#!/usr/bin/env python3
"""Grouped metadata, local tarballs, and non-destructive placement checks."""
import hashlib
import http.server
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import threading

FRAMEWORK = Path(__file__).resolve().parents[2]
FIXTURE = FRAMEWORK / "Tools/tests/cases/github"
PLACE = FRAMEWORK / "Mk/Scripts/github-place.sh"


def tar_bytes(root, files):
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w:gz") as archive:
        for name, content in files.items():
            info = tarfile.TarInfo(f"{root}/{name}")
            info.size = len(content)
            archive.addfile(info, io.BytesIO(content))
    return data.getvalue()


def main():
    def metadata(*settings, ok=True):
        result = subprocess.run(["make", "--no-print-directory", "-s", "-C",
                                 str(FIXTURE), f"PORTSDIR={FRAMEWORK}",
                                 *settings, "group-snapshot"], text=True,
                                capture_output=True, timeout=15)
        assert (result.returncode == 0) == ok, result.stdout + result.stderr
        return result.stdout

    shared = metadata("GH_ACCOUNT=shared:a,b", "GH_PROJECT=one:a two:b",
                      "GH_TAGNAME=v2:a,b", "GH_SUBDIR=vendor/one:a vendor/two:b")
    assert "a|shared|one|v2|vendor/one|shared-one-v2_GH0.tar.gz|one-2" in shared
    assert "b|shared|two|v2|vendor/two|shared-two-v2_GH0.tar.gz|two-2" in shared
    inherited = metadata("GH_ACCOUNT=owner", "GH_TAGNAME=v2",
                         "GH_PROJECT=one:a", "GH_TUPLE=tuple:two:v3:b/vendor/two")
    assert "a|owner|one|v2||owner-one-v2_GH0.tar.gz|one-2" in inherited
    assert "b|tuple|two|v3|vendor/two|tuple-two-v3_GH0.tar.gz|two-3" in inherited
    metadata("GH_TUPLE=owner:one:release/v2:lib/vendor/one")
    for setting in ("GH_ACCOUNT=owner:all", "GH_PROJECT=one:bad-name",
                    "GH_TAGNAME=main:lib", "GH_SUBDIR=../escape:lib",
                    "GH_SUBDIR=/absolute:lib", "GH_SUBDIR=a//b:lib",
                    "GH_SUBDIR=a/./b:lib", "GH_TUPLE=owner:one:v1:lib/../bad",
                    "GH_TUPLE=owner:one", "GH_TUPLE=owner:one:v1:lib:x"):
        metadata(setting, ok=False)
    metadata("GH_PROJECT=one:lib", "USE_SCM=git", ok=False)
    metadata("GH_PROJECT=one:a,b", "GH_ACCOUNT=owner:a other:b", ok=False)
    metadata("GH_PROJECT=one:a,b", "GH_SUBDIR=first:a second:b", ok=False)
    print("GitHub grouped defaults/comma groups/tuples/diagnostics: passed")

    bodies = {}
    requests = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            requests.append(self.path)
            body = bodies.get(self.path)
            if body is None:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    with tempfile.TemporaryDirectory(prefix="uports-github-groups.") as directory:
        task = Path(directory)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{server.server_port}/"
        try:
            # Child deliberately declared before its parent, with both group
            # archives included in the real Git baseline/maintained patch.
            for alternative, nodefault in ((False, False), (True, False),
                                           (False, True), (True, True)):
                port = task / f"port-{alternative}-{nodefault}"
                shutil.copytree(FIXTURE, port)
                archives = {
                    "demo-demo-1.2_GH0.tar.gz": tar_bytes("demo-1.2", {
                        "hello.c": b'#include <stdio.h>\nint main(void) { puts("unpatched archive"); return 0; }\n'}),
                    "demo-one-v2_GH0.tar.gz": tar_bytes("one-2", {"parent.txt": b"parent\n"}),
                    "demo-two-v3_GH0.tar.gz": tar_bytes("two-3", {"child.txt": b"child\n"}),
                }
                bodies.update({f"/{name}": data for name, data in archives.items()})
                (port / "distinfo").write_text("".join(
                    f"SHA256 ({name}) = {hashlib.sha256(data).hexdigest()}\n"
                    f"SIZE ({name}) = {len(data)}\n"
                    for name, data in archives.items()))
                args = ["make", "--no-print-directory", "-s", "-C", str(port),
                        f"PORTSDIR={FRAMEWORK}", f"DISTDIR={port}/cache",
                        f"MASTER_SITE_OVERRIDE={base}", "DISTINFO_REQUIRED=yes",
                        "GH_PROJECT=two:child one:parent",
                        "GH_TAGNAME=v3:child v2:parent",
                        "GH_SUBDIR=aliases/self vendor/one/sub/two:child vendor/one:parent",
                        f"DESTDIR={port}/installed", "PREFIX=/usr"]
                if nodefault:
                    args += ["USE_GITHUB=nodefault"]
                if alternative:
                    args += ["USE_ALTERNATIVE=yes", f"ALTERNATIVE_WRKDIR={port}/src"]
                target = "extract" if nodefault else "stage"
                before = len(requests)
                result = subprocess.run(args + [target], text=True,
                                        capture_output=True, timeout=30)
                assert result.returncode == 0, result.stdout + result.stderr
                physical = port / ("src" if alternative else "work")
                main_root = physical / ("demo-1.2" if nodefault else
                                         "demo-demo-1.2_GH0")
                # nodefault retains generic DISTNAME; hosted default uses
                # its upstream extraction root rather than its cache name.
                if not nodefault:
                    main_root = physical / "demo-1.2"
                placed = main_root / "vendor/one/sub/two/child.txt"
                assert placed.read_bytes() == b"child\n"
                assert (main_root / "vendor/one/parent.txt").read_bytes() == b"parent\n"
                assert (physical / "one-2").is_symlink()
                assert (physical / "two-3").is_symlink()
                assert (main_root / "aliases/self").resolve() == main_root.resolve()
                assert len(requests) == before + (2 if nodefault else 3)
                if not nodefault:
                    binary = port / "work/stage/usr/bin/hello"
                    assert subprocess.check_output([binary], text=True).strip() == (
                        "patched GitHub archive")
                    tracked = subprocess.check_output(
                        ["git", "-C", str(main_root), "ls-files"], text=True)
                    assert "vendor/one/sub/two/child.txt" in tracked
                placed.write_bytes(b"developer edit\n")
                # Explicit placement replay preserves edits and relative links;
                # normal repeat target must neither fetch nor re-extract.
                subprocess.run(args + ["github-place-sources"], check=True,
                               capture_output=True, timeout=20)
                subprocess.run(args + [target], check=True,
                               capture_output=True, timeout=30)
                assert placed.read_bytes() == b"developer edit\n"
                assert len(requests) == before + (2 if nodefault else 3)
            print("GitHub nested/nodefault/alternative/Git-stage/repeat: passed")
            # A nodefault group may itself be the main root without a move.
            port = task / "nodefault-main-group"
            shutil.copytree(FIXTURE, port)
            result = subprocess.run([
                "make", "--no-print-directory", "-s", "-C", str(port),
                f"PORTSDIR={FRAMEWORK}", "USE_GITHUB=nodefault",
                "GH_PROJECT=demo:source", "GH_TAGNAME=1.2:source",
                f"MASTER_SITE_OVERRIDE={base}", f"DISTDIR={port}/cache",
                f"DESTDIR={port}/installed", "PREFIX=/usr", "stage"],
                text=True, capture_output=True, timeout=30)
            assert result.returncode == 0, result.stdout + result.stderr
            assert subprocess.check_output([port / "work/stage/usr/bin/hello"],
                                           text=True).strip() == "patched GitHub archive"
            print("GitHub nodefault unplaced group as main source: passed")
        finally:
            server.shutdown()

        # Adversarial layouts fail before even the first safe move.
        for mode in ("populated", "symlink", "nested-symlink", "duplicate",
                     "alias-symlink", "alias-populated"):
            case = task / mode
            extract = case / "work"
            root = extract / "main"
            one, two = extract / "one-1", extract / "two-1"
            for path in (root, one, two):
                path.mkdir(parents=True)
            (one / "kept").write_text("source")
            outside = case / "outside"
            outside.mkdir()
            records = ["DEFAULT|-|-", "a|one-1|safe", "b|two-1|bad"]
            if mode == "populated":
                (root / "bad").mkdir()
                (root / "bad/keep").write_text("developer")
            elif mode == "symlink":
                (root / "bad").symlink_to(outside)
            elif mode == "nested-symlink":
                (one / "inside").symlink_to(outside)
                records[-1] = "b|two-1|safe/inside/child"
            elif mode == "duplicate":
                records[-1] = "b|two-1|safe"
            elif mode == "alias-symlink":
                records[0] = "DEFAULT|-|self"
                (root / "self").symlink_to(outside)
            else:
                records[0] = "DEFAULT|-|self"
                (root / "self").mkdir()
                (root / "self/keep").write_text("developer")
                (extract / "-").symlink_to(outside)
            result = subprocess.run(["/bin/sh", str(PLACE), *records],
                                    env=dict(os.environ, GH_EXTRACT_ROOT=str(extract),
                                             GH_MAIN_ROOT=str(root)),
                                    capture_output=True, timeout=10)
            assert result.returncode != 0
            assert (one / "kept").read_text() == "source"
            assert one.is_dir() and not one.is_symlink()
            assert not (root / "safe").exists()
            assert not list(outside.iterdir())
        print("GitHub placement conflict/symlink/preflight preservation: passed")


if __name__ == "__main__":
    main()
