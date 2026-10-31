export const WRITE = "Bearer fixture-not-a-real-write-token";
export const READ = "Bearer fixture-not-a-real-read-token";

type Json = Record<string, unknown>;

export function liveSnapshot(overrides: Json = {}): Json {
  return {
    schema: 1,
    kind: "live",
    generatedAt: new Date().toISOString(),
    adBlocker: {
      blocking: "enabled",
      queriesToday: 41234,
      blockedToday: 6120,
      percentBlocked: 14.8,
      domainsOnLists: 182340,
      activeDevices: 14,
    },
    machine: {
      cpuBusyPercent: 7.4,
      memoryUsedPercent: 41.2,
      memoryUsedMB: 3380,
      memoryTotalMB: 8192,
      temperatureC: 52.1,
      diskUsedPercent: 38,
      uptimeSeconds: 1209600,
    },
    monitors: { up: 1, down: 1, total: 2, items: [{ name: "Ad blocker", status: "up" }, { name: "Internet", status: "down" }] },
    streamingProxy: { healthy: true },
    backup: { lastRunAt: "2026-10-25T08:00:00Z", ok: true },
    sources: { adBlocker: "ok", machine: "ok", monitors: "ok" },
    ...overrides,
  };
}

/** A full 24 h history push at the contract's point spacing, with 3-digit counts and one-decimal CPU. */
export function historySnapshot(points = { adBlocker: 144, cpu: 288, monitors: 26 }): Json {
  const live = liveSnapshot({ kind: "history" });
  const start = 1_792_000_000;
  return {
    ...live,
    adBlocker: {
      ...(live.adBlocker as Json),
      history: Array.from({ length: points.adBlocker }, (_, i) => ({ t: start + i * 600, total: 812, blocked: 120 })),
    },
    machine: {
      ...(live.machine as Json),
      cpuHistory: Array.from({ length: points.cpu }, (_, i) => ({ t: start + i * 300, busy: 6.1 })),
    },
    monitors: {
      up: points.monitors,
      down: 0,
      total: points.monitors,
      items: Array.from({ length: points.monitors }, (_, i) => ({ name: `Service monitor name ${i}`, status: "up" })),
    },
  };
}
