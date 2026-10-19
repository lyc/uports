#!/usr/bin/env python3
"""Local-only archive executor regression; no external services or port builds."""
import concurrent.futures
import hashlib
import http.server
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import threading
import time

FRAMEWORK = Path(__file__).resolve().parents[2]
SCRIPT = FRAMEWORK / "Mk/Scripts/do-fetch.sh"
PAYLOAD = b"verified local archive fixture\n"
requests = []


class Handler(http.server.BaseHTTPRequestHandler):
    def handle(self):
        try:
            super().handle()
        except (BrokenPipeError, ConnectionResetError):
            # Expected when clients reject the self-signed certificate.
            pass

    def log_message(self, *args):
        pass

    def do_GET(self):
        requests.append(self.path)
        if self.path.startswith("/slow/"):
            time.sleep(2)
            self.close_connection = True
            return
        if self.path.startswith("/fail/"):
            self.send_error(404)
            return
        if self.path.startswith("/redirect/"):
            self.send_response(302)
            self.send_header("Location", "/good/redirected-name")
            self.end_headers()
            return
        body = PAYLOAD
        if self.path.startswith("/short/"):
            body = b"short"
        elif self.path.startswith("/wrong/"):
            body = b"x" * len(PAYLOAD)
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.path.startswith("/partial/"):
            self.wfile.write(body[:3])
            self.close_connection = True
        else:
            self.wfile.write(body)


