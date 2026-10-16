#!/usr/bin/env python3
"""Hosted archive naming through real checksum/extract/Git-patch/stage phases."""
import hashlib
import http.server
import io
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import threading

FRAMEWORK = Path(__file__).resolve().parents[2]


def archive_bytes(source_root):
    output = io.BytesIO()
    code = b'#include <stdio.h>\nint main(void) { puts("unpatched archive"); return 0; }\n'
    with tarfile.open(fileobj=output, mode="w:gz") as archive:
        member = tarfile.TarInfo(f"{source_root}/hello.c")
        member.size = len(code)
        archive.addfile(member, io.BytesIO(code))
    return output.getvalue()


def main():
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

    with tempfile.TemporaryDirectory(prefix="uports-github.") as directory:
        root = Path(directory)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{server.server_port}/"
        try:
            for index, (tag, sanitized, extracted) in enumerate([
                    ("v1.2", "v1.2", "1.2"),
                    ("release/v2.0+rc--1", "release-v2.0+rc--1",
                     "release-v2.0-rc-1"),
                    ("0123456789abcdef0123456789abcdef01234567",) * 3]):
                port = root / f"port-{index}"
                shutil.copytree(FRAMEWORK / "Tools/tests/cases/github", port)
                filename = f"owner-project-1.2-{sanitized}_GH0.tar.gz"
                body = archive_bytes(f"project-{extracted}")
                bodies[f"/{filename}"] = body
                evidence = port / "distinfo"
                evidence.write_text(
                    f"SHA256 (hosted/{filename}) = "
                    f"{hashlib.sha256(body).hexdigest()}\n"
                    f"SIZE (hosted/{filename}) = {len(body)}\n")
                args = ["make", "--no-print-directory", "-s", "-C", str(port),
                        f"PORTSDIR={FRAMEWORK}", "GH_ACCOUNT=owner",
                        "GH_PROJECT=project", f"GH_TAGNAME={tag}",
                        f"MASTER_SITES={base}", f"DISTDIR={root}/cache",
                        "DIST_SUBDIR=hosted", "DISTINFO_REQUIRED=yes",
                        f"DESTDIR={root}/installed", "PREFIX=/usr"]
                result = subprocess.run(args + ["stage"], text=True,
                                        capture_output=True, timeout=30)
                assert result.returncode == 0, result.stdout + result.stderr
                source = port / "work" / f"project-{extracted}"
                binary = port / "work/stage/usr/bin/hello"
                assert subprocess.check_output([binary], text=True).strip() == (
                    "patched GitHub archive")
                assert (source / ".git").is_dir(), "archive Git baseline missing"
                assert requests.count(f"/{filename}") == 1
                subprocess.run(args + ["stage"], check=True, capture_output=True,
                               timeout=30)
                assert requests.count(f"/{filename}") == 1
                assert subprocess.check_output([binary], text=True).strip() == (
                    "patched GitHub archive")
            print("GitHub tag/commit checksum/extract/Git-patch/stage/runtime: passed")
        finally:
            server.shutdown()


if __name__ == "__main__":
    main()
