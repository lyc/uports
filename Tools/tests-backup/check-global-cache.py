#!/usr/bin/env python3
"""Global site settings must win over stale framework cache symlinks."""
import hashlib
import http.server
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading


FRAMEWORK = Path(__file__).resolve().parents[2]


def main():
    with tempfile.TemporaryDirectory(prefix="uports-global-cache.") as directory:
        root = Path(directory)
        framework = root / "framework"
        shutil.copytree(FRAMEWORK / "Mk", framework / "Mk")
        stale = root / "stale"
        stale.mkdir()
        payload = b"verified global cache selection\n"
        filename = "global-cache.tar.gz"
        (stale / filename).write_bytes(payload)
        for name in ("distfiles", "packages", "scm"):
            (framework / name).symlink_to(stale)
        port = root / "port"
        port.mkdir()
        (port / "Makefile").write_text(
            'PORTNAME=global-cache\nDISTVERSION=1\nCATEGORIES=devel\n'
            'MASTERDIR=$(CURDIR)\nDISTFILES=global-cache.tar.gz\n'
            'include $(PORTSDIR)/Mk/linux.port.mk\n'
            'inspect:\n\t@printf "%s\\n" "$(DISTDIR)" '
            '"$(PACKAGES)" "$(SCMDIR)"\n')
        (port / "distinfo").write_text(
            f"SHA256 ({filename}) = {hashlib.sha256(payload).hexdigest()}\n"
            f"SIZE ({filename}) = {len(payload)}\n")
        sites = [root / name for name in ("dist-site", "pkg-site", "scm-site")]
        args = ["make", "-s", "--no-print-directory", "-C", str(port),
                f"PORTSDIR={framework}", f"portdir={framework}",
                "USE_GLOBALBASE=yes", f"DISTDIR_SITE={sites[0]}",
                f"PACKAGES_SITE={sites[1]}", f"SCMDIR_SITE={sites[2]}"]

        def run(*settings):
            return subprocess.check_output(args + list(settings), text=True,
                                           stderr=subprocess.STDOUT, timeout=20)

        selected = run("inspect").splitlines()
        assert selected == list(map(str, sites)), selected
        assert all(path.is_dir() for path in sites), sites
        explicit = [root / name for name in ("dist-explicit", "pkg-explicit",
                                             "scm-explicit")]
        overrides = [f"{key}={path}" for key, path in
                     zip(("DISTDIR", "PACKAGES", "SCMDIR"), explicit)]
        assert run(*overrides, "inspect").splitlines() == list(map(str, explicit))
        legacy = run("USE_GLOBALBASE=no", "inspect").splitlines()
        assert legacy == [str(framework / name) for name in
                          ("distfiles", "packages", "scm")], legacy
        requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                requests.append(self.path)
                self.send_response(200)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            mirror = f"MASTER_SITES=http://127.0.0.1:{server.server_port}/"
            run(mirror, "fetch")
            assert requests == [f"/{filename}"], requests
            archive = sites[0] / filename
            assert archive.read_bytes() == payload
            before = archive.stat().st_mtime_ns
            run(mirror, "fetch")
            assert len(requests) == 1 and archive.stat().st_mtime_ns == before
            archive.unlink()
            run(mirror, "fetch")
            assert len(requests) == 2 and archive.read_bytes() == payload
            for name in ("distfiles", "packages", "scm"):
                assert (framework / name).readlink() == stale
            assert (stale / filename).read_bytes() == payload
        finally:
            server.shutdown()
        print("Global cache selection/override/reuse/deleted archive: passed")


if __name__ == "__main__":
    main()
