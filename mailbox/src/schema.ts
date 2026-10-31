/** Strict v1 snapshot check. An unknown key fails, so a Pi-side bug cannot leak an extra field. */

const MAX_FUTURE_MS = 2 * 60 * 1000;
const MAX_PAST_MS = 60 * 60 * 1000;
const MAX_MONITOR_NAME = 64;
const UTC_TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?Z$/;
const IPV4 = /\d{1,3}(\.\d{1,3}){3}/;

export type SnapshotKind = "live" | "history";

export interface Snapshot {
  kind: SnapshotKind;
  generatedAtMs: number;
  /** Normal form of the checked value. This is what gets stored. */
  json: string;
}

export type SnapshotCheck = { ok: true; snapshot: Snapshot } | { ok: false; reason: string };

/** Carries a field path and never a value. */
class Rejection extends Error {}

function reject(path: string, problem: string): never {
  throw new Rejection(`${path}: ${problem}`);
}

function object(value: unknown, path: string, keys: readonly string[]): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) reject(path, "expected an object");
  const fields = value as Record<string, unknown>;
  for (const key of Object.keys(fields)) {
    if (!keys.includes(key)) reject(path, "unknown key");
  }
  for (const key of keys) {
    if (!Object.hasOwn(fields, key)) reject(`${path}.${key}`, "missing");
  }
  return fields;
}

function nullable(value: unknown, check: (present: unknown) => void): void {
  if (value !== null) check(value);
}

function number(value: unknown, path: string, min: number, max: number): void {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    reject(path, `expected a number from ${min} to ${max}`);
  }
}

function count(value: unknown, path: string): void {
  if (!Number.isSafeInteger(value) || (value as number) < 0) reject(path, "expected a whole count");
}

function percent(value: unknown, path: string): void {
  number(value, path, 0, 100);
}

function oneOf(value: unknown, path: string, allowed: readonly string[]): void {
  if (typeof value !== "string" || !allowed.includes(value)) reject(path, `expected ${allowed.join(" | ")}`);
}

function list(value: unknown, path: string, item: (entry: unknown, path: string) => void): void {
  if (!Array.isArray(value)) reject(path, "expected an array");
  value.forEach((entry, index) => {
    item(entry, `${path}[${index}]`);
  });
}

function timestamp(value: unknown, path: string): number {
  if (typeof value !== "string" || !UTC_TIMESTAMP.test(value)) reject(path, "expected a UTC timestamp");
  const ms = Date.parse(value);
  if (Number.isNaN(ms)) reject(path, "expected a UTC timestamp");
  return ms;
}

function adBlockerPoint(value: unknown, path: string): void {
  const point = object(value, path, ["t", "total", "blocked"]);
  count(point.t, `${path}.t`);
  count(point.total, `${path}.total`);
  count(point.blocked, `${path}.blocked`);
}

function adBlocker(value: unknown, path: string, kind: SnapshotKind): void {
  const base = ["blocking", "queriesToday", "blockedToday", "percentBlocked", "domainsOnLists", "activeDevices"];
  const part = object(value, path, kind === "history" ? [...base, "history"] : base);
  oneOf(part.blocking, `${path}.blocking`, ["enabled", "disabled", "unknown"]);
  count(part.queriesToday, `${path}.queriesToday`);
  count(part.blockedToday, `${path}.blockedToday`);
  percent(part.percentBlocked, `${path}.percentBlocked`);
  count(part.domainsOnLists, `${path}.domainsOnLists`);
  count(part.activeDevices, `${path}.activeDevices`);
  if (kind === "history") list(part.history, `${path}.history`, adBlockerPoint);
}

function cpuPoint(value: unknown, path: string): void {
  const point = object(value, path, ["t", "busy"]);
  count(point.t, `${path}.t`);
  percent(point.busy, `${path}.busy`);
}

