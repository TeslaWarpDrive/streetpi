import { SELF, reset } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { READ, WRITE, historySnapshot, liveSnapshot } from "./fixtures";

const BASE = "https://mailbox.example";
const fields = ["temperatureHistory", "memoryHistory", "diskHistory"] as const;

beforeEach(async () => { await reset(); });

function push(body: unknown): Promise<Response> {
  return SELF.fetch(`${BASE}/v1/push`, {
    method: "POST",
    headers: { Authorization: WRITE },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function withMachine(fields: Record<string, unknown>, live = false): Record<string, unknown> {
  const snapshot = live ? liveSnapshot() : historySnapshot({ adBlocker: 144, cpu: 96, monitors: 26 });
  const machine = snapshot.machine;
  if (typeof machine !== "object" || machine === null) throw new Error("Fixture machine missing");
  return { ...snapshot, machine: { ...machine, ...fields } };
}

function day() {
  return {
    temperatureHistory: Array.from({ length: 24 }, (_, i) => ({ t: 1792000000 + i * 3600, c: 48.5 })),
    memoryHistory: Array.from({ length: 24 }, (_, i) => ({ t: 1792000000 + i * 3600, used: 42 })),
    diskHistory: Array.from({ length: 24 }, (_, i) => ({ t: 1792000000 + i * 3600, used: 38 })),
  };
}

describe("optional Netdata history", () => {
  it("keeps today's 288 CPU points and the old payload unchanged", async () => {
    const snapshot = historySnapshot();
    expect((await push(snapshot)).status).toBe(204);
    const response = await SELF.fetch(`${BASE}/v1/history?limit=1`, { headers: { Authorization: READ } });
    expect(await response.json()).toEqual({ snapshots: [snapshot] });
  });

  it("stores 24 hourly points beside 96 CPU points within the byte cap", async () => {
    const snapshot = withMachine(day());
    expect(new TextEncoder().encode(JSON.stringify(snapshot)).length).toBeLessThanOrEqual(16384);
    expect((await push(snapshot)).status).toBe(204);
    const response = await SELF.fetch(`${BASE}/v1/history?limit=1`, { headers: { Authorization: READ } });
    expect(await response.json()).toEqual({ snapshots: [snapshot] });
  });

  it("accepts each series independently and empty arrays", async () => {
    for (const field of fields) {
      expect((await push(withMachine({ [field]: day()[field] }))).status).toBe(204);
      expect((await push(withMachine({ [field]: [] }))).status).toBe(204);
    }
  });

  it("rejects bad arrays, points, timestamps, values and extra keys", async () => {
    for (const field of fields) {
      const key = field === "temperatureHistory" ? "c" : "used";
      const bad: unknown[] = [null, {}, "bad", [null], [{ t: 1 }], [{ [key]: 42 }], [{ t: true, [key]: 42 }], [{ t: "1", [key]: 42 }],
        [{ t: 1.5, [key]: 42 }], [{ t: -1, [key]: 42 }], [{ t: 1, [key]: "42" }],
        [{ t: 1, [key]: null }], [{ t: 1, [key]: false }], [{ t: 1, [key]: 42, extra: 1 }], Array(25).fill({ t: 1, [key]: 42 })];
      if (key === "used") bad.push([{ t: 1, used: 42.5 }], [{ t: 1, used: -1 }], [{ t: 1, used: 101 }]);
      for (const value of bad) expect((await push(withMachine({ [field]: value }))).status).toBe(400);
    }
    expect((await push(withMachine({ unknownHistory: [] }))).status).toBe(400);
    expect((await push(withMachine({ cpuHistory: Array(289).fill({ t: 1, busy: 5 }) }))).status).toBe(400);
  });

  it("accepts boundary percentages and negative Celsius, but rejects nonfinite Celsius", async () => {
    expect((await push(withMachine({
      temperatureHistory: [{ t: 1, c: -2.5 }],
      memoryHistory: [{ t: 1, used: 0 }, { t: 2, used: 100 }],
      diskHistory: [{ t: 1, used: 100 }],
    }))).status).toBe(204);
    const json = JSON.stringify(withMachine({ temperatureHistory: [{ t: 1, c: "OVERFLOW" }] }));
    expect((await push(json.replace('"OVERFLOW"', "1e400"))).status).toBe(400);
  });

  it("rejects every new field on live, even empty", async () => {
    for (const field of fields) expect((await push(withMachine({ [field]: [] }, true))).status).toBe(400);
  });

  it("keeps the 16384-byte boundary for new payloads", async () => {
    const json = JSON.stringify(withMachine(day()));
    expect((await push(json.padEnd(16384, " "))).status).toBe(204);
    expect((await push(json.padEnd(16385, " "))).status).toBe(413);
  });
});
