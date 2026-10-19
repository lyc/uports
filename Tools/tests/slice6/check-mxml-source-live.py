#!/usr/bin/env python3
"""Opt-in Linux real-port source validation; downloads into retained /tmp trees."""
import hashlib
import os
from pathlib import Path
import signal
import subprocess
import tempfile


FRAMEWORK = Path(__file__).resolve().parents[3]
PROJECT = FRAMEWORK.parents[1]


def main():
    trial = Path(tempfile.mkdtemp(prefix="uports-mxml-slice6."))
    print(f"Validation directory: {trial}", flush=True)
    with (trial / "validation.log").open("w", buffering=1) as log:
        def report(message):
            print(message, flush=True)
            print(message, file=log, flush=True)

        def run(args, capture=False):
            report("RUN " + " ".join(map(str, args)))
            # Keep stdin open: real Makefile parsing must finish without EOF.
            with subprocess.Popen(
                    list(map(str, args)), stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE if capture else log,
                    stderr=log, start_new_session=True) as child:
                try:
                    if capture:
                        # Metadata is small; do not close stdin with communicate.
                        child.wait(timeout=600)
                        output = child.stdout.read().decode()
                        print(output, file=log)
                    else:
                        child.wait(timeout=600)
                        output = ""
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait()
                    raise RuntimeError("command exceeded 600 seconds")
                if child.returncode:
                    report(f"EXIT {child.returncode}")
                    raise RuntimeError(f"command exited {child.returncode}")
                report("EXIT 0")
                return output.strip()

        common = [
            "make", "--no-print-directory", "-C",
            PROJECT / "feeds/textproc/mxml", f"PORTSDIR={FRAMEWORK}",
            "USE_GLOBALBASE=yes", f"DISTDIR_SITE={trial}/distfiles",
            f"PACKAGES_SITE={trial}/packages", f"SCMDIR_SITE={trial}/scm",
            f"SCM_CACHE_REPO={trial}/scm/mxml.git",
            f"WRKDIR={trial}/work", "USE_ALTERNATIVE=no",
            f"DESTDIR={trial}/installed", "PREFIX=/usr",
            "UPORTS_DEPENDENCIES=none", "SCM_TIMEOUT=120",
            "FETCH_TIMEOUT=30", "FETCH_REGET=1",
        ]
        work = trial / "work"
        package = work / "pkg/mxml-4.0.5.pkg"

        def state():
            return dict(line.split("|", 1) for line in
                        (work / "source.state").read_text().splitlines())

        def provenance():
            header = package.read_bytes().split(b"PLIST:", 1)[0]
            assert header.startswith(b"PVER: 2\n"), header
            for line in (work / "source.state").read_bytes().splitlines():
                assert b"source-state|" + line + b"\n" in header, line
            print(header.decode(), file=log)

        def snapshot():
            paths = [p for p in work.iterdir() if p.is_file()]
            paths += [package, work / "stage/usr/lib/libmxml4.so.2"]
            paths += list((trial / "packages").rglob("mxml-4.0.5.pkg"))
            return {str(p): (p.stat().st_mtime_ns,
                            hashlib.sha256(p.read_bytes()).hexdigest())
                    for p in paths}

        def smoke(label):
            stage = work / "stage/usr"
            source = trial / "smoke.c"
            source.write_text('''#include <mxml.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
int main(void) {
    mxml_node_t *root = mxmlNewElement(NULL, "root");
    mxmlNewText(root, false, "hello");
    char *text = mxmlSaveAllocString(root, NULL);
    int ok = text && strstr(text, "<root>hello</root>");
    if (text) puts(text);
    free(text);
    mxmlDelete(root);
    return ok ? 0 : 1;
}
''')
            binary = trial / f"smoke-{label}"
            run(["cc", source, f"-I{stage}/include/libmxml4",
                 f"-L{stage}/lib", f"-Wl,-rpath,{stage}/lib", "-lmxml4",
                 "-o", binary])
            loaded = run(["ldd", binary], capture=True)
            assert str(stage / "lib/libmxml4.so.2") in loaded, loaded
            run([binary])

        def repeat(settings, label):
            before = snapshot()
            run(common + settings + ["package"])
            after = snapshot()
            assert before == after, {
                p: (before.get(p), after.get(p)) for p in before.keys() | after.keys()
                if before.get(p) != after.get(p)}
            report(f"PASS {label}: repeat preserves cookies/state/library/packages")

        try:
            # Exercise the actual parent command without explicit directory
            # overrides that could hide incorrect *_SITE handling.
            wrapper = [
                "make", "--no-print-directory", "-C", PROJECT, "V=1",
                "USE_GLOBALBASE=yes", f"DISTDIR_SITE={trial}/distfiles",
                f"PACKAGES_SITE={trial}/packages", f"SCMDIR_SITE={trial}/scm",
                "FETCH_TIMEOUT=30", "FETCH_REGET=1", "mxml.fetch",
            ]
            archive = (trial / "distfiles/mxml" /
                       "michaelrsweet-mxml-v4.0.5_GH0.tar.gz")
            evidence = (PROJECT / "feeds/textproc/mxml/distinfo").read_text()
            expected_sha = next(line.rsplit(" = ", 1)[1] for line in
                                evidence.splitlines() if line.startswith(
                                    f"SHA256 (mxml/{archive.name})"))
            run(wrapper)
            assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected_sha
            before = (archive.stat().st_mtime_ns, archive.read_bytes())
            run(wrapper)
            assert (archive.stat().st_mtime_ns, archive.read_bytes()) == before
            # Delete only this run's archive; retain all existing user caches.
            archive.unlink()
            run(wrapper)
            assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected_sha
            report("PASS parent wrapper: fresh/repeat/deleted archive; maintained SHA256")

            dist = ["SOURCE_MODE=dist"]
            run(common + dist + ["package"])
            assert state()["mode"] == "dist"
            provenance()
            smoke("dist")
            repeat(dist, "archive")
            dist_key = state()["request-key"]
            dist_package = package.read_bytes()

            git = ["SOURCE_MODE=git"]
            run(common + git + ["package"])
            selected = state()
            assert selected["mode"] == "git" and selected["ref"] == "v4.0.5"
            expected = run(["git", "-C", trial / "scm/mxml.git",
                            "rev-parse", "v4.0.5^{commit}"], capture=True)
            assert selected["resolved-commit"] == expected, selected
            assert selected["request-key"] != dist_key
            assert package.read_bytes() != dist_package
            provenance()
            smoke("git")
            repeat(git, "Git tag")
            tag_key = state()["request-key"]
            tag_package = package.read_bytes()

            pinned = git + [f"SCM_DETACH={expected}"]
            run(common + pinned + ["package"])
            selected = state()
            assert selected["ref"] == expected
            assert selected["resolved-commit"] == expected
            assert selected["request-key"] != tag_key
            assert package.read_bytes() != tag_package
            provenance()
            smoke("commit")
            repeat(pinned, "Git commit")

            # Revisit old identities whose cookies still exist in this tree.
            # Shared stage/package artifacts must describe the current mode.
            run(common + dist + ["package"])
            assert state()["mode"] == "dist"
            assert state()["request-key"] == dist_key
            provenance()
            smoke("dist-return")
            repeat(dist, "archive return")
            run(common + git + ["package"])
            assert state()["mode"] == "git"
            assert state()["request-key"] == tag_key
            assert state()["resolved-commit"] == expected
            provenance()
            smoke("git-return")
            repeat(git, "Git tag return")
            report("PASS all real Mini-XML source/runtime/provenance/reuse checks")
        except Exception as error:
            report(f"FAIL {type(error).__name__}: {error}")
            raise
        finally:
            report(f"Retained artifacts and log: {trial}")


if __name__ == "__main__":
    main()
