#!/usr/bin/env bash
# Dev check for the away gateway. Needs Docker and a throwaway CA in a temp dir.
# It does not talk to the Pi, Cloudflare, or DNS, and it does not keep the keys.
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$root"

if ! docker info >/dev/null 2>&1; then
	if sudo -n docker info >/dev/null 2>&1; then
		docker() { sudo docker "$@"; }
	else
		echo "docker is not available" >&2
		exit 1
	fi
fi

tmp=$(mktemp -d)
chmod 700 "$tmp"
container=pistats-gateway-test
started=0

redact() {
	python3 -c '
import sys
text = sys.stdin.read()
for token in (
    "canary-not-a-secret",
    "fake-jwt-not-a-secret",
    "fake-access-client-id",
    "fake-access-client-secret",
    "fake-cookie-not-a-secret",
    "fake-sid-not-a-secret",
):
    text = text.replace(token, "[redacted]")
sys.stdout.write(text)
'
}

cleanup() {
	status=$?
	if [[ "$status" -ne 0 && "$started" -eq 1 ]]; then
		echo "---- caddy logs (redacted) ----" >&2
		docker logs "$container" 2>&1 | redact >&2 || true
	fi
	docker rm -f "$container" >/dev/null 2>&1 || true
	if [[ -f "$tmp/pids" ]]; then
		while read -r pid; do
			kill "$pid" >/dev/null 2>&1 || true
		done <"$tmp/pids"
	fi
	rm -rf "$tmp"
	exit "$status"
}
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
die() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

python3 - <<'PY'
import json, re, sys
from pathlib import Path
text = Path("Caddyfile").read_text()
allow = json.loads(Path("allowlist.json").read_text())
if not isinstance(allow, list) or not allow:
    sys.exit("allowlist.json is not a list")
seen = set()
for row in allow:
    if set(row) != {"method", "path", "upstream"}:
        sys.exit(f"bad allowlist row: {row}")
    if row["upstream"] not in {"pihole", "netdata", "kuma", "gateway"}:
        sys.exit(f"bad upstream: {row}")
    if "?" in row["path"]:
        sys.exit(f"query string in allowlist: {row['path']}")
    key = (row["method"], row["path"])
    if key in seen:
        sys.exit(f"duplicate allowlist row: {key}")
    seen.add(key)

found = {}
for match in re.finditer(r"@([A-Za-z0-9_]+)\s*\{([^}]*)\}", text):
    name, body = match.group(1), match.group(2)
    method = re.search(r"(?m)^\s*method\s+([A-Z]+)\s*$", body)
    path = re.search(r"(?m)^\s*path\s+(\S+)\s*$", body)
    if method and path:
        found[name] = (method.group(1), path.group(1))
if ("nojwt",) in []:
    pass
pairs = set(found.values())
if pairs != seen:
    missing = sorted(seen - pairs)
    extra = sorted(pairs - seen)
    sys.exit(f"drift missing={missing} extra={extra}")

handles = {}
for match in re.finditer(r"handle\s+@([A-Za-z0-9_]+)\s*\{([^}]*)\}", text):
    handles[match.group(1)] = match.group(2)
handles.pop("nojwt", None)
if set(handles) != set(found):
    missing = sorted(set(found) - set(handles))
    extra = sorted(set(handles) - set(found))
    sys.exit(f"matcher and handle names differ missing={missing} extra={extra}")

stream = {("GET", "/api/queries"), ("GET", "/api/logs/dnsmasq")}
gravity = {("POST", "/api/action/gravity")}
by_pair = {pair: name for name, pair in found.items()}
for row in allow:
    pair = (row["method"], row["path"])
    body = handles[by_pair[pair]]
    upstream = row["upstream"]
    if pair in stream:
        expect = "import pihole_stream"
    elif pair in gravity:
        expect = "import pihole_gravity"
    elif upstream == "pihole":
        expect = "import pihole"
    elif upstream == "netdata":
        expect = "import netdata"
    elif upstream == "kuma":
        expect = "import kuma"
    else:
        expect = 'respond "ok" 200'
    if expect not in body:
        sys.exit(f"{pair} handle is missing {expect!r}")
    if upstream == "pihole" and pair not in stream and pair not in gravity and "import pihole_" in body:
        sys.exit(f"{pair} uses a special pihole snippet")

