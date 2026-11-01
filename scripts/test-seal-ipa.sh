#!/bin/bash
# Fork-safe tests. Inherited credentials are never used by the fixture processes.
set +x
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "${ROOT}" <<'PY'
import base64
import itertools
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

root = Path(sys.argv[1])
names = ["AWAY_MAILBOX_URL", "AWAY_READ_TOKEN", "AWAY_GATEWAY_URL",
         "AWAY_ACCESS_CLIENT_ID", "AWAY_ACCESS_CLIENT_SECRET", "AWAY_IPA_PASSPHRASE"]
fixtures = dict(zip(names, ["https://mailbox.example.test", "test-read-token-FAKE",
                          "https://gateway.example.test", "test-client.access",
                          "cfast_FAKE_access_secret", "test-passphrase-FAKE-at-least-32-characters"]))
env = {k: v for k, v in os.environ.items() if k not in names}
env["GITHUB_ACTIONS"] = "false"

def run(args, environment, success=True):
    result = subprocess.run(args, env=environment, capture_output=True)
    # Never print captured output, even on failure.
    checked = list(fixtures.values())
    for name in names:
        value = environment.get(name, "")
        if value.strip():
            checked.extend((value, value.strip()))
    for value in checked:
        assert value.encode() not in result.stdout + result.stderr, "Credential appeared in output"
    assert success is None or (result.returncode == 0) == success, f"Unexpected command status: {result.returncode}"
    return result

def matches_seed(path, expected):
    try:
        with zipfile.ZipFile(path) as archive:
            return (archive.testzip() is None
                    and json.loads(archive.read("Payload/StreetPi.app/AwayProvision.json")) == expected)
    except (zipfile.BadZipFile, KeyError, ValueError, UnicodeError, OSError):
        return False

