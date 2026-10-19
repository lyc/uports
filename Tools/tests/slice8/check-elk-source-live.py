#!/usr/bin/env python3
"""Real Elk release/Git migration, bootstrap, package and extension checks."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile


FRAMEWORK = Path(__file__).resolve().parents[3]
PROJECT = FRAMEWORK.parents[1]
REPOSITORY = "https://gitea.scheme.org/conservatory/elk.git"
REVISION = "5ba5ffc44da4943139fa27879df2aa748abf1c71"


def main():
    trial = Path(tempfile.mkdtemp(prefix="uports-elk-slice8."))
    print(f"Evidence directory: {trial}", flush=True)
    results = []
    with (trial / "validation.log").open("w", buffering=1) as log:
        def report(message):
            print(message, flush=True)
            print(message, file=log, flush=True)

        def run(args, input_text=None, env=None, limit=900):
            args = list(map(str, args))
            report("RUN " + " ".join(args))
            with tempfile.TemporaryFile(mode="w+") as output:
                with subprocess.Popen(args, stdin=subprocess.PIPE,
                                      stdout=output, stderr=subprocess.STDOUT,
                                      env=env, start_new_session=True) as child:
                    try:
                        if input_text is not None:
                            child.stdin.write(input_text.encode())
                            child.stdin.close()
                        child.wait(timeout=limit)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGTERM)
                        try:
                            child.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            os.killpg(child.pid, signal.SIGKILL)
                            child.wait()
                        raise RuntimeError(f"command exceeded {limit}s")
                    output.seek(0)
                    text = output.read()
                print(text, file=log, flush=True)
            results.append({"command": args, "exit": child.returncode})
            (trial / "commands.json").write_text(json.dumps(results, indent=2))
            report(f"EXIT {child.returncode}")
            if child.returncode:
                raise RuntimeError(text[-6000:])
            return text

        try:
            cache = trial / "scm/elk.git"
            seed = Path(os.environ.get(
                "UPORTS_LIVE_ELK_REPO",
                "/opt/distfiles/uports/scm/git/gitea.scheme.org_conservatory_elk.git"))
            if seed.is_dir():
                cache.parent.mkdir(parents=True)
                run(["git", "clone", "--mirror", seed, cache])
                run(["git", "-C", cache, "remote", "set-url", "origin", REPOSITORY])
            distdir = os.environ.get("UPORTS_LIVE_ELK_DISTDIR", str(trial / "distfiles"))
            shared = ["USE_GLOBALBASE=yes", f"DISTDIR_SITE={distdir}",
                      f"PACKAGES_SITE={trial}/packages", f"SCMDIR_SITE={trial}/scm",
                      f"SCM_CACHE_REPO={cache}", "SCM_CACHE_UPDATE=no",
                      "SCM_TIMEOUT=15m", "FETCH_REGET=3"]
            for mode in ("dist", "git"):
                settings = shared + [f"SOURCE_MODE={mode}"]
                # Real parent wrapper and SITE paths, with ordinary fetch policy.
                run(["make", "--no-print-directory", "-C", PROJECT,
                     "V=1", *shared,
                     f"PORTS_compiler_elk_EXTRA_ENVS=SOURCE_MODE={mode}",
                     "compiler@elk.fetch"])
                work = trial / mode
                common = ["make", "--no-print-directory", "-C",
                          PROJECT / "feeds/lang/elk", f"PORTSDIR={FRAMEWORK}",
                          *settings, f"WRKDIR={work}", "USE_ALTERNATIVE=yes",
                          f"ALTERNATIVE_WRKDIR={trial}/sources/{mode}",
                          f"DESTDIR={trial}/installed", "PREFIX=/usr/local",
                          "UPORTS_DEPENDENCIES=none"]
                metadata = run(common + ["uports-source-metadata"])
                fields = dict(line.split("=", 1) for line in metadata.splitlines()
                              if "=" in line)
                assert fields["source_mode"] == mode, metadata
                source = Path(fields["source_root"])
                run(common + ["extract"])
                generated = (source / "configure").exists()
                assert generated == (mode == "dist"), (mode, generated)
                report(f"SOURCE {mode}: generated configure present={generated}")
                assert (source / "configure.ac").is_file(), source
                if mode == "git":
                    assert run(["git", "-C", source, "rev-parse", "HEAD"]).strip() == REVISION
                else:
                    run(common + ["checksum"])
                run(common + ["package"])
                assert (source / "configure").is_file(), source
                state = dict(line.split("|", 1) for line in
                             (work / "source.state").read_text().splitlines())
                assert state["mode"] == mode, state
                packages = list((work / "pkg").glob("*.pkg"))
                assert len(packages) == 1, packages
                header = packages[0].read_bytes().split(b"PLIST:", 1)[0]
                assert header.startswith(b"PVER: 2\n"), header
                assert f"source-state|mode|{mode}\n".encode() in header, header
                stage = work / "stage/usr/local"
                env = dict(os.environ, LD_LIBRARY_PATH=str(stage / "lib"))
                for name, program, expected in (
                    ("arithmetic", "(write (+ 20 22)) (newline)\n", "42"),
                    ("regexp", "(require 'regexp)\n(write (regexp? (make-regexp \"a+\")))\n(newline)\n", "#t"),
                    ("unix", "(require 'unix)\n(write (system-record? (unix-system-info)))\n(newline)\n", "#t"),
                ):
                    binary = stage / "bin" / ("scheme-elk" if name == "regexp" else "elk")
                    output = run([binary, "-p", f"{stage}/share/elk:{stage}/lib/elk",
                                  "-l", "-"], input_text=program, env=env)
                    assert expected in output.splitlines(), output
                    report(f"PASS {mode} {name} runtime")
                loaded = run(["ldd", stage / "bin/elk"], env=env)
                assert str(stage / "lib/libelk") in loaded, loaded
                # Snapshot packaged output and state; a repeat must not rebuild.
                paths = [p for p in work.iterdir() if p.is_file()] + packages
                paths += [p for p in (work / "stage").rglob("*") if p.is_file()]

                def snapshot():
                    return {str(p): (p.stat().st_mtime_ns,
                                    hashlib.sha256(p.read_bytes()).hexdigest())
                            for p in paths}

                before = snapshot()
                run(common + ["package"])
                assert snapshot() == before, f"{mode} repeat changed output"
                report(f"PASS {mode} bootstrap/package/provenance/repeat")
            report("PASS slice 8 Elk Linux source migration")
            (trial / "summary.json").write_text(json.dumps(
                {"result": "passed", "platform": "Linux",
                 "commands": len(results), "darwin": "not tested"}, indent=2))
        finally:
            report(f"Retained evidence: {trial}")


if __name__ == "__main__":
    main()