if text.count("flush_interval -1") != 1:
    sys.exit("flush_interval -1 must appear once")
if "response_header_timeout 310s" not in text:
    sys.exit("gravity timeout missing")
if text.count("response_header_timeout 30s") != 4:
    sys.exit("expected four 30s proxy timeouts")
for needle in (
    "admin off",
    "auto_https off",
    "http://127.0.0.1:8447",
    "bind 127.0.0.1",
    "max_size 4KB",
    "tls_server_name pi.hole",
    "tls_trust_pool file /etc/caddy/pihole-ca.pem",
    "uri strip_prefix /netdata",
    "uri strip_prefix /kuma",
    "@nojwt not header Cf-Access-Jwt-Assertion *",
    "request>headers delete",
    "resp_headers delete",
):
    if needle not in text:
        sys.exit(f"Caddyfile missing {needle}")
if "insecure_skip_verify" in text or "rate_limit" in text:
    sys.exit("Caddyfile contains a forbidden directive")
if "0.0.0.0" in text:
    sys.exit("Caddyfile listens beyond localhost")

compose = Path("compose.yaml").read_text()
for needle in (
    "pistats-gateway",
    "caddy:2@sha256:<PIN-ME>",
    "network_mode: host",
    "read_only: true",
    "cap_drop:",
    "- ALL",
    "cap_add:",
    "- NET_BIND_SERVICE",
    "no-new-privileges:true",
    "mem_limit: 64m",
    "cpus: 0.25",
    "pids_limit: 64",
    "unless-stopped",
    'max-size: "1m"',
    'max-file: "3"',
    "/etc/caddy/Caddyfile:ro",
    "/etc/caddy/pihole-ca.pem:ro",
    "/data",
    "/config",
    "/tmp",
):
    if needle not in compose:
        sys.exit(f"compose.yaml missing {needle}")
print(f"drift: {len(allow)} allowlist rows match {len(found)} matchers")
PY

# Throwaway CA and a pi.hole certificate. Keys stay in $tmp and are removed on exit.
openssl req -x509 -newkey rsa:2048 -nodes \
	-keyout "$tmp/ca.key" -out "$tmp/ca.pem" -days 1 \
	-subj "/CN=StreetPi Gateway Test CA" \
	-addext "basicConstraints=critical,CA:TRUE" \
	-addext "keyUsage=critical,keyCertSign,cRLSign" >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes \
	-keyout "$tmp/pi.key" -out "$tmp/pi.csr" \
	-subj "/CN=pi.hole" >/dev/null 2>&1
cat >"$tmp/pi.ext" <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:pi.hole
EOF
openssl x509 -req -in "$tmp/pi.csr" -CA "$tmp/ca.pem" -CAkey "$tmp/ca.key" \
	-CAcreateserial -out "$tmp/pi.crt" -days 1 \
	-extfile "$tmp/pi.ext" >/dev/null 2>&1
chmod 600 "$tmp/ca.key" "$tmp/pi.key"
chmod 644 "$tmp/ca.pem" "$tmp/pi.crt"
openssl x509 -in "$tmp/pi.crt" -noout -ext subjectAltName | grep -q 'DNS:pi.hole'

pihole_port=18443
netdata_port=19998
kuma_port=18001
python3 - "$tmp/Caddyfile" "$pihole_port" "$netdata_port" "$kuma_port" <<'PY'
import pathlib, sys
dest, pihole, netdata, kuma = sys.argv[1:]
text = pathlib.Path("Caddyfile").read_text()
text = text.replace("https://127.0.0.1:443", f"https://127.0.0.1:{pihole}")
text = text.replace("127.0.0.1:19999", f"127.0.0.1:{netdata}")
text = text.replace("127.0.0.1:3001", f"127.0.0.1:{kuma}")
pathlib.Path(dest).write_text(text)
PY