with tempfile.TemporaryDirectory() as work:
    work = Path(work)
    stage = work / "stage"
    app = stage / "Payload/StreetPi.app"
    app.mkdir(parents=True)
    (app / "StreetPi").write_text("fake app")
    sealed = work / "sealed.enc"
    blank = work / "blank.ipa"
    with zipfile.ZipFile(blank, "w") as archive:
        archive.write(app / "StreetPi", "Payload/StreetPi.app/StreetPi")

    # All 64 presence combinations cover no secrets, partial sets, both groups, and fallback.
    round_trips = 0
    for bits in itertools.product((False, True), repeat=len(names)):
        present = {name: fixtures[name] for name, enabled in zip(names, bits) if enabled}
        test_env = dict(env, **present)
        mailbox = all(name in present for name in names[:2])
        gateway = all(name in present for name in names[2:5])
        partial = (any(name in present for name in names[:2]) and not mailbox
                   or any(name in present for name in names[2:5]) and not gateway)
        configured = mailbox or gateway
        passphrase = present.get(names[5]) or present.get(names[1])
        valid = not partial and (not configured or bool(passphrase))
        # A stale artifact must disappear on skip/failure.
        sealed.write_text("stale")
        result = run(["bash", str(root / "scripts/seal-provisioned-ipa.sh"), str(stage), str(sealed)],
                     test_env, success=valid)
        assert not (app / "AwayProvision.json").exists(), "Clear seed left behind"
        assert not (app / "AwayProvision.plist").exists(), "Legacy clear seed left behind"
        if not valid:
            for group in (names[:2], names[2:5]):
                if any(name in present for name in group):
                    for name in group:
                        if name not in present:
                            assert name.encode() in result.stderr, "Missing secret name omitted"
        if not valid or not configured:
            assert not sealed.exists(), "Unexpected artifact"
            continue
        expected = {"version": 2}
        if mailbox:
            expected["mailbox"] = {"url": fixtures[names[0]], "readToken": fixtures[names[1]]}
        if gateway:
            expected["gateway"] = {"url": fixtures[names[2]], "clientId": fixtures[names[3]],
                                   "clientSecret": fixtures[names[4]]}
        opened = work / "opened.ipa"
        decrypt_env = dict(env, TEST_IPA_PASSWORD=passphrase)
        run(["openssl", "enc", "-d", "-aes-256-cbc", "-md", "sha256", "-pbkdf2", "-iter", "200000",
             "-pass", "env:TEST_IPA_PASSWORD", "-in", str(sealed), "-out", str(opened)], decrypt_env)
        with zipfile.ZipFile(opened) as archive:
            resource = archive.getinfo("Payload/StreetPi.app/AwayProvision.json")
            assert (resource.external_attr >> 16) & 0o777 == 0o644, "Seed is not app-readable"
            assert json.loads(archive.read(resource)) == expected
            assert "Payload/StreetPi.app/AwayProvision.plist" not in archive.namelist()
        result = run(["openssl", "enc", "-d", "-aes-256-cbc", "-md", "sha256", "-pbkdf2", "-iter", "200000",
                      "-pass", "env:TEST_IPA_PASSWORD", "-in", str(sealed), "-out", str(opened)],
                     dict(env, TEST_IPA_PASSWORD="wrong-FAKE-password"), success=None)
        assert result.returncode != 0 or not matches_seed(opened, expected), "Wrong password opened the IPA"
        round_trips += 1
        with zipfile.ZipFile(blank) as archive:
            clear = b"".join(archive.read(name) for name in archive.namelist())
            assert not any(value.encode() in clear for value in fixtures.values()), "Blank IPA contains credentials"
        assert not any(value.encode() in sealed.read_bytes() for value in fixtures.values())

    # Fixed, fake-only reviewer reproduction: wrong key, valid CBC padding, exit zero, invalid ZIP.
    # No retries or random-salt search are used by this regression check.
    regression = work / "wrong-padding.enc"
    regression.write_bytes(base64.b64decode(
        "U2FsdGVkX1/SZft1htePotG6pIoZz2LktS1LPdeSwMb57oaFeqQ0JHY//Ub0vOttv+HaBWyxcdQPXNOE"
        "ufH5JJ4HiUMQ6Idytz2e2P21nur/wv9GRZIWzG7gd4zmrE3cSeibB+BdAUIsWvLWAWKut25Cgant2u6f"
        "39D1WVLKjSQog4NN2aWsvKVhQrAEM1rVtfT8AhABlH7+kFaj9+BpwoeSgbudSasvvT1ez76RudVwyNpa"
        "/I0BoNaDpHybA05K0K3fx/Oo72OisAbh+PWlTqyAwVWwBwhIuPppFTcl4Pk="
    ))
    result = run(["openssl", "enc", "-d", "-aes-256-cbc", "-md", "sha256", "-pbkdf2", "-iter", "200000",
                  "-pass", "env:TEST_IPA_PASSWORD", "-in", str(regression), "-out", str(opened)],
                 dict(env, TEST_IPA_PASSWORD="wrong-FAKE-password"), success=None)
    assert result.returncode == 0, "Fixed CBC padding reproduction changed"
    assert not matches_seed(opened, expected), "Wrong password opened the regression IPA"
    regression.write_bytes(b"not an encrypted IPA")
    run(["openssl", "enc", "-d", "-aes-256-cbc", "-md", "sha256", "-pbkdf2", "-iter", "200000",
         "-pass", "env:TEST_IPA_PASSWORD", "-in", str(regression), "-out", str(opened)],
        dict(env, TEST_IPA_PASSWORD="wrong-FAKE-password"), success=False)

    # Edge whitespace is normalized for headers and for the passphrase used by OpenSSL.
    padded_env = dict(env, **{name: " \t" + value + "\r\n" for name, value in fixtures.items()})
    run(["bash", str(root / "scripts/seal-provisioned-ipa.sh"), str(stage), str(sealed)], padded_env)
    run(["openssl", "enc", "-d", "-aes-256-cbc", "-md", "sha256", "-pbkdf2", "-iter", "200000",
         "-pass", "env:TEST_IPA_PASSWORD", "-in", str(sealed), "-out", str(opened)],
        dict(env, TEST_IPA_PASSWORD=fixtures[names[5]]))
    assert matches_seed(opened, expected), "Normalized credentials did not round-trip"

    # The 32-character minimum is inclusive, and gateway root slashes/valid ports are accepted.
    run(["bash", str(root / "scripts/seal-provisioned-ipa.sh"), str(stage), str(sealed)],
        dict(env, **dict(fixtures, AWAY_IPA_PASSPHRASE="test-FAKE-" + "x" * 22,
                        AWAY_GATEWAY_URL="https://gateway.example.test:8443/")))

    # Invalid input and encryption failures leave neither a resource nor an artifact.
    invalid_changes = [
        {names[0]: "http://mailbox.example.test"}, {names[2]: "http://gateway.example.test"},
        {names[3]: " "}, {names[4]: " "}, {names[5]: " "}, {names[5]: "password1"},
        {names[5]: "x" * 31},
    ]
    for name in (names[0], names[2]):
        for suffix in (":notaport", ":65536", ":0", "?", "#"):
            invalid_changes.append({name: "https://gateway.example.test" + suffix})
        invalid_changes.extend([{name: "https://user@gateway.example.test"},
                                {name: "https://@gateway.example.test"}])
    for path in ("/foo", "//", "/%2F"):
        invalid_changes.append({names[2]: "https://gateway.example.test" + path})
    for name in (names[1], names[3], names[4], names[5]):
        for whitespace in (" ", "\t", "\n", "\r"):
            invalid_changes.append({name: "test-FAKE-padding-32-characters" + whitespace + "inside"})
    for change in invalid_changes:
        run(["bash", str(root / "scripts/seal-provisioned-ipa.sh"), str(stage), str(sealed)],
            dict(env, **dict(fixtures, **change)), success=False)
        assert not sealed.exists()
        assert not (app / "AwayProvision.json").exists()
    run(["bash", str(root / "scripts/seal-provisioned-ipa.sh"), str(stage), str(work / "absent/sealed.enc")],
        dict(env, **fixtures), success=False)
    assert not (app / "AwayProvision.json").exists()

    # Exercise the real unsigned build script with a fake xcodebuild, including a stale seed.
    # Work in an isolated fixture root so no build products enter the checkout.
    build_root = work / "build-root"
    (build_root / "scripts").mkdir(parents=True)
    for name in ("unsigned-ipa.sh", "seal-provisioned-ipa.sh"):
        (build_root / "scripts" / name).write_bytes((root / "scripts" / name).read_bytes())
    bin_dir = work / "bin"
    bin_dir.mkdir()
    stub = bin_dir / "xcodebuild"
    stub.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
