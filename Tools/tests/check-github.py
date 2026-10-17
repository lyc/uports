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


def check_git_mode(root):
    upstream = root / "upstream"
    upstream.mkdir()
    (upstream / "hello.c").write_text(
        '#include <stdio.h>\n'
        'int main(void) { puts("unpatched archive"); return 0; }\n')
    subprocess.run(["git", "init", "-q", upstream], check=True)
    subprocess.run(["git", "-C", upstream, "add", "hello.c"], check=True)
    subprocess.run(["git", "-C", upstream, "-c", "user.name=uports tests",
                    "-c", "user.email=tests@example.invalid", "commit", "-qm",
                    "initial"], check=True)
    subprocess.run(["git", "-C", upstream, "tag", "1.2"], check=True)
    subprocess.run(["git", "-C", upstream, "tag", "2.0"], check=True)
    upstream_revision = subprocess.check_output(
        ["git", "-C", upstream, "rev-parse", "1.2"], text=True).strip()

    port = root / "port-git"
    shutil.copytree(FRAMEWORK / "Tools/tests/cases/github", port)
    (root / "packages").mkdir()
    args = ["make", "--no-print-directory", "-s", "-C", str(port),
            f"PORTSDIR={FRAMEWORK}", "SOURCE_MODE=git",
            "UPORTS_DEPENDENCIES=none",
            f"SCM_REPO_URL={upstream}",
            f"SCM_CACHE_REPO={root}/upstream.git", "SCM_CACHE_UPDATE=no",
            f"PACKAGES={root}/packages",
            f"DESTDIR={root}/installed-git", "PREFIX=/usr"]
    result = subprocess.run(args + ["package"], text=True, capture_output=True,
                            timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    source = port / "work/demo-1.2-git-1.2"
    binary = port / "work/stage/usr/bin/hello"
    assert source.is_dir(), "explicit Git mode did not use its distinct root"
    assert subprocess.check_output([binary], text=True).strip() == (
        "patched GitHub archive")

    revision = subprocess.check_output(
        ["git", "-C", source, "rev-parse", "HEAD"], text=True).strip()
    state = (port / "work/source.state").read_text()
    assert "mode|git\n" in state
    assert f"resolved-commit|{upstream_revision}\n" in state
    package = port / "work/pkg/demo-1.2.pkg"
    package_contents = package.read_bytes()
    assert b"PVER: 2\n" == package_contents[:8]
    assert b"source-state|mode|git\n" in package_contents
    assert f"source-state|resolved-commit|{upstream_revision}\n".encode() \
        in package_contents
    subprocess.run(args + ["package"], check=True, capture_output=True,
                   timeout=30)
    repeated_revision = subprocess.check_output(
        ["git", "-C", source, "rev-parse", "HEAD"], text=True).strip()
    assert repeated_revision == revision
    assert subprocess.check_output([binary], text=True).strip() == (
        "patched GitHub archive")

    assert package.read_bytes() == package_contents
    marker = source / "developer-note"
    marker.write_text("preserve this checkout\n")

    changed = subprocess.run(args + ["GH_TAGNAME=2.0", "package"], text=True,
                             capture_output=True, timeout=30)
    assert changed.returncode == 0, changed.stdout + changed.stderr
    changed_source = port / "work/demo-1.2-git-2.0"
    assert changed_source.is_dir(), "Git ref change did not select a new root"
    changed_state = (port / "work/source.state").read_text()
    assert "ref|2.0\n" in changed_state
    changed_package = package.read_bytes()
    assert changed_package != package_contents
    assert b"source-state|ref|2.0\n" in changed_package
    assert subprocess.check_output([binary], text=True).strip() == (
        "patched GitHub archive")

    saved_cookies = sorted(port.glob("work/*._done.*"))
    dry = subprocess.run(args + ["-n", "package"], text=True,
                         capture_output=True, timeout=30)
    assert dry.returncode == 0, dry.stdout + dry.stderr
    assert (port / "work/source.state").read_text() == changed_state
    assert package.read_bytes() == changed_package
    assert sorted(port.glob("work/*._done.*")) == saved_cookies

    returned = subprocess.run(args + ["package"], text=True,
                              capture_output=True, timeout=30)
    assert returned.returncode == 0, returned.stdout + returned.stderr
    returned_state = (port / "work/source.state").read_text()
    assert "ref|1.2\n" in returned_state, returned_state
    assert b"source-state|ref|1.2\n" in package.read_bytes()
    assert marker.read_text() == "preserve this checkout\n"
    assert subprocess.check_output(
        ["git", "-C", source, "rev-parse", "HEAD"], text=True).strip() == revision


def main():
    # Keep stdin open without sending EOF, as in an interactive invocation.
    # Metadata normalization must not try to consume the caller's input.
    with tempfile.TemporaryFile(mode="w+") as output:
        with subprocess.Popen(
                ["make", "--no-print-directory", "-s", "-C",
                 str(FRAMEWORK / "Tools/tests/cases/github"),
                 f"PORTSDIR={FRAMEWORK}", "snapshot"],
                stdin=subprocess.PIPE, stdout=output,
                stderr=subprocess.STDOUT) as process:
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.stdin.close()
                process.wait(timeout=10)
                raise AssertionError("GitHub metadata waited for stdin EOF")
            output.seek(0)
            snapshot = output.read()
            assert process.returncode == 0, snapshot
            assert "account=demo\n" in snapshot, snapshot

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
            check_git_mode(root)
            print("GitHub tag/commit checksum/extract/Git-patch/stage/runtime: passed")
        finally:
            server.shutdown()


if __name__ == "__main__":
    main()
