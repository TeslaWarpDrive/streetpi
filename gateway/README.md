# Pi Stats gateway

This is the small gate on the Pi for away mode. Pi Keeper reviews it and deploys it. Nothing in this repository starts it, and nothing here changes the Pi, Cloudflare, or DNS.

At home the phone talks to the Pi on the house network (`192.168.1.78`): Pi-hole on `https` port 443, Netdata on port 19999, and Uptime Kuma on port 3001. Away from home the phone calls `https://pistats.thestreetfam.com`. That name is already published by the Cloudflare Tunnel `pi-grok-stats`. Cloudflare Access checks the service token. `cloudflared` is set to protect the hostname with Access, so it checks the Access JWT and then forwards to this gate at `http://127.0.0.1:8447`.

The gate is stock `caddy:2` with no plugins. It allows only the method and path pairs in `allowlist.json`. Paths are exact and do not include the query string. Anything else is 404. A request with no `Cf-Access-Jwt-Assertion` header is 403. The gate checks that the header is present. It does not check the signature. The signature check is `cloudflared`'s job, which is why this listener stays on `127.0.0.1` and is not published on the LAN.

Pi-hole is proxied to `https://127.0.0.1:443` with SNI `pi.hole` and the Pi-hole CA in `/etc/caddy/pihole-ca.pem`. Verification stays on. Do not set `insecure_skip_verify`. Netdata paths under `/netdata` are forwarded to `127.0.0.1:19999` with that prefix removed. Kuma paths under `/kuma` are forwarded to `127.0.0.1:3001` with that prefix removed. `GET /healthz` is answered by the gate itself.

Before the proxy, these headers are removed: `CF-Access-Client-Id`, `CF-Access-Client-Secret`, `Cf-Access-Jwt-Assertion`, and `Cookie`. The Pi-hole session header `X-FTL-SID` is left in place. The body limit is 4KB. Gravity (`POST /api/action/gravity`) may wait 310 seconds for response headers. Every other proxy waits 30 seconds. `GET /api/queries` and `GET /api/logs/dnsmasq` are flushed immediately. Access logs are JSON on stdout. The query string, the request headers, and the response headers are dropped before the line is written. There is no rate limit in Caddy.

Two paths the app can call are outside this list. See the pull request for the cross-check. In short: Netdata's `GET /api/v2/data` fallback is not allowed, and a Kuma slug other than `house` is not allowed.

## Before you deploy

1. Replace `<PIN-ME>` in `compose.yaml` with the digest of the `caddy:2` image you intend to run. `gateway/test.sh` uses the floating `caddy:2` tag on a dev machine so the placeholder does not have to be a real digest. Do not deploy the floating tag. A pull on 2026-11-01 resolved `caddy:2` to v2.11.7, digest `sha256:36c24ad91a7ff7bc4c87fe22bfa8df3c4b18da0773d73fc12ee2c52b98c0bb7e`. That observation is not a pin.
2. Choose where the Pi-hole CA certificate lives on the Pi. Edit the volume line so that host path is mounted at `/etc/caddy/pihole-ca.pem`, read-only. The container path is fixed because the Caddyfile trusts that file. Mount the certificate only. Do not mount a private key. Do not commit the certificate or the key.
3. Keep port 8447 on `127.0.0.1`. The Caddyfile sets `bind 127.0.0.1` because a site address alone does not keep the socket off other interfaces. Do not remove that line, do not listen on `0.0.0.0`, and do not publish the port in Compose. Host networking is there so the gate can reach the other listeners on the Pi, not so the LAN can reach the gate.
4. Confirm the existing tunnel hostname `pistats.thestreetfam.com` will send traffic to `http://127.0.0.1:8447`, and that the hostname is protected with Access. This repository does not make that change.

