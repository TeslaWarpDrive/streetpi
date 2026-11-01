#!/bin/bash
# Fork-safe tests. Inherited credentials are never used by the fixture processes.
set +x
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "${ROOT}" <<'PY'
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
                          "cfast_FAKE_access_secret", "test-passphrase-FAKE"]))
env = {k: v for k, v in os.environ.items() if k not in names}
env["GITHUB_ACTIONS"] = "false"

def run(args, environment, success=True):
    result = subprocess.run(args, env=environment, capture_output=True)
    # Never print captured output, even on failure.
    for value in fixtures.values():
        assert value.encode() not in result.stdout + result.stderr, "Credential appeared in output"
    assert (result.returncode == 0) == success, f"Unexpected command status: {result.returncode}"
    return result

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
            assert json.loads(archive.read("Payload/StreetPi.app/AwayProvision.json")) == expected
            assert "Payload/StreetPi.app/AwayProvision.plist" not in archive.namelist()
        run(["openssl", "enc", "-d", "-aes-256-cbc", "-md", "sha256", "-pbkdf2", "-iter", "200000",
             "-pass", "env:TEST_IPA_PASSWORD", "-in", str(sealed), "-out", str(opened)],
            dict(env, TEST_IPA_PASSWORD="wrong-FAKE-password"), success=False)
        round_trips += 1
        with zipfile.ZipFile(blank) as archive:
            clear = b"".join(archive.read(name) for name in archive.namelist())
            assert not any(value.encode() in clear for value in fixtures.values()), "Blank IPA contains credentials"
        assert not any(value.encode() in sealed.read_bytes() for value in fixtures.values())

    # Invalid input and encryption failures leave neither a resource nor an artifact.
    for change in ({names[0]: "http://mailbox.example.test"}, {names[2]: "http://gateway.example.test"},
                   {names[3]: " "}, {names[4]: " "}, {names[5]: " "}):
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

    # Check GitHub mask commands with fake values, including command escaping.
    mask_env = dict(env, **fixtures, GITHUB_ACTIONS="true")
    mask_env[names[4]] = "cfast_FAKE%\r\n::error::fake"
    result = subprocess.run(["bash", str(root / "scripts/seal-provisioned-ipa.sh"), str(stage), str(sealed)],
                            env=mask_env, capture_output=True)
    assert result.returncode == 0
    lines = result.stdout.decode().splitlines()
    for name in names:
        escaped = mask_env[name].replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
        assert "::add-mask::" + escaped in lines
    assert not result.stderr
    assert not any(line.startswith("::error::") for line in lines)
print(f"IPA sealing passed: 64 secret combinations, {round_trips} v2 round-trips, blank build isolation, cleanup and masks.")
PY