def main():
    with tempfile.TemporaryDirectory(prefix="uports-fetch.") as directory:
        root = Path(directory)
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        env = dict(os.environ, dp_DISTDIR=str(root / "cache"),
                   dp_DIST_SUBDIR="namespace", dp_DISTINFO_FILE=str(root / "distinfo"),
                   dp_SITE_FLAVOR="MASTER", dp_TARGET="do-fetch",
                   dp_FETCH_TIMEOUT="3", dp_FETCH_REGET="1",
                   dp_FETCH_ENV="", dp_FETCH_BEFORE_ARGS="",
                   dp_FETCH_AFTER_ARGS="", dp_FORCE_FETCH_ALL="no",
                   dp_FORCE_FETCH_LIST="", dp_NO_CHECKSUM="no",
                   dp_DISTINFO_REQUIRED="yes", dp_DISABLE_SIZE="no",
                   dp_NO_CHECK_CERTIFICATE="no", dp_MASTER_SITE_OVERRIDE="",
                   dp_MASTER_SITE_BACKUP="", dp_MASTER_SORT="",
                   dp_MASTER_SORT_REGEX="", dp_RANDOMIZE_SITES="no")

        def evidence(filename="source.tar.gz", payload=PAYLOAD):
            (root / "distinfo").write_text(
                f"SHA256 (namespace/{filename}) = "
                f"{hashlib.sha256(payload).hexdigest()}\n"
                f"SIZE (namespace/{filename}) = {len(payload)}\n")

        def run(filename="source.tar.gz:src", ok=True, **settings):
            result = subprocess.run(["/bin/sh", str(SCRIPT), filename],
                                    env=dict(env, **settings), text=True,
                                    capture_output=True, timeout=20)
            assert (result.returncode == 0) == ok, result.stdout + result.stderr
            return result

        tools = [tool for tool in ("wget", "curl") if shutil.which(tool)]
        assert tools, "wget or curl is needed for this fixture"
        for tool in tools:
            env.update(dp_FETCH_CMD=shutil.which(tool), dp_FETCH_TOOL=tool,
                       _MASTER_SITES_src=f"{base}/fail/ {base}/short/ "
                                         f"{base}/wrong/ {base}/good/")
            evidence()
            cache = root / "cache"
            archive = cache / "source.tar.gz"
            if archive.exists():
                archive.unlink()
            before = len(requests)
            result = run()
            assert archive.read_bytes() == PAYLOAD
            assert "SIZE mismatch" in result.stderr
            assert "SHA256 mismatch" in result.stderr
            assert len(requests) == before + 4
            run()
            assert len(requests) == before + 4, "warm cache downloaded again"
            run(dp_FORCE_FETCH_LIST="source.tar.gz")
            assert len(requests) == before + 8
            saved = archive.stat().st_mtime_ns
            run(ok=False, dp_FORCE_FETCH_ALL="yes",
                _MASTER_SITES_src=f"{base}/partial/")
            assert archive.read_bytes() == PAYLOAD
            assert archive.stat().st_mtime_ns == saved
            run(dp_FORCE_FETCH_ALL="yes",
                _MASTER_SITES_src=f"{base}/redirect/")
            assert not (cache / "redirected-name").exists()
            archive.unlink()
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(run, _MASTER_SITES_src=f"{base}/good/")
                           for _ in range(2)]
                for future in futures:
                    future.result()
            assert archive.read_bytes() == PAYLOAD
            assert not list(cache.glob(".fetch.*")), "temporary files leaked"
            archive.unlink()
            archive.symlink_to(root / "missing")
            run(ok=False)
            assert archive.is_symlink()
            archive.unlink()
            # Existing checksum evidence cannot silently accept changed content.
            run(ok=False, _MASTER_SITES_src=f"{base}/wrong/")
            assert not archive.exists()
            evidence("nested/source.tar.gz")
            run("nested/source.tar.gz:src", _MASTER_SITES_src=f"{base}/good/")
            assert (cache / "nested/source.tar.gz").read_bytes() == PAYLOAD
            evidence()
            # Listings neither create cache directories nor download files.
            listing_cache = root / f"listing '{tool} cache"
            before = len(requests)
            listed = run(dp_TARGET="fetch-url-list", dp_DISTDIR=str(listing_cache),
                         dp_MASTER_SITE_OVERRIDE=f"{base}/first/",
                         dp_MASTER_SITE_BACKUP=f"{base}/last/",
                         dp_MASTER_SORT_REGEX="/good/")
            urls = listed.stdout.splitlines()
            assert urls[0] == f"{base}/first/source.tar.gz"
            assert urls[1] == f"{base}/good/source.tar.gz"
            assert urls[-1] == f"{base}/last/source.tar.gz"
            grouped = run("source.tar.gz:src,extra", dp_TARGET="fetch-url-list",
                          _MASTER_SITES_extra=f"{base}/extra/",
                          dp_MASTER_SITE_OVERRIDE=f"{base}/first/")
            assert grouped.stdout.count(f"{base}/first/source.tar.gz") == 1
            assert f"{base}/extra/source.tar.gz" in grouped.stdout
            preferred = run(dp_TARGET="fetch-url-list", dp_MASTER_SORT="preferred.invalid",
                            _MASTER_SITES_src="https://other.invalid/ "
                                              "https://preferred.invalid/")
            assert preferred.stdout.splitlines()[0] == (
                "https://preferred.invalid/source.tar.gz")
            randomized = run(dp_TARGET="fetch-url-list", dp_RANDOMIZE_SITES="yes")
            assert sorted(randomized.stdout.splitlines()) == sorted(
                f"{site}source.tar.gz" for site in env["_MASTER_SITES_src"].split())
            command = run(dp_TARGET="fetch-list", dp_DISTDIR=str(listing_cache))
            assert not listing_cache.exists() and len(requests) == before
            subprocess.run(["/bin/sh", "-c", command.stdout], check=True,
                           capture_output=True, timeout=20)
            assert (listing_cache / "source.tar.gz").read_bytes() == PAYLOAD
            run(ok=False, dp_FETCH_TIMEOUT="0")
            started = time.monotonic()
            run(ok=False, dp_DISTDIR=str(root / f"slow-{tool}"),
                dp_FETCH_TIMEOUT="1", _MASTER_SITES_src=f"{base}/slow/")
            assert time.monotonic() - started < 6, "I/O timeout did not stop fetch"
            run("../escape:src", ok=False)
            run("source.tar.gz:bad-name", ok=False)
            readonly = root / f"readonly-{tool}"
            readonly.mkdir()
            readonly.chmod(0o555)
            if not os.access(readonly, os.W_OK):
                run(ok=False, dp_DISTDIR=str(readonly))
            readonly.chmod(0o755)
            (root / "distinfo").unlink()
            run(ok=False, dp_DISTDIR=str(root / "required-cache"))
            run(dp_DISTDIR=str(root / "optional-cache"),
                dp_DISTINFO_REQUIRED="no", _MASTER_SITES_src=f"{base}/good/")
            evidence()
            run(ok=False, dp_DISTDIR=str(root / "missing-entry"),
                dp_DIST_SUBDIR="unknown")
            print(f"fetch HTTP/cache/failure/listing checks: {tool} passed")

        if shutil.which("openssl"):
            certificate, private_key = root / "cert.pem", root / "key.pem"
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048",
                            "-nodes", "-keyout", str(private_key), "-out",
                            str(certificate), "-days", "1", "-subj", "/CN=localhost"],
                           check=True, capture_output=True, timeout=20)
            secure = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certificate, private_key)
            secure.socket = context.wrap_socket(secure.socket, server_side=True)
            threading.Thread(target=secure.serve_forever, daemon=True).start()
            try:
                for tool in tools:
                    settings = dict(dp_FETCH_CMD=shutil.which(tool),
                                    dp_FETCH_TOOL=tool,
                                    dp_DISTDIR=str(root / f"tls-{tool}"),
                                    _MASTER_SITES_src=(
                                        f"https://127.0.0.1:{secure.server_port}/good/"))
                    run(ok=False, **settings)
                    run(dp_NO_CHECK_CERTIFICATE="yes", **settings)
                    assert (root / f"tls-{tool}/source.tar.gz").read_bytes() == PAYLOAD
                print("fetch TLS verification default and explicit opt-out: passed")
            finally:
                secure.shutdown()
        else:
            print("fetch TLS handshake fixture: skipped (openssl unavailable)")

        # Exercise actual make exports and both distfile/patchfile dispatches.
        make_cache = root / "make-cache"
        (root / "distinfo").write_text("")
        command = ["make", "--no-print-directory", "-s", "-C",
                   str(FRAMEWORK / "Tools/tests/cases/fetch-contract"),
                   f"PORTSDIR={FRAMEWORK}", f"DISTDIR={make_cache}",
                   "DIST_SUBDIR=", "DISTFILES=source.tar.gz:src",
                   "PATCHFILES=fix.patch:fix", f"MASTER_SITES={base}/good/:src",
                   f"PATCH_SITES={base}/good/:fix", "NO_CHECKSUM=yes",
                   f"FETCH_CMD={shutil.which(tools[0])}", "do-fetch"]
        subprocess.run(command, check=True, capture_output=True, timeout=20)
        assert (make_cache / "source.tar.gz").read_bytes() == PAYLOAD
        assert (make_cache / "fix.patch").read_bytes() == PAYLOAD
        before = len(requests)
        inspected = subprocess.run(command[:-1] + ["fetch-url-list"],
                                   check=True, capture_output=True, timeout=20)
        assert f"{base}/good/source.tar.gz".encode() in inspected.stdout
        assert f"{base}/good/fix.patch".encode() in inspected.stdout
        assert len(requests) == before
        print("fetch make distfile/patchfile wiring: passed")
        sums = root / "generated.distinfo"
        subprocess.run(command[:-1] + [f"DISTINFO_FILE={sums}", "makesum"],
                       check=True, capture_output=True, timeout=20)
        saved_sums = sums.read_bytes()
        checksum_command = command[:-1] + [f"DISTINFO_FILE={sums}",
                                           "NO_CHECKSUM=no", "checksum"]
        subprocess.run(checksum_command, check=True, capture_output=True,
                       timeout=20)
        (make_cache / "fix.patch").write_bytes(b"changed")
        failed = subprocess.run(checksum_command, capture_output=True,
                                timeout=20)
        assert failed.returncode != 0 and b"mismatch" in failed.stdout
        assert sums.read_bytes() == saved_sums
        print("fetch makesum/checksum evidence preservation: passed")
        empty_cache = root / "empty cache"
        empty_sums = root / "empty.distinfo"
        subprocess.run(command[:-1] + [f"DISTDIR={empty_cache}",
                       "DISTFILES=", "PATCHFILES=", f"DISTINFO_FILE={empty_sums}",
                       "makesum"], check=True, capture_output=True, timeout=20)
        assert empty_cache.is_dir()
        assert empty_sums.read_text().startswith("TIMESTAMP = ")
        print("fetch empty-file-list cache/makesum compatibility: passed")
        server.shutdown()


if __name__ == "__main__":
    main()
