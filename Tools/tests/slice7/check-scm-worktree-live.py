#!/usr/bin/env python3
"""Real Mini-XML and ad-libitum checkouts: preservation and SCM failure recovery."""
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import tempfile

FRAMEWORK = Path(__file__).resolve().parents[3]
PROJECT = FRAMEWORK.parents[1]


def main():
    trial = Path(tempfile.mkdtemp(prefix="uports-scm-slice7."))
    print(f"Evidence directory: {trial}", flush=True)
    results = []
    env = dict(os.environ, GIT_CONFIG_COUNT="3",
               GIT_CONFIG_KEY_0="user.name", GIT_CONFIG_VALUE_0="uports live validation",
               GIT_CONFIG_KEY_1="user.email", GIT_CONFIG_VALUE_1="tests@example.invalid",
               GIT_CONFIG_KEY_2="protocol.file.allow", GIT_CONFIG_VALUE_2="always")
    with (trial / "validation.log").open("w", buffering=1) as log:
        def report(message):
            print(message, flush=True)
            print(message, file=log, flush=True)

        def run(args, ok=True, limit=600, cwd=None):
            args = list(map(str, args))
            report("RUN " + " ".join(args))
            with tempfile.TemporaryFile(mode="w+") as output:
                with subprocess.Popen(args, stdin=subprocess.PIPE, stdout=output,
                                      stderr=subprocess.STDOUT, env=env,
                                      start_new_session=True, cwd=cwd) as process:
                    try:
                        process.wait(timeout=limit)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGTERM)
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            os.killpg(process.pid, signal.SIGKILL)
                            process.wait()
                        raise RuntimeError(f"command exceeded {limit}s")
                    output.seek(0)
                    text = output.read()
                print(text, file=log, flush=True)
            results.append({"command": args, "exit": process.returncode,
                            "expected_success": ok})
            report(f"EXIT {process.returncode} (expected {'success' if ok else 'failure'})")
            assert (process.returncode == 0) == ok, text[-8000:]
            return text.strip()

        def git(path, *args, **kwargs):
            return run(["git", "-C", path, *args], **kwargs)

        def port(work, *settings, target="extract", ok=True, name="textproc/mxml"):
            args = ["make", "-s", "--no-print-directory", "-C",
                    PROJECT / "feeds" / name, f"PORTSDIR={FRAMEWORK}",
                    "USE_GLOBALBASE=yes", f"DISTDIR_SITE={trial}/distfiles",
                    f"PACKAGES_SITE={trial}/packages", f"SCMDIR_SITE={trial}/scm",
                    f"WRKDIR={work}", f"DESTDIR={trial}/installed", "PREFIX=/usr",
                    "UPORTS_DEPENDENCIES=none", "SCM_TIMEOUT=120",
                    "USE_ALTERNATIVE=yes", f"ALTERNATIVE_WRKDIR={work}/sources",
                    *settings, target]
            return run(args, ok=ok)

        def source(work):
            state = dict(line.split("|", 1) for line in
                         (work / "source.state").read_text().splitlines())
            return work / state["root"].strip()

        try:
            work = trial / "mxml"
            seed = trial / "scm/mxml-seed.git"
            settings = ["SOURCE_MODE=git", f"SCM_CACHE_REPO={seed}",
                        "SCM_CACHE_UPDATE=no"]
            if env.get("UPORTS_LIVE_MXML_REPO"):
                settings += [f"SCM_REPO_URL={env['UPORTS_LIVE_MXML_REPO']}"]
            port(work, *settings, target="package")
            tree = source(work)
            assert tree.is_symlink(), tree
            actual = tree.resolve()
            assert actual.is_relative_to(work / "sources"), actual
            run([tree / "testmxml", "test.xml"], cwd=tree)
            header = (work / "pkg/mxml-4.0.5.pkg").read_bytes().split(b"PLIST:", 1)[0]
            dirty = "yes" if git(tree, "status", "--porcelain", "--untracked-files=all") else "no"
            assert f"source-state|worktree-dirty|{dirty}\n".encode() in header, header
            head = git(tree, "rev-parse", "HEAD")
            branch_before = git(tree, "symbolic-ref", "--short", "HEAD", ok=False)
            assert "not a symbolic ref" in branch_before
            original = (tree / "mxml.h").read_bytes()
            (tree / "mxml.h").write_bytes(original + b"\n/* local developer change */\n")
            note = tree / "developer-note.txt"
            note.write_text("preserve untracked work\n")
            git(tree, "switch", "-c", "developer-kept")
            port(work, *settings, target="fetch")
            port(work, *settings, target="do-extract")
            assert (tree / "mxml.h").read_bytes() == original + b"\n/* local developer change */\n"
            assert note.read_text() == "preserve untracked work\n"
            assert tree.resolve() == actual and git(tree, "rev-parse", "HEAD") == head
            assert git(tree, "symbolic-ref", "--short", "HEAD") == "developer-kept"
            port(work, *settings, "SOURCE_MODE=dist", f"WRKSRC={tree}",
                 target="wrkdir", ok=False)
            assert note.exists() and git(tree, "rev-parse", "HEAD") == head
            port(work, *settings, target="scm-update", ok=False)
            # Package creation must reject a dirty checkout, even with warm build cookies.
            (work / "pkg/mxml-4.0.5.pkg").unlink()
            port(work, *settings, "SCM_DIRTY_PACKAGE=reject", target="do-package", ok=False)
            assert note.exists() and (tree / "mxml.h").read_bytes() != original
            port(work, *settings, target="do-package")
            header = (work / "pkg/mxml-4.0.5.pkg").read_bytes().split(b"PLIST:", 1)[0]
            assert b"source-state|worktree-dirty|yes\n" in header
            (tree / "mxml.h").write_bytes(original)
            note.unlink()
            git(tree, "checkout", "--detach", head)
            report("PASS real checkout: branch/dirty/untracked/alternative preservation; dirty package rejection")

            # Use a local copy of the real upstream repository for reproducible
            # offline/advancing-ref/concurrency checks; no toy source is created.
            upstream = trial / "mxml-upstream.git"
            run(["git", "clone", "--mirror", seed, upstream])
            base = git(upstream, "rev-parse", f"{head}^")
            git(upstream, "update-ref", "refs/heads/uports-live", base)
            branch_work = trial / "branch"
            branch_cache = trial / "scm/branch.git"
            branch_settings = ["SOURCE_MODE=git", "SCM_BRANCH=uports-live",
                               f"SCM_REPO_URL={upstream}", f"SCM_CACHE_REPO={branch_cache}"]
            port(branch_work, *branch_settings)
            branch_tree = source(branch_work)
            assert git(branch_tree, "rev-parse", "HEAD") == base
            git(upstream, "update-ref", "refs/heads/uports-live", head)
            port(branch_work, *branch_settings, target="fetch")
            assert git(branch_tree, "rev-parse", "HEAD") == base
            port(branch_work, *branch_settings, target="scm-update")
            assert git(branch_tree, "rev-parse", "HEAD") == head
            assert git(branch_tree, "symbolic-ref", "--short", "HEAD") == "uports-live"
            report("PASS real upstream history: fetch leaves checkout; explicit update fast-forwards")

            raw = trial / "uncached"
            raw_settings = ["SOURCE_MODE=git", "SCM_CACHE=no",
                            "SCM_BRANCH=uports-live", f"SCM_REPO_URL={upstream}"]
            port(raw, *raw_settings)
            raw_tree = source(raw)
            assert git(raw_tree, "rev-parse", "HEAD") == head
            raw_note = raw_tree / "developer-note.txt"
            raw_note.write_text("preserve direct checkout\n")
            port(raw, *raw_settings, target="do-extract")
            assert raw_note.read_text() == "preserve direct checkout\n"
            report("PASS direct SCM_CACHE=no branch clone/repeat preservation")

            offline = trial / "mxml-upstream.offline"
            upstream.rename(offline)
            port(branch_work, *branch_settings, target="fetch")
            port(branch_work, *branch_settings, "SCM_CACHE_UPDATE_REQUIRED=yes",
                 target="fetch", ok=False)
            port(branch_work, *branch_settings, "SCM_BRANCH=missing-live-branch",
                 target="fetch", ok=False)
            assert git(branch_tree, "rev-parse", "HEAD") == head
            offline.rename(upstream)
            report("PASS optional offline cache, required-refresh failure and missing-ref rejection")

            # Advance a local-only commit: update must never discard it.
            (branch_tree / "local-commit.txt").write_text("developer commit\n")
            git(branch_tree, "add", "local-commit.txt")
            git(branch_tree, "commit", "-qm", "local developer work")
            local_head = git(branch_tree, "rev-parse", "HEAD")
            port(branch_work, *branch_settings, target="scm-update", ok=False)
            assert git(branch_tree, "rev-parse", "HEAD") == local_head
            # Create an interrupted patch session using a real upstream commit
            # already present in this checkout; preserve it until explicit abort.
            patch = trial / "upstream-commit.patch"
            patch.write_text(git(seed, "format-patch", "-1", head, "--stdout") + "\n")
            git(branch_tree, "am", patch, ok=False)
            gitdir = Path(git(branch_tree, "rev-parse", "--absolute-git-dir"))
            assert (gitdir / "rebase-apply").exists()
            port(branch_work, *branch_settings, target="do-extract", ok=False)
            assert (gitdir / "rebase-apply").exists()
            assert git(branch_tree, "rev-parse", "HEAD") == local_head
            git(branch_tree, "am", "--abort")
            report("PASS local commits and interrupted real git-am session preserved")

            # Real clone timeout and retry. Any partial publication is a failure.
            timed_cache = trial / "scm/timed.git"
            timed = ["SOURCE_MODE=git", f"SCM_REPO_URL={upstream}",
                     f"SCM_CACHE_REPO={timed_cache}"]
            failure = port(trial / "timed", *timed, "SCM_TIMEOUT=0.001",
                           target="fetch", ok=False)
            assert "mirror clone timed out after 0.001 (exit 124)" in failure, failure
            assert not timed_cache.exists()
            assert not list(timed_cache.parent.glob("timed.git.tmp.*"))
            assert not Path(str(timed_cache) + ".lock").exists()
            port(trial / "timed", *timed, target="fetch")
            port(trial / "timed", *timed, "SCM_TIMEOUT_BIN=/missing-timeout",
                 target="fetch", ok=False)
            port(trial / "timed", *timed, "SCM_TIMEOUT=0", "SCM_TIMEOUT_BIN=/missing-timeout",
                 "SCM_CACHE_UPDATE=no", target="fetch")
            report("PASS bounded clone failure/retry, missing timer and explicit timeout opt-out")

            # Concurrent real mirror clones use the production executor with
            # the exact environment the port exports, sharing one mirror.
            executor = FRAMEWORK / "Mk/Scripts/do-scm.sh"
            shared = trial / "scm/concurrent.git"
            scm_env = dict(env, SCM_REPO_URL=str(upstream), SCM_CACHE_REPO=str(shared),
                           SCM_DETACH=head, SCM_CACHE_UPDATE="no", SCM_TIMEOUT="120")
            jobs = [subprocess.Popen(["sh", str(executor), "fetch"], env=scm_env,
                                     stdout=log, stderr=log, start_new_session=True)
                    for _ in range(2)]
            try:
                for job in jobs:
                    code = job.wait(timeout=60)
                    results.append({"command": ["sh", str(executor), "fetch"],
                                    "exit": code, "expected_success": True})
                    report(f"EXIT {code} (concurrent mirror; expected success)")
                    assert code == 0
            finally:
                for job in jobs:
                    if job.poll() is None:
                        os.killpg(job.pid, signal.SIGKILL)
                        job.wait()
            assert git(shared, "rev-parse", head) == head
            assert not Path(str(shared) + ".lock").exists()
            assert not list(shared.parent.glob("concurrent.git.tmp.*"))
            report("PASS concurrent real mirror creation: valid publication and released locks")

            interrupted = trial / "scm/interrupted.git"
            scm_env["SCM_CACHE_REPO"] = str(interrupted)
            with subprocess.Popen(["sh", str(executor), "fetch"], env=scm_env,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  start_new_session=True) as job:
                selector = selectors.DefaultSelector()
                selector.register(job.stdout, selectors.EVENT_READ)
                assert selector.select(timeout=15), "no clone progress"
                line = job.stdout.readline().decode()
                print(line, file=log)
                assert "create mirror" in line, line
                os.killpg(job.pid, signal.SIGTERM)
                code = job.wait(timeout=10)
                results.append({"command": ["sh", str(executor), "fetch"],
                                "exit": code, "expected_success": False,
                                "reason": "intentional SIGTERM during real clone"})
                report(f"EXIT {code} (interrupted clone; expected failure)")
                assert code != 0
                selector.close()
            assert not interrupted.exists()
            assert not list(interrupted.parent.glob("interrupted.git.tmp.*"))
            assert not Path(str(interrupted) + ".lock").exists()
            retry_env = dict(env)
            env.update(scm_env)
            try:
                run(["sh", executor, "fetch"])
            finally:
                env.clear()
                env.update(retry_env)
            report("PASS interrupted real clone: no partial cache; retry succeeds")

            # Actual declared submodules and maintained patch series.
            audio = trial / "ad-libitum"
            port(audio, "SCM_CACHE_UPDATE=no", name="audio/ad-libitum", target="patch")
            audio_tree = source(audio)
            status = git(audio_tree, "submodule", "status", "--recursive")
            assert "chez-soundio" in status and "chez-sockets" in status, status
            before = git(audio_tree, "rev-parse", "HEAD")
            sub_before = git(audio_tree / "chez-sockets", "rev-parse", "HEAD")
            marker = audio_tree / "chez-sockets/developer-note.txt"
            marker.write_text("preserve submodule developer work\n")
            port(audio, "SCM_CACHE_UPDATE=no", name="audio/ad-libitum", target="patch")
            assert marker.read_text() == "preserve submodule developer work\n"
            assert git(audio_tree, "rev-parse", "HEAD") == before
            assert git(audio_tree / "chez-sockets", "rev-parse", "HEAD") == sub_before
            # Preserve a real interrupted git-am operation in a submodule at
            # its recorded gitlink, before any maintained series is applied.
            sub = audio_tree / "chez-soundio"
            patched = git(sub, "rev-parse", "HEAD")
            git(sub, "branch", "preserved-maintained-patches", patched)
            gitlink = git(audio_tree, "rev-parse", "HEAD:chez-soundio")
            git(sub, "checkout", "--detach", gitlink)
            duplicate = trial / "submodule-upstream.patch"
            duplicate.write_text(git(sub, "format-patch", "-1", gitlink, "--stdout") + "\n")
            git(sub, "am", duplicate, ok=False)
            sub_gitdir = Path(git(sub, "rev-parse", "--absolute-git-dir"))
            assert (sub_gitdir / "rebase-apply").exists()
            failure = port(audio, "SCM_CACHE_UPDATE=no", name="audio/ad-libitum",
                           target="apply-submodule-patches", ok=False)
            assert "Git operation in progress" in failure, failure
            assert (sub_gitdir / "rebase-apply").exists()
            assert git(sub, "rev-parse", "HEAD") == gitlink
            git(sub, "am", "--abort")
            git(sub, "checkout", "--detach", patched)
            assert marker.read_text() == "preserve submodule developer work\n"
            report("PASS actual ad-libitum submodules/maintained patches/repeat preservation")
            report("PASS slice 7 real-world validation")
        except Exception as error:
            report(f"FAIL {type(error).__name__}: {error}")
            raise
        finally:
            (trial / "commands.json").write_text(json.dumps(results, indent=2) + "\n")
            report(f"Retained evidence: {trial}")


if __name__ == "__main__":
    main()