assert not any(name.startswith("AWAY_") for name in os.environ)
path = pathlib.Path(sys.argv[sys.argv.index("-derivedDataPath") + 1]) / "StreetPi.app"
path.mkdir(parents=True)
(path / "StreetPi").write_text("fake app")
(path / "AwayProvision.json").write_text("stale seed")
(path / "AwayProvision.plist").write_text("stale legacy seed")
''')
    stub.chmod(0o700)
    for present in ({}, fixtures):
        run(["bash", str(build_root / "scripts/unsigned-ipa.sh")],
            dict(env, **present, PATH=str(bin_dir) + os.pathsep + env["PATH"]))
        with zipfile.ZipFile(build_root / "StreetPi-unsigned.ipa") as archive:
            assert not any("AwayProvision" in name for name in archive.namelist())
            clear = b"".join(archive.read(name) for name in archive.namelist())
            assert not any(value.encode() in clear for value in fixtures.values())
        assert (build_root / "StreetPi-provisioned.ipa.enc").exists() == bool(present)

    # Both entry points use the shared masking path, including raw/normalized values and injection escaping.
    for script, args in ((root / "scripts/seal-provisioned-ipa.sh", [str(stage), str(sealed)]),
                         (build_root / "scripts/unsigned-ipa.sh", [])):
        for invalid in (False, True):
            mask_env = dict(env, **fixtures, GITHUB_ACTIONS="true",
                            PATH=str(bin_dir) + os.pathsep + env["PATH"])
            mask_env[names[4]] = " \tcfast_FAKE_access_secret\r\n"
            if invalid:
                mask_env[names[4]] = "cfast_FAKE%\r\n::error::fake"
            result = subprocess.run(["bash", str(script)] + args, env=mask_env, capture_output=True)
            assert (result.returncode == 0) != invalid
            lines = result.stdout.decode().splitlines()
            for name in names:
                for value in (mask_env[name], mask_env[name].strip()):
                    escaped = value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
                    assert "::add-mask::" + escaped in lines
            # Actual mask commands are consumed by Actions. No other line may contain a credential.
            ordinary = "\n".join(line for line in lines if not line.startswith("::add-mask::"))
            for value in fixtures.values():
                assert value not in ordinary + result.stderr.decode()
            assert not any(line.startswith("::error::") for line in lines)
print(f"IPA sealing passed: 64 secret combinations, {round_trips} v2 round-trips, "
      "CBC exit-zero regression, normalization, URL/password rejection, resource mode, blank builds and shared masks.")
PY
