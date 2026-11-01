#!/bin/bash
# Usage: seal-provisioned-ipa.sh <stage-dir-holding-Payload> <output.ipa.enc>
# Credentials and the encryption passphrase travel through environment variables, never argv.
set +x
set -euo pipefail
umask 077

STAGE="$1"
OUTPUT="$2"
APP="${STAGE}/Payload/StreetPi.app"
# Never retain a previous artifact after a skipped or failed attempt.
rm -f "${OUTPUT}"
trap 'rm -f "${APP}/AwayProvision.json" "${APP}/AwayProvision.plist"' EXIT
rm -f "${APP}/AwayProvision.json" "${APP}/AwayProvision.plist"

# Validate before writing anything. Errors name fields only, never their contents.
# Workflow command escaping also protects multiline values from command injection.
status=0
python3 - <<'PY' || status=$?
import os
import sys
from urllib.parse import urlsplit

names = ["AWAY_MAILBOX_URL", "AWAY_READ_TOKEN", "AWAY_GATEWAY_URL",
         "AWAY_ACCESS_CLIENT_ID", "AWAY_ACCESS_CLIENT_SECRET", "AWAY_IPA_PASSPHRASE"]
values = {name: os.environ.get(name, "") for name in names}
if os.environ.get("GITHUB_ACTIONS") == "true":
    for value in values.values():
        if value:
            escaped = value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
            print("::add-mask::" + escaped, flush=True)
missing = []
for group in (names[:2], names[2:5]):
    if any(values[name] for name in group):
        missing.extend(name for name in group if not values[name])
configured = any(values[name] for name in names[:5])
if configured and not (values["AWAY_IPA_PASSPHRASE"] or values["AWAY_READ_TOKEN"]):
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
        url = urlsplit(values[name].strip())
        valid = (url.scheme.lower() == "https" and url.hostname and not url.username
                 and not url.password and not url.query and not url.fragment)
    except ValueError:
        valid = False
    if not valid:
        invalid.append(name)
for name in names[1:2] + names[3:]:
    if values[name] and not values[name].strip():
        invalid.append(name)
if values["AWAY_READ_TOKEN"] and any(c.isspace() for c in values["AWAY_READ_TOKEN"].strip()):
    invalid.append("AWAY_READ_TOKEN")
if invalid:
    sys.exit("Invalid secrets: " + ", ".join(invalid))
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
                         "clientId": os.environ["AWAY_ACCESS_CLIENT_ID"],
                         "clientSecret": os.environ["AWAY_ACCESS_CLIENT_SECRET"]}
with open(sys.argv[1], "w") as file:
    json.dump(fields, file)
PY

export AWAY_IPA_PASSPHRASE="${AWAY_IPA_PASSPHRASE:-${AWAY_READ_TOKEN:-}}"
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
