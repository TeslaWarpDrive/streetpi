import type { Env as MailboxEnv } from "../src/env";

declare global {
  namespace Cloudflare {
    /** Types `env` from `cloudflare:workers`, so tests reach the same bindings as the Worker. */
    interface Env extends MailboxEnv {}
  }
}