: >"$tmp/pihole.jsonl"
: >"$tmp/netdata.jsonl"
: >"$tmp/kuma.jsonl"
: >"$tmp/pids"
python3 "$root/stubs/upstream.py" --name pihole --port "$pihole_port" \
	--record "$tmp/pihole.jsonl" --cert "$tmp/pi.crt" --key "$tmp/pi.key" \
	>"$tmp/pihole.err" 2>&1 &
echo $! >>"$tmp/pids"
python3 "$root/stubs/upstream.py" --name netdata --port "$netdata_port" \
	--record "$tmp/netdata.jsonl" >"$tmp/netdata.err" 2>&1 &
echo $! >>"$tmp/pids"
python3 "$root/stubs/upstream.py" --name kuma --port "$kuma_port" \
	--record "$tmp/kuma.jsonl" >"$tmp/kuma.err" 2>&1 &
echo $! >>"$tmp/pids"

wait_code() {
	local url=$1 expect=$2
	local i code
	for i in $(seq 1 50); do
		code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 1 "$url" || true)
		if [[ "$code" == "$expect" ]]; then
			return 0
		fi
		sleep 0.2
	done
	die "timed out waiting for $url (last ${code:-none}, expected $expect)"
}
wait_code "https://127.0.0.1:${pihole_port}/ready" 200
wait_code "http://127.0.0.1:${netdata_port}/ready" 200
wait_code "http://127.0.0.1:${kuma_port}/ready" 200
: >"$tmp/pihole.jsonl"
: >"$tmp/netdata.jsonl"
: >"$tmp/kuma.jsonl"

if ! docker image inspect caddy:2 >/dev/null 2>&1; then
	docker pull caddy:2 >/dev/null
fi
docker run --rm \
	-v "$root/Caddyfile:/etc/caddy/Caddyfile:ro" \
	-v "$tmp/ca.pem:/etc/caddy/pihole-ca.pem:ro" \
	caddy:2 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1

docker rm -f "$container" >/dev/null 2>&1 || true
docker run -d --name "$container" \
	--network host \
	--read-only \
	--tmpfs /data \
	--tmpfs /config \
	--tmpfs /tmp \
	--cap-drop ALL \
	--cap-add NET_BIND_SERVICE \
	--security-opt no-new-privileges \
	--memory 64m \
	--cpus 0.25 \
	--pids-limit 64 \
	-v "$tmp/Caddyfile:/etc/caddy/Caddyfile:ro" \
	-v "$tmp/ca.pem:/etc/caddy/pihole-ca.pem:ro" \
	caddy:2 caddy run --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
started=1
wait_code "http://127.0.0.1:8447/healthz" 403

jwt='fake-jwt-not-a-secret'
base='http://127.0.0.1:8447'
common=(
	-H "Cf-Access-Jwt-Assertion: ${jwt}"
	-H "CF-Access-Client-Id: fake-access-client-id"
	-H "CF-Access-Client-Secret: fake-access-client-secret"
	-H "Cookie: sid=fake-cookie-not-a-secret"
	-H "X-FTL-SID: fake-sid-not-a-secret"
)

python3 - "$base" <<'PY' | while IFS=$'\t' read -r method path; do
import json, sys
base = sys.argv[1]
for row in json.load(open("allowlist.json")):
    print(f"{row['method']}\t{row['path']}")
PY
	if [[ "$method" == "POST" ]]; then
		code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
			-X POST -H 'Content-Type: application/json' --data-binary '{}' \
			"${common[@]}" "$base$path" || true)
	else
		code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
			-X "$method" "${common[@]}" "$base$path" || true)
	fi
	case "$code" in
		2*) ;;
		*) die "$method $path returned $code, expected 2xx" ;;
	esac
done
say "allow: every allowlist row returned 2xx"

# Query strings are forwarded upstream and must not appear in the access log.
curl -sS -o /dev/null --max-time 5 "${common[@]}" \
	"$base/api/queries?n=canary-not-a-secret" || die "pihole query forward failed"
curl -sS -o /dev/null --max-time 5 "${common[@]}" \
	"$base/netdata/api/v1/data?chart=canary-not-a-secret" || die "netdata query forward failed"

