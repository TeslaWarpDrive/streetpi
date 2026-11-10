import { DurableObject } from "cloudflare:workers";
import type { Env } from "./env";

/** Three rows can be read at once, with one extra push kept as a margin. */
export const HISTORY_ROWS = 4;

/** The one object that holds the house's newest snapshot and four recent full-day history pushes. */
export class Mailbox extends DurableObject<Env> {
  private readonly sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS latest (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        generated_at_ms INTEGER NOT NULL,
        body TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS history (
        id INTEGER PRIMARY KEY,
        generated_at_ms INTEGER NOT NULL DEFAULT 0,
        body TEXT NOT NULL
      );
    `);
    this.rememberHistoryTimes();
  }

  /** Older databases stored history in arrival order. Fill the time from the body once. */
  private rememberHistoryTimes(): void {
    const columns = this.sql.exec<{ name: string }>("PRAGMA table_info(history)").toArray();
    if (!columns.some((column) => column.name === "generated_at_ms")) {
      this.sql.exec("ALTER TABLE history ADD COLUMN generated_at_ms INTEGER NOT NULL DEFAULT 0");
    }
    const pending = this.sql
      .exec<{ id: number; body: string }>("SELECT id, body FROM history WHERE generated_at_ms = 0")
      .toArray();
    for (const row of pending) {
      const generatedAtMs = Mailbox.timeInBody(row.body);
      if (generatedAtMs === null) continue;
      this.sql.exec("UPDATE history SET generated_at_ms = ? WHERE id = ?", generatedAtMs, row.id);
    }
  }

  private static timeInBody(body: string): number | null {
    try {
      const parsed = JSON.parse(body) as { generatedAt?: unknown };
      if (typeof parsed.generatedAt !== "string") return null;
      const ms = Date.parse(parsed.generatedAt);
      return Number.isFinite(ms) ? ms : null;
    } catch {
      return null;
    }
  }

  /** An older generatedAt leaves the stored row in place. The same time still replaces it. */
  putLatest(generatedAtMs: number, body: string): void {
    const stored = this.latestGeneratedAtMs();
    if (stored !== null && generatedAtMs < stored) return;
    this.sql.exec(
      "INSERT OR REPLACE INTO latest (id, generated_at_ms, body) VALUES (1, ?, ?)",
      generatedAtMs,
      body,
    );
  }

  addHistory(generatedAtMs: number, body: string): void {
    this.sql.exec("INSERT INTO history (generated_at_ms, body) VALUES (?, ?)", generatedAtMs, body);
    const count = this.sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM history").toArray()[0]?.n ?? 0;
    const extra = count - HISTORY_ROWS;
    if (extra > 0) {
      this.sql.exec(
        `DELETE FROM history WHERE id IN (
          SELECT id FROM history ORDER BY generated_at_ms ASC, id ASC LIMIT ?
        )`,
        extra,
      );
    }
  }

  latest(): string | null {
    const rows = this.sql.exec<{ body: string }>("SELECT body FROM latest WHERE id = 1").toArray();
    return rows[0]?.body ?? null;
  }

  latestGeneratedAtMs(): number | null {
    const rows = this.sql
      .exec<{ generated_at_ms: number }>("SELECT generated_at_ms FROM latest WHERE id = 1")
      .toArray();
    return rows[0]?.generated_at_ms ?? null;
  }

  /** Newest generated time first. The same time keeps the later arrival. */
  history(limit: number): string[] {
    return this.sql
      .exec<{ body: string }>(
        "SELECT body FROM history ORDER BY generated_at_ms DESC, id DESC LIMIT ?",
        limit,
      )
      .toArray()
      .map((row) => row.body);
  }
}
