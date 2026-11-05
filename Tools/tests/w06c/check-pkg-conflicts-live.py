#!/usr/bin/env python3
"""Check production package conflicts using real cached gforth archives."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import traceback


def snapshot(directory):
    result = {}
    if not directory.exists():
        return result
    for path in directory.rglob("*"):
        relative = str(path.relative_to(directory))
        if path.is_symlink():
            result[relative] = ["link", os.readlink(path)]
        elif path.is_file():
            result[relative] = [
                "file", hashlib.sha256(path.read_bytes()).hexdigest(),
                path.stat().st_mode, path.stat().st_mtime_ns,
            ]
        else:
            result[relative] = ["directory", path.stat().st_mode]
    return result


def validate(run, framework, report):
    cache = framework / "packages/All-linux-x86_64"
    names = ["gforth", "gforth-libffcall"]
    archives = {name: cache / f"{name}-0.7.9.pkg" for name in names}
    bootstrap = cache / "gforth-bootstrap-0.7.3.pkg"
    for path in [*archives.values(), bootstrap]:
        if not path.is_file():
            raise RuntimeError(f"Required real cached package missing: {path}")
    before_archives = {
        str(path): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in [*archives.values(), bootstrap]
    }
    binary_dir = run / "bin"
    binary_dir.mkdir()
    tool = binary_dir / "pkg.sh"
    shutil.copy2(framework / "Mk/Scripts/pkg.sh", tool)
    working = run / "empty"
    working.mkdir()
    results = []

    def command(label, destination, arguments, expected=0):
        environment = os.environ.copy()
        environment["DESTDIR"] = str(destination)
        process = subprocess.run(
            [str(tool), *map(str, arguments)], cwd=working,
            env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, timeout=90,
        )
        output = run / f"{label}.log"
        output.write_text(
            process.stdout + f"\nexit={process.returncode}\n"
        )
        if process.returncode != expected:
            raise RuntimeError(f"Unexpected exit for {label}; see {output}")
        results.append({"case": label, "exit": process.returncode})
        report(f"PASS: {label} (exit={process.returncode})")

    for first, second in [(names[0], names[1]), (names[1], names[0])]:
        destination = run / first
        command(f"{first}-install", destination,
                ["add", "-q", archives[first]])
        command(f"{first}-reinstall", destination,
                ["add", "-q", archives[first]])
        before = snapshot(destination)
        command(f"{first}-conflict", destination,
                ["add", "-q", archives[second]], expected=1)
        if snapshot(destination) != before:
            raise RuntimeError("Rejected Flavor changed files/registration")
        command(f"{first}-bootstrap", destination,
                ["add", "-q", bootstrap])

    for label in ["unmanaged", "directory-target", "symlink-parent"]:
        destination = run / label
        target = destination / "usr/local/bin/gforth"
        target.parent.mkdir(parents=True)
        if label == "unmanaged":
            target.write_text("preserve unmanaged file\n")
        elif label == "directory-target":
            target.mkdir()
            (target / "preserve").write_text("preserve directory\n")
        else:
            target.parent.rmdir()
            outside = run / "outside"
            outside.mkdir()
            (outside / "preserve").write_text("preserve outside\n")
            target.parent.symlink_to(outside)
        before = snapshot(destination)
        command(label, destination, ["add", "-q", archives[names[0]]],
                expected=1)
        if snapshot(destination) != before:
            raise RuntimeError(f"Rejected install changed {label} destination")
        if label == "symlink-parent":
            if list(outside.iterdir()) != [outside / "preserve"]:
                raise RuntimeError("Install followed a directory symlink")

    destination = run / "concurrent"
    destination.mkdir()
    alias = run / "concurrent-alias"
    alias.symlink_to(destination)
    processes = []
    for name, selected in zip(names, [destination, alias]):
        environment = os.environ.copy()
        environment["DESTDIR"] = str(selected)
        output = (run / f"concurrent-{name}.log").open("w")
        process = subprocess.Popen(
            [str(tool), "add", "-q", str(archives[name])],
            cwd=working, env=environment, stdout=output,
            stderr=subprocess.STDOUT,
        )
        processes.append((name, process, output))
    statuses = []
    for name, process, output in processes:
        status = process.wait(timeout=90)
        output.write(f"\nexit={status}\n")
        output.close()
        statuses.append(status)
    if sorted(statuses) != [0, 1]:
        raise RuntimeError(f"Concurrent install results: {statuses}")
    registrations = (destination / "var/db/pkg").read_text().splitlines()
    if len(registrations) != 1:
        raise RuntimeError("Concurrent installs left invalid registrations")
    results.append({"case": "concurrent-path-aliases", "exits": statuses})
    report("PASS: concurrent path aliases (one winner, one rejection)")
    for path, digest in before_archives.items():
        if hashlib.sha256(Path(path).read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"Original cached archive changed: {path}")
    (run / "summary.json").write_text(json.dumps(results, indent=2) + "\n")


def main():
    framework = Path(__file__).resolve().parents[3]
    run = Path(tempfile.mkdtemp(prefix="uports-w06c-manual."))
    Path("/tmp/uports-w06c-latest").write_text(str(run) + "\n")
    status = 1
    with (run / "validation.log").open("w") as log:
        def report(message):
            print(message, flush=True)
            print(message, file=log, flush=True)

        report(f"Framework: {framework}")
        report(f"Evidence: {run}")
        try:
            validate(run, framework, report)
            report("PASS: W06C standalone install conflicts")
            status = 0
        except Exception:
            traceback.print_exc(file=log)
            report("FAIL: see validation.log and per-case output")
        report(f"exit={status}")
    raise SystemExit(status)


if __name__ == "__main__":
    main()
