#!/bin/bash
# Proves the sealing step with fixture values: skipped without secrets, encrypted with them,
# readable with the token, and nothing left behind in the plain payload.
set -euo pipefail

# Never let a caller's provisioning credentials enter a fixture test.
unset AWAY_MAILBOX_URL AWAY_READ_TOKEN

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${WORK}/stage/Payload/StreetPi.app"
echo "app" > "${WORK}/stage/Payload/StreetPi.app/StreetPi"
SEALED="${WORK}/sealed.ipa.enc"

env -u AWAY_MAILBOX_URL -u AWAY_READ_TOKEN bash "${ROOT}/scripts/seal-provisioned-ipa.sh" "${WORK}/stage" "${SEALED}"
[[ ! -e "${SEALED}" ]] || { echo "Sealed with no secrets" >&2; exit 1; }

AWAY_MAILBOX_URL="https://mailbox.example.test" \
  bash "${ROOT}/scripts/seal-provisioned-ipa.sh" "${WORK}/stage" "${SEALED}"
[[ ! -e "${SEALED}" ]] || { echo "Sealed with one secret" >&2; exit 1; }

export AWAY_MAILBOX_URL="https://mailbox.example.test"
export AWAY_READ_TOKEN="fixture-not-a-real-read-token"
bash "${ROOT}/scripts/seal-provisioned-ipa.sh" "${WORK}/stage" "${SEALED}"

[[ ! -e "${WORK}/stage/Payload/StreetPi.app/AwayProvision.plist" ]] || {
  echo "The plain payload kept the plist" >&2
  exit 1
}
if grep -q "fixture-not-a-real-read-token" "${SEALED}"; then
  echo "The token is readable in the sealed file" >&2
  exit 1
fi

if AWAY_READ_TOKEN="wrong-fixture-token" openssl enc -d -aes-256-cbc -md sha256 -pbkdf2 -iter 200000 \
  -pass env:AWAY_READ_TOKEN -in "${SEALED}" -out "${WORK}/wrong.zip" 2>/dev/null &&
  unzip -tq "${WORK}/wrong.zip" >/dev/null 2>&1; then
  echo "A wrong password opened the sealed file" >&2
  exit 1
fi

openssl enc -d -aes-256-cbc -md sha256 -pbkdf2 -iter 200000 -pass env:AWAY_READ_TOKEN \
  -in "${SEALED}" -out "${WORK}/opened.zip"
unzip -q "${WORK}/opened.zip" -d "${WORK}/opened"
python3 - "${WORK}/opened/Payload/StreetPi.app/AwayProvision.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as file:
    fields = plistlib.load(file)
assert fields == {
    "mailboxURL": "https://mailbox.example.test",
    "readToken": "fixture-not-a-real-read-token",
}
PY

# A failed encryption must also remove the clear resource from the staged app.
if bash "${ROOT}/scripts/seal-provisioned-ipa.sh" "${WORK}/stage" "${WORK}/missing/sealed.enc" >/dev/null 2>&1; then
  echo "Sealing unexpectedly succeeded with an invalid output path" >&2
  exit 1
fi
[[ ! -e "${WORK}/stage/Payload/StreetPi.app/AwayProvision.plist" ]] || {
  echo "Failed sealing left the clear plist behind" >&2
  exit 1
}
echo "Sealing works."
