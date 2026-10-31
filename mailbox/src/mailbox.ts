import { DurableObject } from "cloudflare:workers";
import type { Env } from "./env";

export const HISTORY_ROWS = 288;

/** The one object that holds the house's newest snapshot and its last day of history pushes. */
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
        body TEXT NOT NULL
      );
    `);
  }

  putLatest(generatedAtMs: number, body: string): void {
    this.sql.exec(
      "INSERT OR REPLACE INTO latest (id, generated_at_ms, body) VALUES (1, ?, ?)",
      generatedAtMs,
      body,
    );
  }

  addHistory(body: string): void {
    this.sql.exec("INSERT INTO history (body) VALUES (?)", body);
    this.sql.exec(
      "DELETE FROM history WHERE id <= (SELECT id FROM history ORDER BY id DESC LIMIT 1 OFFSET ?)",
      HISTORY_ROWS,
    );
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

  /** Newest first. */
  history(limit: number): string[] {
    return this.sql
      .exec<{ body: string }>("SELECT body FROM history ORDER BY id DESC LIMIT ?", limit)
      .toArray()
      .map((row) => row.body);
  }
}
