import { SELF, reset, runInDurableObject } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { READ, WRITE, historySnapshot, liveSnapshot } from "./fixtures";

const BASE = "https://mailbox.example";

beforeEach(async () => {
  await reset();
});

function push(body: unknown, authorization = WRITE): Promise<Response> {
  return SELF.fetch(`${BASE}/v1/push`, {
    method: "POST",
    headers: { Authorization: authorization, "Content-Type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function get(path: string, authorization?: string): Promise<Response> {
  return SELF.fetch(`${BASE}${path}`, authorization ? { headers: { Authorization: authorization } } : {});
}

async function expectRejected(body: unknown, field: string): Promise<void> {
  const response = await push(body);
  expect(response.status).toBe(400);
  expect((await response.json<{ error: string }>()).error).toContain(field);
}

describe("auth", () => {
  it("lets each token do only its own job", async () => {
    expect((await push(liveSnapshot(), READ)).status).toBe(401);
    expect((await get("/v1/latest", WRITE)).status).toBe(401);
    expect((await get("/v1/history", WRITE)).status).toBe(401);
    expect((await push(liveSnapshot(), WRITE)).status).toBe(204);
    expect((await get("/v1/latest", READ)).status).toBe(200);
    expect((await get("/v1/history", READ)).status).toBe(200);
  });

  it("refuses a missing, malformed, or wrong token", async () => {
    expect((await get("/v1/latest")).status).toBe(401);
    expect((await get("/v1/latest", "fixture-not-a-real-read-token")).status).toBe(401);
    expect((await get("/v1/latest", "Bearer fixture-not-a-real-read-toke")).status).toBe(401);
    expect((await get("/v1/latest", "Basic fixture-not-a-real-read-token")).status).toBe(401);
  });

  it("checks the token before it reads the body", async () => {
    const response = await push("x".repeat(20 * 1024), "Bearer nope");
    expect(response.status).toBe(401);
  });
});

describe("schema", () => {
  it("rejects a client name, an IP, and any other unknown key", async () => {
    await expectRejected(liveSnapshot({ clientName: "fixture-laptop" }), "snapshot: unknown key");
    await expectRejected(liveSnapshot({ ip: "192.0.2.10" }), "snapshot: unknown key");
    const leaky = liveSnapshot();
    (leaky.adBlocker as Record<string, unknown>).topClient = "fixture-phone";
    await expectRejected(leaky, "adBlocker: unknown key");
  });

  it("rejects an unknown key nested in a monitor", async () => {
    const leaky = liveSnapshot({
      monitors: { up: 1, down: 0, total: 1, items: [{ name: "Ad blocker", status: "up", host: "192.0.2.10" }] },
    });
    await expectRejected(leaky, "monitors.items[0]: unknown key");
  });

  it("rejects a monitor name that carries an IP", async () => {
    const leaky = liveSnapshot({
      monitors: { up: 1, down: 0, total: 1, items: [{ name: "Check 192.0.2.10", status: "up" }] },
    });
    await expectRejected(leaky, "monitors.items[0].name");
  });

  it("rejects an up count above the total, and an all-up count beside a down check", async () => {
    const good = liveSnapshot();
    expect((await push(good)).status).toBe(204);

    const fiveOfZero = liveSnapshot({
      monitors: { up: 5, down: 0, total: 0, items: [] },
    });
    const overTotal = await push(fiveOfZero);
    expect(overTotal.status).toBe(400);
    const overText = await overTotal.text();
    expect(overText).toContain("monitors.up");
    expect(overText).not.toContain("5");

    const calmLie = liveSnapshot({
      monitors: {
        up: 2,
        down: 0,
        total: 2,
        items: [
          { name: "Ad blocker", status: "up" },
          { name: "Internet", status: "down" },
        ],
      },
    });
    const lie = await push(calmLie);
    expect(lie.status).toBe(400);
    const lieText = await lie.text();
    expect(lieText).toContain("monitors.items");
    expect(lieText).not.toContain("Internet");

    const kept = await (await get("/v1/latest", READ)).json<{ monitors: unknown }>();
    expect(kept.monitors).toEqual(good.monitors);
  });

  it("keeps a shorter named list, and a down count that the summary already admits", async () => {
    const subset = liveSnapshot({
      monitors: {
        up: 4,
        down: 1,
        total: 10,
        items: [
          { name: "Ad blocker", status: "up" },
          { name: "Internet", status: "down" },
        ],
      },
    });
    expect((await push(subset)).status).toBe(204);

    const counted = liveSnapshot({
      monitors: {
        up: 2,
        down: 1,
        total: 2,
        items: [{ name: "Internet", status: "down" }],
      },
    });
    expect((await push(counted)).status).toBe(204);

    const pending = liveSnapshot({
      monitors: {
        up: 1,
        down: 0,
        total: 1,
        items: [{ name: "Ad blocker", status: "pending" }],
      },
    });
    expect((await push(pending)).status).toBe(204);
  });

  it("does not store a history push whose counts say every check is up", async () => {
    const history = historySnapshot({ adBlocker: 1, cpu: 1, monitors: 1 });
    history.monitors = {
      up: 1,
      down: 0,
      total: 1,
      items: [{ name: "Internet", status: "down" }],
    };
    await expectRejected(history, "monitors.items");
    const body = await (await get("/v1/history", READ)).json<{ snapshots: unknown[] }>();
    expect(body.snapshots).toEqual([]);
  });

  it("never echoes a rejected value", async () => {
    const response = await push(liveSnapshot({ ip: "192.0.2.10" }));
    expect(await response.text()).not.toContain("192.0.2.10");
  });

  it("rejects bad JSON, a wrong schema, and a wrong kind", async () => {
    await expectRejected("{nope", "not JSON");
    await expectRejected("[]", "expected an object");
    await expectRejected(liveSnapshot({ schema: 2 }), "schema");
    await expectRejected(liveSnapshot({ kind: "other" }), "kind");
  });

  it("rejects a generatedAt that is malformed or outside the window", async () => {
    await expectRejected(liveSnapshot({ generatedAt: "yesterday" }), "generatedAt");
    await expectRejected(liveSnapshot({ generatedAt: "2026-10-30T19:40:00+05:00" }), "generatedAt");
    const ahead = new Date(Date.now() + 3 * 60 * 1000).toISOString();
    await expectRejected(liveSnapshot({ generatedAt: ahead }), "future");
    const behind = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
    await expectRejected(liveSnapshot({ generatedAt: behind }), "old");
  });

  it("accepts a generatedAt just inside the future limit", async () => {
    const ahead = new Date(Date.now() + 60 * 1000).toISOString();
    expect((await push(liveSnapshot({ generatedAt: ahead }))).status).toBe(204);
  });

  it("rejects out-of-range numbers and bad words", async () => {
    const good = liveSnapshot();
    const machine = good.machine as Record<string, unknown>;
    await expectRejected({ ...good, machine: { ...machine, cpuBusyPercent: 140 } }, "machine.cpuBusyPercent");
    await expectRejected({ ...good, machine: { ...machine, uptimeSeconds: -1 } }, "machine.uptimeSeconds");
    await expectRejected(
      { ...good, adBlocker: { ...(good.adBlocker as object), blocking: "maybe" } },
      "adBlocker.blocking",
    );
    await expectRejected({ ...good, sources: { adBlocker: "ok", machine: "ok", monitors: "fine" } }, "sources.monitors");
  });

  it("rejects a missing key", async () => {
    const { backup: _dropped, ...partial } = liveSnapshot();
    await expectRejected(partial, "snapshot.backup");
  });

  it("allows series only on a history push", async () => {
    const history = historySnapshot();
    await expectRejected({ ...history, kind: "live" }, "adBlocker: unknown key");
    await expectRejected(liveSnapshot({ kind: "history" }), "adBlocker.history");
  });

  it("takes null for a failed part only when sources says so", async () => {
    const failed = liveSnapshot({
      machine: null,
      backup: null,
      sources: { adBlocker: "ok", machine: "error", monitors: "ok" },
    });
    expect((await push(failed)).status).toBe(204);
    await expectRejected(liveSnapshot({ machine: null }), "sources.machine");
  });
});

describe("size", () => {
  it("rejects a body over 16 KB, with or without a declared length", async () => {
    expect((await push("x".repeat(16 * 1024 + 1))).status).toBe(413);
    const stream = new Blob(["x".repeat(16 * 1024 + 1)]).stream();
    const chunked = await SELF.fetch(`${BASE}/v1/push`, {
      method: "POST",
      headers: { Authorization: WRITE },
      body: stream,
    });
    expect(chunked.status).toBe(413);
  });

  it("fits a full day of history inside the limit", async () => {
    const body = JSON.stringify(historySnapshot());
    expect(new TextEncoder().encode(body).length).toBeLessThanOrEqual(16 * 1024);
    expect((await push(body)).status).toBe(204);
  });
});

describe("storage", () => {
  it("replaces latest", async () => {
    expect((await get("/v1/latest", READ)).status).toBe(204);
    await push(liveSnapshot({ streamingProxy: { healthy: true } }));
    await push(liveSnapshot({ streamingProxy: { healthy: false } }));
    const body = await (await get("/v1/latest", READ)).json<{ streamingProxy: { healthy: boolean } }>();
    expect(body.streamingProxy.healthy).toBe(false);
  });

  it("keeps the stored live snapshot when an older one arrives later", async () => {
    const now = Date.now();
    const at = (offsetMs: number) => new Date(now + offsetMs).toISOString();
    const minuteAgo = at(-60 * 1000);
    const tenMinutesAgo = at(-10 * 60 * 1000);
    const withTemperature = (generatedAt: string, temperatureC: number) => {
      const snapshot = liveSnapshot({ generatedAt });
      (snapshot.machine as Record<string, unknown>).temperatureC = temperatureC;
      return snapshot;
    };
    const shown = async () =>
      (await get("/v1/latest", READ)).json<{ generatedAt: string; machine: { temperatureC: number } }>();

    expect((await push(withTemperature(tenMinutesAgo, 40))).status).toBe(204);
    expect((await push(withTemperature(minuteAgo, 61))).status).toBe(204);
    expect(await shown()).toMatchObject({ generatedAt: minuteAgo, machine: { temperatureC: 61 } });

    expect((await push(withTemperature(tenMinutesAgo, 40))).status).toBe(204);
    expect(await shown()).toMatchObject({ generatedAt: minuteAgo, machine: { temperatureC: 61 } });
    const age = await (await get("/healthz")).json<{ ageSeconds: number }>();
    expect(age.ageSeconds).toBeGreaterThanOrEqual(60);
    expect(age.ageSeconds).toBeLessThan(180);

    expect((await push(withTemperature(minuteAgo, 55))).status).toBe(204);
    expect(await shown()).toMatchObject({ generatedAt: minuteAgo, machine: { temperatureC: 55 } });
    const justNow = at(0);
    expect((await push(withTemperature(justNow, 48))).status).toBe(204);
    expect(await shown()).toMatchObject({ generatedAt: justNow, machine: { temperatureC: 48 } });
  });

  it("keeps a history push out of latest and a live push out of history", async () => {
    await push(historySnapshot());
    expect((await get("/v1/latest", READ)).status).toBe(204);
    await push(liveSnapshot());
    const body = await (await get("/v1/history?limit=3", READ)).json<{ snapshots: { kind: string }[] }>();
    expect(body.snapshots.map((snapshot) => snapshot.kind)).toEqual(["history"]);
  });

  it("keeps up to four history rows and trims oldest first on each push", async () => {
    const tiny = { adBlocker: 1, cpu: 1, monitors: 1 };
    const mailbox = env.MAILBOX.get(env.MAILBOX.idFromName("house"));
    for (let run = 0; run < 7; run += 1) {
      const snapshot = historySnapshot(tiny);
      (snapshot.machine as Record<string, unknown>).uptimeSeconds = run;
      expect((await push(snapshot)).status).toBe(204);
      const rows = await mailbox.history(5);
      const uptimes = rows.map((row) => (JSON.parse(row) as { machine: { uptimeSeconds: number } }).machine.uptimeSeconds);
      expect(uptimes).toEqual(Array.from({ length: Math.min(run + 1, 4) }, (_, index) => run - index));
    }
  });

  it("trims an existing 288-row mailbox on the next history push", async () => {
    const mailbox = env.MAILBOX.get(env.MAILBOX.idFromName("house"));
    await runInDurableObject(mailbox, (_instance, state) => {
      for (let run = 0; run < 288; run += 1) {
        state.storage.sql.exec("INSERT INTO history (body) VALUES (?)", JSON.stringify({ legacyRow: run }));
      }
    });
    const snapshot = historySnapshot();
    expect((await push(snapshot)).status).toBe(204);
    const rows = await mailbox.history(289);
    expect(rows.map((row) => JSON.parse(row))).toEqual([
      snapshot, { legacyRow: 287 }, { legacyRow: 286 }, { legacyRow: 285 },
    ]);
  });

  it("reads the newest row by default and up to three on request", async () => {
    const tiny = { adBlocker: 1, cpu: 1, monitors: 1 };
    for (let run = 0; run < 5; run += 1) {
      const snapshot = historySnapshot(tiny);
      (snapshot.machine as Record<string, unknown>).uptimeSeconds = run;
      await push(snapshot);
    }
    const uptimes = async (path: string): Promise<number[]> => {
      const body = await (await get(path, READ)).json<{ snapshots: { machine: { uptimeSeconds: number } }[] }>();
      return body.snapshots.map((snapshot) => snapshot.machine.uptimeSeconds);
    };
    expect(await uptimes("/v1/history")).toEqual([4]);
    expect(await uptimes("/v1/history?limit=1")).toEqual([4]);
    expect(await uptimes("/v1/history?limit=3")).toEqual([4, 3, 2]);
  });

  it("rejects a history limit outside 1 to 3 and names only the field", async () => {
    for (const limit of ["0", "4", "288", "289", "1000", "abc", "-1", "1.5", "1e0", ""]) {
      const response = await get(`/v1/history?limit=${limit}`, READ);
      expect(response.status).toBe(400);
      expect(await response.json()).toEqual({ error: "limit: expected 1 to 3" });
    }
  });

  it("checks the token before it reads the limit", async () => {
    expect((await get("/v1/history?limit=abc", WRITE)).status).toBe(401);
  });

  it("keeps the largest history read to three full pushes", async () => {
    for (let run = 0; run < 4; run += 1) {
      expect((await push(historySnapshot())).status).toBe(204);
    }
    const response = await get("/v1/history?limit=3", READ);
    const text = await response.text();
    expect((JSON.parse(text) as { snapshots: unknown[] }).snapshots).toHaveLength(3);
    expect(new TextEncoder().encode(text).length).toBeLessThanOrEqual(3 * 16 * 1024 + 32);
  });
});

describe("healthz", () => {
  it("needs no token and reports only the age", async () => {
    expect(await (await get("/healthz")).json()).toEqual({ ok: true, ageSeconds: null });
    await push(liveSnapshot({ generatedAt: new Date(Date.now() - 30 * 1000).toISOString() }));
    const body = await (await get("/healthz")).json<{ ok: boolean; ageSeconds: number }>();
    expect(Object.keys(body).sort()).toEqual(["ageSeconds", "ok"]);
    expect(body.ageSeconds).toBeGreaterThanOrEqual(30);
    expect(body.ageSeconds).toBeLessThan(40);
  });
});

describe("responses", () => {
  it("answers everything else with 404", async () => {
    expect((await get("/")).status).toBe(404);
    expect((await get("/v1/push", WRITE)).status).toBe(404);
    expect((await get("/v1/latest/", READ)).status).toBe(404);
    expect((await SELF.fetch(`${BASE}/v1/latest`, { method: "POST", headers: { Authorization: READ } })).status).toBe(404);
    expect((await SELF.fetch(`${BASE}/v1/latest`, { method: "OPTIONS" })).status).toBe(404);
  });

  it("sends no-store and no CORS headers", async () => {
    const pushed = await push(liveSnapshot());
    for (const response of [pushed, await get("/v1/latest", READ), await get("/healthz"), await get("/nope")]) {
      expect(response.headers.get("Cache-Control")).toBe("no-store");
      expect(response.headers.has("Access-Control-Allow-Origin")).toBe(false);
    }
  });
});
