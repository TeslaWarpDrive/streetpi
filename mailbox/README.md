# Pi Stats mailbox

A small Cloudflare Worker that holds the newest read-only stats from the Pi, so the app can show them away from home. The Pi pushes out over HTTPS. Nothing on the Pi listens, and no router port changes.

One Worker and one SQLite-backed Durable Object. No KV. Everything fits the free plan, and over a free limit Cloudflare answers with an error instead of billing.

## API

| Route | Token | Answer |
| --- | --- | --- |
| `POST /v1/push` | `WRITE_TOKEN` | `204`. `400` names the bad field and never echoes a value. `413` over 16 KB. |
| `GET /v1/latest` | `READ_TOKEN` | `200` with the newest live snapshot. `204` before the first push. |
| `GET /v1/history` | `READ_TOKEN` | `200` with `{"snapshots":[…]}`, newest first. `?limit=N` (1 to 288) returns only the newest rows. |
| `GET /healthz` | none | `{"ok":true,"ageSeconds":12}`. `ageSeconds` is `null` before the first push. |

A missing or wrong token gets `401`. The read token cannot write and the write token cannot read. Everything else gets `404`. Every answer carries `Cache-Control: no-store`, and none carries a CORS header. The Worker logs nothing, and observability is off in `wrangler.jsonc`.

A `live` push replaces the one `latest` row. A `history` push adds a row, and the table keeps the newest 288.

## Schema

The contract is snapshot v1 in `remote-access-webhook-plan.md`. `src/schema.ts` is the strict check: an unknown key fails at any depth, and every contract key must be present. `generatedAt` must be UTC, at most 2 minutes ahead and at most 1 hour behind.

The check adds these rules to the plan:

- `adBlocker`, `machine`, and `monitors` may each be `null` when that part failed and there is no last good value. `sources` for that part then cannot be `ok`. The contract's "still push" rule needs this, and a made-up zero would read as a real number.
- `adBlocker.history` and `machine.cpuHistory` are required on a `history` push and rejected on a `live` push.
- A monitor `status` is `up`, `down`, `pending`, or `maintenance`, the four Uptime Kuma states.
- A monitor `name` is 1 to 64 characters and cannot contain an IPv4 address. The Pi must rename or leave out a monitor whose name holds one.

Each `history` push already carries a full day of points, so the app asks for `GET /v1/history?limit=1` and pays for about 16 KB. Without the limit the answer can reach 4.6 MB.

A full history push sits close to the 16 KB cap: about 16,020 bytes on a typical day, and about 16,450 on a busy one, which is over and gets `413`. The Pi should send `busy` as a whole number and JSON with no spaces. That brings a busy day to about 15,880 bytes. `historySnapshot()` in `test/fixtures.ts` is a realistic full day, and a test proves that it fits.

## Test

```sh
npm ci
npm test
```

Tests run in the local Workers runtime with fixture tokens. They need no Cloudflare account.

## Deploy

Only run this with Bradley's OK. It needs a Cloudflare login and it changes his account. Run from this folder.

1. Install the tools and sign in.

   ```sh
   npm ci
   npx wrangler login
   ```

2. Publish the Worker. It answers `401` to everyone until the secrets are set.

   ```sh
   npx wrangler deploy
   ```

3. Make both tokens straight into the Worker secrets. A Worker secret can't be read back, so `tee` also keeps one private copy for the handoff. Neither token reaches the screen, the shell history, or a log. `pipefail` stops a failed `openssl` from setting an empty secret.

   ```sh
   set -o pipefail
   umask 077
   handoff="$(mktemp -d)"
   openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n' | tee "$handoff/write-token" | npx wrangler secret put WRITE_TOKEN
   openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n' | tee "$handoff/read-token" | npx wrangler secret put READ_TOKEN
   ```

   This gives 32 random bytes in base64url. `openssl rand -base64url 32` is not used because LibreSSL, which macOS ships, does not have that flag.

4. Check it. The first answer is `{"ok":true,"ageSeconds":null}`.

   ```sh
   curl -s https://pistats-mailbox.<your-subdomain>.workers.dev/healthz
   ```

5. Give the Pi its token. `write-token` goes to `MAILBOX_WRITE_TOKEN` in the Pi's root `600` `.env`.

6. So nobody types anything on a phone, Bradley adds two repo secrets. Save the deployed mailbox address in `$handoff/mailbox-url` using a local editor. The private handoff directory was created with `umask 077`. Both secrets are read from files through stdin, keeping the values out of commands, shell history, and output.

   ```sh
   gh secret set AWAY_MAILBOX_URL --repo TeslaWarpDrive/streetpi < "$handoff/mailbox-url"
   gh secret set AWAY_READ_TOKEN --repo TeslaWarpDrive/streetpi < "$handoff/read-token"
   ```

   The next CI run also builds the provisioned IPA. See "Provisioned IPA" in the main README. Without these secrets the build still succeeds, and the phone's Settings > Away takes the address and `read-token` by hand.

7. Keep `read-token` in Bradley's password manager, because it opens the provisioned IPA. Then destroy the copies.

   ```sh
   shred -u "$handoff/write-token" "$handoff/read-token" "$handoff/mailbox-url"
   rmdir "$handoff"
   ```

On a Mac without `shred`, use `rm -P`.

To replace a token, repeat its line from step 3 and hand the new one over. The old one stops working at once. A phone that already has a mailbox keeps it, so after replacing the read token, update `AWAY_READ_TOKEN` and either replace the token in Settings > Away or remove the app and install the new build.