denied=(
	"PUT /api/config/dns"
	"GET /admin/"
	"DELETE /api/domains/deny/exact/x"
	"GET /api/teleporter"
	"GET /kuma/dashboard"
	"GET /netdata/"
	"POST /api/queries"
	"GET /api/auth"
	"PUT /api/auth"
	"PATCH /api/dns/blocking"
	"POST /api/stats/summary"
	"DELETE /api/stats/summary"
	"GET /api/action/gravity"
	"DELETE /api/action/gravity"
	"POST /healthz"
	"PUT /healthz"
	"GET /api/config"
	"GET /api/config/dns"
	"POST /api/config/dns/hosts"
	"DELETE /api/domains/deny/exact"
	"GET /api/domains/deny/exact/extra"
	"POST /api/info/login"
	"GET /netdata/api/v1/info/extra"
	"POST /netdata/api/v1/data"
	"GET /kuma/api/status-page/house/extra"
	"POST /kuma/api/status-page/house"
	"GET /api/padd"
	"GET /metrics"
	"GET /api/v1/info"
	"POST /api/clients"
	"DELETE /api/queries"
	"GET /kuma/"
	"GET /netdata/api/"
	"OPTIONS /api/stats/summary"
	"GET /api/search"
	"POST /api/lists"
	"GET /admin"
	"GET /api/action/flush"
	"GET /api/queries/"
	"DELETE /api/domains/allow/exact"
	"GET /netdata/api/v2/data"
	"GET /kuma/api/status-page/other"
	"GET /kuma/api/status-page/heartbeat/other"
)
if [[ "${#denied[@]}" -lt 30 ]]; then
	die "need at least 30 disallowed pairs"
fi
denied_ok=0
for pair in "${denied[@]}"; do
	method=${pair%% *}
	path=${pair#* }
	code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
		-X "$method" "${common[@]}" "$base$path" || true)
	if [[ "$code" != "404" ]]; then
		die "$method $path returned $code, expected 404"
	fi
	denied_ok=$((denied_ok + 1))
done
say "deny: $denied_ok disallowed pairs returned 404"

code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$base/healthz" || true)
[[ "$code" == "403" ]] || die "GET /healthz without JWT returned $code"
code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$base/api/stats/summary" || true)
[[ "$code" == "403" ]] || die "GET /api/stats/summary without JWT returned $code"
code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
	-X POST -H 'Content-Type: application/json' --data-binary '{}' \
	-H 'X-No-Jwt-Probe: no-jwt-probe' "$base/api/auth" || true)
[[ "$code" == "403" ]] || die "POST /api/auth without JWT returned $code"
say "no jwt: 403"

python3 -c 'import os,sys; os.write(sys.stdout.fileno(), b"a"*5120)' >"$tmp/big.bin"
code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
	-X POST -H 'Content-Type: application/octet-stream' \
	-H 'X-Body-Probe: big-body-probe' \
	-H "Cf-Access-Jwt-Assertion: ${jwt}" \
	--data-binary @"$tmp/big.bin" "$base/api/auth" || true)
[[ "$code" == "413" ]] || die "5120-byte body returned $code, expected 413"
say "body 5120: 413"

hdr=$(curl -sS -D - -o /dev/null --max-time 5 \
	-H "Cf-Access-Jwt-Assertion: ${jwt}" "$base/healthz")
printf '%s' "$hdr" | grep -qi '^x-content-type-options: nosniff' || die "missing nosniff on /healthz"
printf '%s' "$hdr" | grep -qi '^cache-control: no-store' || die "missing no-store on /healthz"
printf '%s' "$hdr" | grep -q '^HTTP/.* 200' || die "/healthz with JWT was not 200"
body=$(curl -sS --max-time 5 -H "Cf-Access-Jwt-Assertion: ${jwt}" "$base/healthz")
[[ "$body" == "ok" ]] || die "/healthz body was not ok"
say "healthz: 200 ok, nosniff, no-store"

python3 - "$tmp" <<'PY'
import json, sys
from pathlib import Path
tmp = Path(sys.argv[1])
allow = json.loads(Path("allowlist.json").read_text())
by_up = {}
for row in allow:
    by_up.setdefault(row["upstream"], set()).add((row["method"], row["path"]))