function machine(value: unknown, path: string, kind: SnapshotKind): void {
  const base = [
    "cpuBusyPercent",
    "memoryUsedPercent",
    "memoryUsedMB",
    "memoryTotalMB",
    "temperatureC",
    "diskUsedPercent",
    "uptimeSeconds",
  ];
  const part = object(value, path, kind === "history" ? [...base, "cpuHistory"] : base);
  percent(part.cpuBusyPercent, `${path}.cpuBusyPercent`);
  percent(part.memoryUsedPercent, `${path}.memoryUsedPercent`);
  count(part.memoryUsedMB, `${path}.memoryUsedMB`);
  count(part.memoryTotalMB, `${path}.memoryTotalMB`);
  number(part.temperatureC, `${path}.temperatureC`, -40, 150);
  percent(part.diskUsedPercent, `${path}.diskUsedPercent`);
  count(part.uptimeSeconds, `${path}.uptimeSeconds`);
  if (kind === "history") list(part.cpuHistory, `${path}.cpuHistory`, cpuPoint);
}

function monitorItem(value: unknown, path: string): void {
  const item = object(value, path, ["name", "status"]);
  const name = item.name;
  if (typeof name !== "string" || name.length === 0 || name.length > MAX_MONITOR_NAME) {
    reject(`${path}.name`, `expected 1 to ${MAX_MONITOR_NAME} characters`);
  }
  if (IPV4.test(name)) reject(`${path}.name`, "must not contain an IP address");
  oneOf(item.status, `${path}.status`, ["up", "down", "pending", "maintenance"]);
}

function monitors(value: unknown, path: string): void {
  const part = object(value, path, ["up", "down", "total", "items"]);
  count(part.up, `${path}.up`);
  count(part.down, `${path}.down`);
  count(part.total, `${path}.total`);
  list(part.items, `${path}.items`, monitorItem);
}

function streamingProxy(value: unknown, path: string): void {
  const part = object(value, path, ["healthy"]);
  if (typeof part.healthy !== "boolean") reject(`${path}.healthy`, "expected true or false");
}

function backup(value: unknown, path: string): void {
  const part = object(value, path, ["lastRunAt", "ok"]);
  timestamp(part.lastRunAt, `${path}.lastRunAt`);
  if (typeof part.ok !== "boolean") reject(`${path}.ok`, "expected true or false");
}

const SOURCE_STATES = ["ok", "stale", "error"];

function sources(value: unknown, path: string): Record<string, unknown> {
  const part = object(value, path, ["adBlocker", "machine", "monitors"]);
  oneOf(part.adBlocker, `${path}.adBlocker`, SOURCE_STATES);
  oneOf(part.machine, `${path}.machine`, SOURCE_STATES);
  oneOf(part.monitors, `${path}.monitors`, SOURCE_STATES);
  return part;
}

function snapshotFields(value: unknown, nowMs: number): Snapshot {
  const root = object(value, "snapshot", [
    "schema",
    "kind",
    "generatedAt",
    "adBlocker",
    "machine",
    "monitors",
    "streamingProxy",
    "backup",
    "sources",
  ]);
  if (root.schema !== 1) reject("schema", "expected 1");
  oneOf(root.kind, "kind", ["live", "history"]);
  const kind = root.kind as SnapshotKind;
  const generatedAtMs = timestamp(root.generatedAt, "generatedAt");
  if (generatedAtMs > nowMs + MAX_FUTURE_MS) reject("generatedAt", "too far in the future");
  if (generatedAtMs < nowMs - MAX_PAST_MS) reject("generatedAt", "too old");

  nullable(root.adBlocker, (present) => adBlocker(present, "adBlocker", kind));
  nullable(root.machine, (present) => machine(present, "machine", kind));
  nullable(root.monitors, (present) => monitors(present, "monitors"));
  streamingProxy(root.streamingProxy, "streamingProxy");
  nullable(root.backup, (present) => backup(present, "backup"));

  const health = sources(root.sources, "sources");
  for (const part of ["adBlocker", "machine", "monitors"]) {
    if (root[part] === null && health[part] === "ok") reject(`sources.${part}`, "cannot be ok for a missing part");
  }
  return { kind, generatedAtMs, json: JSON.stringify(root) };
}

export function checkSnapshot(text: string, nowMs: number): SnapshotCheck {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    return { ok: false, reason: "snapshot: not JSON" };
  }
  try {
    return { ok: true, snapshot: snapshotFields(value, nowMs) };
  } catch (error) {
    if (error instanceof Rejection) return { ok: false, reason: error.message };
    throw error;
  }
}
