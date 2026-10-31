#!/bin/bash
# Seals a provisioned copy of an unzipped IPA payload for Away mode.
#
# Usage: seal-provisioned-ipa.sh <stage-dir-holding-Payload> <output.ipa.enc>
# Reads AWAY_MAILBOX_URL and AWAY_READ_TOKEN from the environment. Without both it writes nothing.
#
# This repo is public, and anyone signed in to GitHub can download its Actions artifacts. So the
# provisioned IPA never leaves here in the clear. It is encrypted with the read token, which means
# opening it reveals nothing the holder didn't already have. Values stay in the environment and
# never go on a command line. Do not add `set -x` here.
set -euo pipefail

STAGE="$1"
OUTPUT="$2"
APP="${STAGE}/Payload/StreetPi.app"

if [[ -z "${AWAY_MAILBOX_URL:-}" || -z "${AWAY_READ_TOKEN:-}" ]]; then
  echo "Away secrets are not set. Skipping the provisioned IPA."
  exit 0
fi

# Remove the clear bundle resource even if plist creation, zip, or encryption fails.
trap 'rm -f "${APP}/AwayProvision.plist"' EXIT

python3 - "${APP}/AwayProvision.plist" <<'PY'
import os
import plistlib
import sys

fields = {
    "mailboxURL": os.environ["AWAY_MAILBOX_URL"].strip(),
    "readToken": os.environ["AWAY_READ_TOKEN"].strip(),
}
with open(sys.argv[1], "wb") as file:
    plistlib.dump(fields, file)
PY

# The zip goes straight into openssl, so no clear provisioned IPA is ever written to disk.
(
  cd "${STAGE}"
  zip -qr - Payload
) | openssl enc -aes-256-cbc -md sha256 -salt -pbkdf2 -iter 200000 -pass env:AWAY_READ_TOKEN -out "${OUTPUT}"

rm -f "${APP}/AwayProvision.plist"
echo "Wrote the encrypted provisioned IPA."