def load(name):
    path = tmp / f"{name}.jsonl"
    rows = []
    for line in path.read_text().splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows

banned = {
    "cf-access-client-id",
    "cf-access-client-secret",
    "cf-access-jwt-assertion",
    "cookie",
}
banned_values = (
    "fake-jwt-not-a-secret",
    "fake-access-client-id",
    "fake-access-client-secret",
    "fake-cookie-not-a-secret",
)
pihole = load("pihole")
netdata = load("netdata")
kuma = load("kuma")
if not pihole or not netdata or not kuma:
    sys.exit("a stub recorded no requests")

def check(rows, upstream, rewrite):
    saw_sid = False
    for row in rows:
        keys = {key.lower() for key in row["headers"]}
        if keys & banned:
            sys.exit(f"{upstream} saw a stripped header: {sorted(keys & banned)}")
        blob = json.dumps(row["headers"])
        for value in banned_values:
            if value in blob:
                sys.exit(f"{upstream} saw a stripped header value")
        if "no-jwt-probe" in blob:
            sys.exit(f"{upstream} saw a request with no JWT")
        if row["headers"].get("x-ftl-sid") == "fake-sid-not-a-secret":
            saw_sid = True
        path = row["path"].split("?", 1)[0]
        if upstream == "netdata":
            if row["path"].startswith("/netdata"):
                sys.exit(f"netdata prefix was not stripped: {row['path']}")
            gateway_path = "/netdata" + path
        elif upstream == "kuma":
            if row["path"].startswith("/kuma"):
                sys.exit(f"kuma prefix was not stripped: {row['path']}")
            gateway_path = "/kuma" + path
        else:
            gateway_path = path
        if (row["method"], gateway_path) not in by_up[upstream]:
            sys.exit(f"unexpected {upstream} request {row['method']} {row['path']}")
    return saw_sid

if not check(pihole, "pihole", None):
    sys.exit("pihole stub did not see X-FTL-SID")
check(netdata, "netdata", None)
check(kuma, "kuma", None)
joined = "\n".join(path.read_text() for path in (tmp/"pihole.jsonl", tmp/"netdata.jsonl", tmp/"kuma.jsonl"))
if "/healthz" in joined:
    sys.exit("healthz was proxied")
if "canary-not-a-secret" not in (tmp/"pihole.jsonl").read_text():
    sys.exit("pihole stub did not receive the query string")
if "chart=canary-not-a-secret" not in (tmp/"netdata.jsonl").read_text():
    sys.exit("netdata stub did not receive the query string")
if "/api/v1/data?chart=canary-not-a-secret" not in (tmp/"netdata.jsonl").read_text():
    sys.exit("netdata path was not stripped before the query")
print("stubs: access headers stripped, prefixes stripped, query forwarded")
PY

logs=$(docker logs "$container" 2>&1 || true)
printf '%s' "$logs" | python3 -c '
import json, sys
raw = sys.stdin.read()
banned = (
    "canary-not-a-secret",
    "fake-jwt-not-a-secret",
    "fake-access-client-id",
    "fake-access-client-secret",
    "fake-cookie-not-a-secret",
)
for token in banned:
    if token in raw:
        sys.exit("access log leaked a filtered value")
found = False
paths = set()
for line in raw.splitlines():
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        item = json.loads(line)
    except json.JSONDecodeError:
        continue
    logger = item.get("logger") or ""
    if not str(logger).startswith("http.log.access"):
        continue
    found = True
    request = item.get("request") or {}
    uri = request.get("uri", "")
    if not uri or "?" in uri or "headers" in request or "resp_headers" in item:
        sys.exit("access log kept a query string or headers, or dropped the path")
    paths.add(uri)
if not found:
    sys.exit("no JSON access log lines")
if "/healthz" not in paths:
    sys.exit("access log did not keep the /healthz path")
print("access log: query string and headers dropped")
'

image=$(docker image inspect caddy:2 --format '{{index .RepoDigests 0}} {{.Id}}')
version=$(docker run --rm caddy:2 caddy version)
say "image: $version"
say "digest: $image"
say "PASS"
