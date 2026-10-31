import { presentsToken } from "./auth";
import type { Env } from "./env";
import { HISTORY_ROWS, type Mailbox } from "./mailbox";
import { checkSnapshot } from "./schema";

export { Mailbox } from "./mailbox";

const MAX_BODY_BYTES = 16 * 1024;

const BASE_HEADERS = { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" };

function json(body: string, status = 200): Response {
  return new Response(body, { status, headers: { ...BASE_HEADERS, "Content-Type": "application/json" } });
}

function empty(status: number, extra: Record<string, string> = {}): Response {
  return new Response(null, { status, headers: { ...BASE_HEADERS, ...extra } });
}

function refused(): Response {
  return empty(401, { "WWW-Authenticate": "Bearer" });
}

function rejected(reason: string): Response {
  return json(JSON.stringify({ error: reason }), 400);
}

function mailbox(env: Env): DurableObjectStub<Mailbox> {
  return env.MAILBOX.get(env.MAILBOX.idFromName("house"));
}

/** Reads up to the cap and stops. A body with no Content-Length is held to the same limit. */
async function readCapped(request: Request): Promise<string | null> {
  if (Number(request.headers.get("Content-Length") ?? 0) > MAX_BODY_BYTES) return null;
  if (request.body === null) return "";
  const decoder = new TextDecoder();
  let size = 0;
  let text = "";
  for await (const chunk of request.body) {
    size += chunk.byteLength;
    if (size > MAX_BODY_BYTES) return null;
    text += decoder.decode(chunk, { stream: true });
  }
  return text + decoder.decode();
}

async function push(request: Request, env: Env): Promise<Response> {
  if (!(await presentsToken(request, env.WRITE_TOKEN))) return refused();
  const text = await readCapped(request);
  if (text === null) return empty(413);
  const check = checkSnapshot(text, Date.now());
  if (!check.ok) return rejected(check.reason);
  const { kind, generatedAtMs, json: body } = check.snapshot;
  if (kind === "live") {
    await mailbox(env).putLatest(generatedAtMs, body);
  } else {
    await mailbox(env).addHistory(body);
  }
  return empty(204);
}

async function latest(request: Request, env: Env): Promise<Response> {
  if (!(await presentsToken(request, env.READ_TOKEN))) return refused();
  const body = await mailbox(env).latest();
  return body === null ? empty(204) : json(body);
}

function historyLimit(url: URL): number | null {
  const raw = url.searchParams.get("limit");
  if (raw === null) return HISTORY_ROWS;
  const limit = /^\d{1,3}$/.test(raw) ? Number(raw) : 0;
  return limit >= 1 && limit <= HISTORY_ROWS ? limit : null;
}

async function history(request: Request, url: URL, env: Env): Promise<Response> {
  if (!(await presentsToken(request, env.READ_TOKEN))) return refused();
  const limit = historyLimit(url);
  if (limit === null) return rejected(`limit: expected 1 to ${HISTORY_ROWS}`);
  const rows = await mailbox(env).history(limit);
  return json(`{"snapshots":[${rows.join(",")}]}`);
}

async function health(env: Env): Promise<Response> {
  const generatedAtMs = await mailbox(env).latestGeneratedAtMs();
  const ageSeconds = generatedAtMs === null ? null : Math.max(0, Math.floor((Date.now() - generatedAtMs) / 1000));
  return json(JSON.stringify({ ok: true, ageSeconds }));
}

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    switch (`${request.method} ${url.pathname}`) {
      case "POST /v1/push":
        return push(request, env);
      case "GET /v1/latest":
        return latest(request, env);
      case "GET /v1/history":
        return history(request, url, env);
      case "GET /healthz":
        return health(env);
      default:
        return empty(404);
    }
  },
} satisfies ExportedHandler<Env>;
