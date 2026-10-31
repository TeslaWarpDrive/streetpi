import { SELF, reset } from "cloudflare:test";
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

  it("keeps a history push out of latest and a live push out of history", async () => {
    await push(historySnapshot());
    expect((await get("/v1/latest", READ)).status).toBe(204);
    await push(liveSnapshot());
    const body = await (await get("/v1/history", READ)).json<{ snapshots: unknown[] }>();
    expect(body.snapshots).toHaveLength(1);
  });

  it("trims history to the newest 288 rows and reads newest first", async () => {
    const tiny = { adBlocker: 1, cpu: 1, monitors: 1 };
    for (let run = 0; run < 290; run += 1) {
      const snapshot = historySnapshot(tiny);
      (snapshot.machine as Record<string, unknown>).uptimeSeconds = run;
      expect((await push(snapshot)).status).toBe(204);
    }
    const all = await (await get("/v1/history", READ)).json<{ snapshots: { machine: { uptimeSeconds: number } }[] }>();
    expect(all.snapshots).toHaveLength(288);
    expect(all.snapshots[0]?.machine.uptimeSeconds).toBe(289);
    expect(all.snapshots.at(-1)?.machine.uptimeSeconds).toBe(2);
  });

  it("limits a history read to the newest rows", async () => {
    await push(historySnapshot());
    await push(historySnapshot());
    const one = await (await get("/v1/history?limit=1", READ)).json<{ snapshots: unknown[] }>();
    expect(one.snapshots).toHaveLength(1);
    expect((await get("/v1/history?limit=0", READ)).status).toBe(400);
    expect((await get("/v1/history?limit=289", READ)).status).toBe(400);
    expect((await get("/v1/history?limit=abc", READ)).status).toBe(400);
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
