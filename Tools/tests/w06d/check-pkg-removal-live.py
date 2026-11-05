#!/usr/bin/env python3
"""Check removal using real gforth packages and their legacy install state."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import traceback


LEGACY_COMMIT = "54bba9d1eb19af5b1ccb9f335e273f236aa10d17"


def snapshot(directory):
    answer = {}
    if not directory.exists():
        return answer
    for path in directory.rglob("*"):
        name = str(path.relative_to(directory))
        if path.is_symlink():
            answer[name] = ["link", os.readlink(path)]
        elif path.is_file():
            answer[name] = [
                "file", hashlib.sha256(path.read_bytes()).hexdigest(),
                path.stat().st_mode,
            ]
        else:
            answer[name] = ["directory", path.stat().st_mode]
    return answer


def owned_snapshot(destination, name, version="0.7.9"):
    rows = (destination / "var/db/pkg").read_text().splitlines()
    full_name = name + "-" + version + ":"
    row = next(row for row in rows if row.startswith(full_name))
    fields = row.split()
    manifest = destination / "var/db" / fields[-1]
    paths = [
        fields[3].strip("/") + "/" + line[2:]
        for line in manifest.read_text().splitlines()
        if line.startswith("./")
    ]
    data = snapshot(destination)
    return {path: data[path] for path in paths}


def validate(run, framework, report):
    cache = framework / "packages/All-linux-x86_64"
    names = ["gforth", "gforth-libffcall"]
    archives = {name: cache / f"{name}-0.7.9.pkg" for name in names}
    bootstrap = cache / "gforth-bootstrap-0.7.3.pkg"
    original_hashes = {}
    for path in [*archives.values(), bootstrap]:
        original_hashes[path] = hashlib.sha256(path.read_bytes()).hexdigest()
    tool = run / "pkg.sh"
    shutil.copy2(framework / "Mk/Scripts/pkg.sh", tool)
    legacy = run / "legacy-pkg.sh"
    legacy.write_bytes(subprocess.check_output([
        "git", "-C", str(framework), "show",
        f"{LEGACY_COMMIT}:Mk/Scripts/pkg.sh",
    ]))
    working = run / "empty"
    working.mkdir()
    results = []

    def command(label, destination, arguments, old=False, expected=0):
        environment = os.environ.copy()
        environment["DESTDIR"] = str(destination)
        process = subprocess.run(
            ["sh", str(legacy if old else tool), *map(str, arguments)],
            cwd=working, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, timeout=90,
        )
        output = run / f"{label}.log"
        output.write_text(process.stdout + f"\nexit={process.returncode}\n")
        if process.returncode != expected:
            raise RuntimeError(f"Unexpected result for {label}; see {output}")
        results.append({"case": label, "exit": process.returncode})
        report(f"PASS: {label} (exit={process.returncode})")
        return process.stdout

    def setup(destination, selected, with_bootstrap=False):
        # Prior production installer creates genuine pre-W06C overlap.
        for name in selected:
            command(f"{destination.name}-setup-{name}", destination,
                    ["add", "-q", archives[name]], old=True)
        if with_bootstrap:
            command(f"{destination.name}-setup-bootstrap", destination,
                    ["add", "-q", bootstrap], old=True)

    for first, second in [(names[0], names[1]), (names[1], names[0])]:
        destination = run / first
        setup(destination, [first, second], with_bootstrap=True)
        retained = owned_snapshot(destination, second)
        first_paths = owned_snapshot(destination, first)
        empty = [
            path for path, value in retained.items()
            if path in first_paths and value[0] == "directory"
            and not any((destination / path).iterdir())
        ]
        if not empty:
            raise RuntimeError("Real packages have no shared empty directory")
        before = snapshot(destination)
        output = command(first + "-preview", destination,
                         ["delete", "-n", first])
        if snapshot(destination) != before:
            raise RuntimeError("Preview changed destination")
        binary = str(destination / "usr/local/bin/gforth")
        if ("keep " + binary not in output or
                "rm -f " + binary + "\n" in output):
            raise RuntimeError("Preview did not preserve shared executable")
        command(first + "-remove", destination, ["delete", "-q", first])
        command(first + "-registration-removed", destination,
                ["info", "-e", first], expected=1)
        if owned_snapshot(destination, second) != retained:
            raise RuntimeError("Remaining Flavor lost files or directories")
        if not (destination / "usr/local/bin/gforth-0.7.3").exists():
            raise RuntimeError("Exact selection removed bootstrap")
        if not all((destination / path).is_dir() for path in empty):
            raise RuntimeError("Shared empty directory removed")
        user = destination / "usr/local/share/man/w06d-user-file"
        user.write_text("preserve user file\n")
        remaining = owned_snapshot(destination, second)
        remaining.update(owned_snapshot(
            destination, "gforth-bootstrap", "0.7.3"))
        before = snapshot(destination)
        command(first + "-preview-all", destination, ["delete", "-na"])
        if snapshot(destination) != before:
            raise RuntimeError("Bulk preview changed destination")
        command(first + "-remove-all", destination, ["delete", "-qa"])
        if (destination / "var/db/pkg").exists():
            raise RuntimeError("Bulk removal left registrations")
        if user.read_text() != "preserve user file\n":
            raise RuntimeError("User file lost during directory cleanup")
        for path, value in remaining.items():
            target = destination / path
            if value[0] != "directory" and (
                    target.exists() or target.is_symlink()):
                raise RuntimeError("Bulk removal left a listed file: " + path)
        if any((destination / path).exists() for path in empty):
            raise RuntimeError("Last owner left a shared empty directory")

    destination = run / "invalid"
    setup(destination, names)
    receipt = next((destination / "var/db").glob(
        "gforth-libffcall-*-pkg-plist.*"))
    original = receipt.read_bytes()
    receipt.write_bytes(original + b"@exec do-not-run\n")
    before = snapshot(destination)
    command("invalid-bulk", destination, ["delete", "-qa"], expected=1)
    if snapshot(destination) != before:
        raise RuntimeError("Invalid manifest caused partial bulk deletion")
    receipt.unlink()
    before = snapshot(destination)
    command("missing-receipt", destination, ["delete", "-qa"], expected=1)
    if snapshot(destination) != before:
        raise RuntimeError("Missing receipt caused partial bulk deletion")
    receipt.write_bytes(original)

    def race(label, destination, operations):
        alias = run / (label + "-alias")
        alias.symlink_to(destination)
        processes = []
        for index, (selected, args) in enumerate(zip(
                [destination, alias], operations)):
            environment = os.environ.copy()
            environment["DESTDIR"] = str(selected)
            output = (run / f"{label}-{index}.log").open("w")
            process = subprocess.Popen(
                [str(tool), *map(str, args)], cwd=working,
                env=environment, stdout=output, stderr=subprocess.STDOUT,
            )
            processes.append((process, output))
        statuses = []
        for process, output in processes:
            code = process.wait(timeout=90)
            output.write(f"\nexit={code}\n")
            output.close()
            statuses.append(code)
        results.append({"case": label, "exits": statuses})
        return statuses

    destination = run / "concurrent-delete"
    setup(destination, names)
    codes = race("concurrent-delete", destination, [
        ["delete", "-q", names[0]], ["delete", "-q", names[1]],
    ])
    if codes != [0, 0] or (destination / "var/db/pkg").exists():
        raise RuntimeError(f"Concurrent removal failed: {codes}")
    if any((destination / "usr/local").rglob("*")):
        raise RuntimeError("Concurrent removal left orphaned shared payload")
    report("PASS: concurrent removals through aliases")
    destination = run / "concurrent-add-delete"
    setup(destination, [names[0]])
    codes = race("concurrent-add-delete", destination, [
        ["delete", "-q", names[0]], ["add", "-q", archives[names[1]]],
    ])
    if codes[0] != 0 or codes[1] not in [0, 1]:
        raise RuntimeError(f"Concurrent add/delete failed: {codes}")
    database = destination / "var/db/pkg"
    rows = database.read_text().splitlines() if database.exists() else []
    if len(rows) != (1 if codes[1] == 0 else 0):
        raise RuntimeError("Concurrent add/delete registrations inconsistent")
    if any(row.startswith("gforth-0.7.9:") for row in rows):
        raise RuntimeError("Concurrent removal left default registration")
    binary = destination / "usr/local/bin/gforth"
    if binary.exists() != (codes[1] == 0):
        raise RuntimeError("Concurrent add/delete payload inconsistent")
    if codes[1] == 0:
        owned_snapshot(destination, names[1])
    elif any((destination / "usr/local").rglob("*")):
        raise RuntimeError("Concurrent removal left orphaned payload")
    report("PASS: concurrent add/delete through aliases")
    for path, digest in original_hashes.items():
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"Original cached archive changed: {path}")
    (run / "summary.json").write_text(json.dumps({
        "legacy_setup_commit": LEGACY_COMMIT,
        "cases": results,
    }, indent=2) + "\n")


def main():
    framework = Path(__file__).resolve().parents[3]
    run = Path(tempfile.mkdtemp(prefix="uports-w06d-manual."))
    Path("/tmp/uports-w06d-latest").write_text(str(run) + "\n")
    status = 1
    with (run / "validation.log").open("w") as log:
        def report(message):
            print(message, flush=True)
            print(message, file=log, flush=True)

        report(f"Framework: {framework}")
        report(f"Evidence: {run}")
        try:
            validate(run, framework, report)
            report("PASS: W06D ownership-aware removal")
            status = 0
        except Exception:
            traceback.print_exc(file=log)
            report("FAIL: see validation.log and per-case output")
        report(f"exit={status}")
    raise SystemExit(status)


if __name__ == "__main__":
    main()
