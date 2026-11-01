#!/bin/bash
# Builds an unsigned iOS .ipa. A sideload tool re-signs it later. No Apple Developer account.
set +x
set -euo pipefail

python3 - <<'PYMASK'
import os
if os.environ.get("GITHUB_ACTIONS") == "true":
    for name in ("AWAY_MAILBOX_URL", "AWAY_READ_TOKEN", "AWAY_GATEWAY_URL",
                 "AWAY_ACCESS_CLIENT_ID", "AWAY_ACCESS_CLIENT_SECRET", "AWAY_IPA_PASSPHRASE"):
        value = os.environ.get(name, "")
        if value:
            print("::add-mask::" + value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A"))
PYMASK

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${ROOT}/build/unsigned"
OUTPUT="${ROOT}/StreetPi-unsigned.ipa"

rm -rf "${DERIVED}" "${OUTPUT}" "${ROOT}/StreetPi-provisioned.ipa.enc"
env -u AWAY_MAILBOX_URL -u AWAY_READ_TOKEN -u AWAY_GATEWAY_URL \
  -u AWAY_ACCESS_CLIENT_ID -u AWAY_ACCESS_CLIENT_SECRET -u AWAY_IPA_PASSPHRASE xcodebuild \
  -project "${ROOT}/StreetPi.xcodeproj" \
  -scheme StreetPi \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "${DERIVED}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

APP="$(find "${DERIVED}" -name 'StreetPi.app' -type d | head -n 1)"
if [[ -z "${APP}" ]]; then
  echo "StreetPi.app was not produced" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
mkdir -p "${STAGE}/Payload"
cp -R "${APP}" "${STAGE}/Payload/"
rm -rf "${STAGE}/Payload/StreetPi.app/_CodeSignature"
rm -f "${STAGE}/Payload/StreetPi.app/AwayProvision.json" "${STAGE}/Payload/StreetPi.app/AwayProvision.plist"
(
  cd "${STAGE}"
  zip -qr "${OUTPUT}" Payload
)
echo "Wrote ${OUTPUT}"

bash "${ROOT}/scripts/seal-provisioned-ipa.sh" "${STAGE}" "${ROOT}/StreetPi-provisioned.ipa.enc"
