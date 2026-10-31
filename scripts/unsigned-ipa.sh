#!/bin/bash
# Builds an unsigned iOS .ipa. A sideload tool re-signs it later. No Apple Developer account.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${ROOT}/build/unsigned"
OUTPUT="${ROOT}/StreetPi-unsigned.ipa"

rm -rf "${DERIVED}" "${OUTPUT}" "${ROOT}/StreetPi-provisioned.ipa.enc"
xcodebuild \
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
(
  cd "${STAGE}"
  zip -qr "${OUTPUT}" Payload
)
echo "Wrote ${OUTPUT}"

bash "${ROOT}/scripts/seal-provisioned-ipa.sh" "${STAGE}" "${ROOT}/StreetPi-provisioned.ipa.enc"
