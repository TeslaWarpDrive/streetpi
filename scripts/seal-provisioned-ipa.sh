#!/bin/bash
# Usage: seal-provisioned-ipa.sh <stage-dir-holding-Payload> <output.ipa.enc>
# This public repository has publicly downloadable artifacts. The encrypted copy contains Access
# credentials; a mailbox read-token holder can also open them when the fallback passphrase is used.
# Credentials and the encryption passphrase travel through environment variables, never argv.
# Do not add `set -x`.
set +x
set -euo pipefail
umask 077

# Shared with unsigned-ipa.sh; mask before build tools or validators run.
python3 - <<'PYMASK'
import os
if os.environ.get("GITHUB_ACTIONS") == "true":
    for name in ("AWAY_MAILBOX_URL", "AWAY_READ_TOKEN", "AWAY_GATEWAY_URL",
                 "AWAY_ACCESS_CLIENT_ID", "AWAY_ACCESS_CLIENT_SECRET", "AWAY_IPA_PASSPHRASE"):
        value = os.environ.get(name, "")
        for masked in dict.fromkeys((value, value.strip())):
            if masked:
                escaped = masked.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
                print("::add-mask::" + escaped, flush=True)
PYMASK
if [[ "${1:-}" == --mask-only ]]; then
  exit 0
fi

STAGE="$1"
OUTPUT="$2"
APP="${STAGE}/Payload/StreetPi.app"
# Never retain a previous artifact after a skipped or failed attempt.
rm -f "${OUTPUT}"
trap 'rm -f "${APP}/AwayProvision.json" "${APP}/AwayProvision.plist"' EXIT
rm -f "${APP}/AwayProvision.json" "${APP}/AwayProvision.plist"

# Validate before writing anything. Errors name fields only, never their contents.
status=0
python3 - <<'PY' || status=$?
import os
import sys
from urllib.parse import urlsplit

names = ["AWAY_MAILBOX_URL", "AWAY_READ_TOKEN", "AWAY_GATEWAY_URL",
         "AWAY_ACCESS_CLIENT_ID", "AWAY_ACCESS_CLIENT_SECRET", "AWAY_IPA_PASSPHRASE"]
values = {name: os.environ.get(name, "").strip() for name in names}
# Presence is based on raw values so whitespace-only configuration fails rather than disappearing.
present = {name: bool(os.environ.get(name, "")) for name in names}
missing = []
for group in (names[:2], names[2:5]):
    if any(present[name] for name in group):
        missing.extend(name for name in group if not present[name])
configured = any(present[name] for name in names[:5])
if configured and not (present["AWAY_IPA_PASSPHRASE"] or present["AWAY_READ_TOKEN"]):
    missing.append("AWAY_IPA_PASSPHRASE (or AWAY_READ_TOKEN)")
if missing:
    sys.exit("Missing secrets: " + ", ".join(missing))
if not configured:
    sys.exit(10)
invalid = []
for name in ("AWAY_MAILBOX_URL", "AWAY_GATEWAY_URL"):
    if not values[name]:
        continue
    try:
        url = urlsplit(values[name])
        port = url.port  # Accessing this property rejects malformed and out-of-range ports.
        valid = (url.scheme.lower() == "https" and url.hostname and url.username is None
                 and url.password is None and "?" not in values[name] and "#" not in values[name]
                 and not any(c.isspace() or ord(c) < 32 for c in values[name])
                 and (port is None or 1 <= port <= 65535)
                 and (name != "AWAY_GATEWAY_URL" or url.path in ("", "/")))
    except ValueError:
        valid = False
    if not valid:
        invalid.append(name)
for name in names:
    if present[name] and not values[name]:
        invalid.append(name)
for name in ("AWAY_READ_TOKEN", "AWAY_ACCESS_CLIENT_ID", "AWAY_ACCESS_CLIENT_SECRET", "AWAY_IPA_PASSPHRASE"):
    if any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in values[name]):
        invalid.append(name)
if present["AWAY_IPA_PASSPHRASE"] and len(values["AWAY_IPA_PASSPHRASE"]) < 32:
    invalid.append("AWAY_IPA_PASSPHRASE")
if invalid:
    sys.exit("Invalid secrets: " + ", ".join(dict.fromkeys(invalid)))
PY
if [[ "$status" == 10 ]]; then
  echo "Away secrets are not set. Skipping the provisioned IPA."
  exit 0
elif [[ "$status" != 0 ]]; then
  exit "$status"
fi

python3 - "${APP}/AwayProvision.json" <<'PY'
import json
import os
import sys

fields = {"version": 2}
if os.environ.get("AWAY_MAILBOX_URL"):
    fields["mailbox"] = {"url": os.environ["AWAY_MAILBOX_URL"].strip(),
                         "readToken": os.environ["AWAY_READ_TOKEN"].strip()}
if os.environ.get("AWAY_GATEWAY_URL"):
    fields["gateway"] = {"url": os.environ["AWAY_GATEWAY_URL"].strip(),
                         "clientId": os.environ["AWAY_ACCESS_CLIENT_ID"].strip(),
                         "clientSecret": os.environ["AWAY_ACCESS_CLIENT_SECRET"].strip()}
with open(sys.argv[1], "w") as file:
    json.dump(fields, file)
# The staging directory is private; the installed bundle resource must be readable by the app.
os.chmod(sys.argv[1], 0o644)
PY

export AWAY_IPA_PASSPHRASE="$(python3 - <<'PY'
import os
print((os.environ.get("AWAY_IPA_PASSPHRASE") or os.environ.get("AWAY_READ_TOKEN", "")).strip(), end="")
PY
)"
# No clear provisioned IPA is written to disk.
if ! (
  cd "${STAGE}"
  zip -qr - Payload
) | openssl enc -aes-256-cbc -md sha256 -salt -pbkdf2 -iter 200000 \
  -pass env:AWAY_IPA_PASSPHRASE -out "${OUTPUT}"; then
  rm -f "${OUTPUT}"
  exit 1
fi
echo "Wrote the encrypted provisioned IPA."
