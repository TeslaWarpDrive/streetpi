import type { Mailbox } from "./mailbox";

export interface Env {
  MAILBOX: DurableObjectNamespace<Mailbox>;
  WRITE_TOKEN?: string;
  READ_TOKEN?: string;
}