The stock image's binary is owned by a non-root user and has `cap_net_bind_service` set on the file. Dropping every capability makes Linux refuse to start it (`operation not permitted`). Compose drops every capability and adds `NET_BIND_SERVICE` back only so that file can be executed. Port 8447 does not need it. `no-new-privileges` is set. The root filesystem is read-only. `/data`, `/config`, and `/tmp` are tmpfs. Memory is 64m, CPUs are 0.25, and the process limit is 64. The container restarts unless stopped. Docker keeps three 1m JSON log files.

## Deploy

Run these on the Pi, from this directory, after the pin and the CA path are filled in.

```sh
docker compose up -d
docker compose ps
```

Then add the Cloudflare rate limit rule below. Then run the checks.

## Rate limit

The free Cloudflare plan allows one rate limiting rule. The only counting characteristic is IP. The only period is 10 seconds, and the only block duration is 10 seconds. The expression may use the Path field. Do not add a second rule, and do not add a rate limit to the Caddyfile. Availability is listed at <https://developers.cloudflare.com/waf/rate-limiting-rules/#availability>.

Use one rule:

- Expression, Path field only: path starts with `/api/`, `/netdata/api/`, or `/kuma/api/`.

```
(starts_with(http.request.uri.path, "/api/") or starts_with(http.request.uri.path, "/netdata/api/") or starts_with(http.request.uri.path, "/kuma/api/"))
```

- Characteristic: IP.
- Requests: 60 in 10 seconds. More than 60 requests from one IP in that period blocks for 10 seconds.
- Action: Block.
- Mitigation timeout: 10 seconds.

`/healthz` is not under those prefixes, so this rule does not count it. Cloudflare's counter can lag by a few seconds, and it counts per data center, so the Pi may still see a short burst.

## Gravity

Cloudflare cuts a proxied response at about 100 seconds. Gravity on the Pi can take longer. The gate waits up to 310 seconds for gravity's response headers, so the gate is not what cuts the call. The app expects the cut at about 100 seconds. A phone that stops waiting is not, by itself, a failed gravity run. Check gravity on the Pi if you need to know.

## Checks

Use `127.0.0.1`, not a name that might resolve to IPv6. The samples use an obvious fake header. That is enough on localhost, because the gate only checks that the header is present. Do not put a real token in a shell command.

```sh
# No header. Expect 403.
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8447/healthz

# Header present. Expect 200 from the gate itself.
curl -sS -D - -o /dev/null -H 'Cf-Access-Jwt-Assertion: present' http://127.0.0.1:8447/healthz

# Unknown path, header present. Expect 404.
curl -sS -o /dev/null -w '%{http_code}\n' -H 'Cf-Access-Jwt-Assertion: present' http://127.0.0.1:8447/admin/

# Pi-hole login info, header present. Expect the Pi-hole status, often 200.
curl -sS -o /dev/null -w '%{http_code}\n' -H 'Cf-Access-Jwt-Assertion: present' http://127.0.0.1:8447/api/info/login
```

The health response should include `X-Content-Type-Options: nosniff` and `Cache-Control: no-store`.

A cloudflared origin health check that calls `/healthz` without the JWT header gets 403. Access has already decided for requests that came through the tunnel. Prefer no separate origin health check, or send the header from the Pi only.

`gateway/test.sh` is the dev check. It needs Docker, builds a throwaway CA in a temp directory, and never writes a key into the repo. It is not a Pi deploy.

## Logs

`docker logs` shows JSON access lines. The query string and the headers are already gone. Do not turn on debug logging. Debug lines can put a URL back on stderr. The Docker log cap is 1m times 3 files.

## Undo

From this directory:

```sh
docker compose down
```

That stops the listener on `127.0.0.1:8447`. Leave the tunnel `pi-grok-stats` in place. If the public name should stop answering, pause that hostname on the existing tunnel. Do not delete the tunnel, and do not change DNS, as part of undoing the gate. Disable the rate limit rule in Cloudflare if you want the free-plan slot back.

## Allowlist

`allowlist.json` and the named matchers in the Caddyfile are the same list. Adding a path means editing both. `gateway/test.sh` fails if they drift. Upstream is `pihole`, `netdata`, `kuma`, or `gateway`.
