# MoarVM crash investigation: issues and PRs

Status as of 2026-11-20. **Nothing has been pushed, submitted or posted.**

Started from MoarVM core dumps on this machine: 4 × SIGABRT, 2 × SIGBUS, 1 × SIGSEGV, plus one out-of-memory kill of the terminal session.

Status values: **tested** (fix written and verified locally) · **unsubmitted** · **submitted** · **accepted** · **open** (no fix yet)

## Overview

| # | Repo | What | Fixes | Status | Depends on |
|---|---|---|---|---|---|
| 1 | MoarVM | PR: close a bound stdin through libuv | 4 × SIGABRT | tested, unsubmitted | none |
| 2 | roast | PR: regression test for #1 | — | tested, unsubmitted | #1 merged (fails without it) |
| 3 | NQP | PR: write bytecode files via temp file + rename | 2 × SIGBUS, likely 1 × SIGSEGV | tested, unsubmitted | none |
| 4 | Rakudo | Issue: closing `Proc.out` early buffers without limit | OOM | written, unsubmitted | none to file; a fix may need a new MoarVM op |
| 5 | — | SIGSEGV of 20 Nov 04:49 | — | diagnosed: most likely #3 | #3 |

---

## MoarVM

### #1 Close a bound stdin through libuv, not behind its back

- **Status:** tested, unsubmitted
- **Branch:** `fix-bind-stdin-close` in `~/git/cognominal---moarvm`, 1 commit (94401a2a9) on `upstream/main` 5249be7aa (MoarVM/MoarVM)
- **Patch:** `0001-Close-a-bound-stdin-through-libuv-not-behind-its-bac.patch`
- **PR body:** `moarvm-pr.md`
- **Depends on:** nothing
- **Needed by:** #2 (roast test)
- **What:** `src/io/procops.c`. When a process whose stdin was bound to another process's stdout exits, MoarVM called `close()` on a descriptor still owned by the producer's `uv_pipe_t`. A later read made libuv `abort()` in `uv__epoll_ctl_flush`. The fix closes it through `uv_close` on the owning handle, and falls back to `close()` only when no handle owns it.
- **Tested:**
  - repro aborts 3/3 before, exits normally 3/3 after
  - roast test #2: fails on Rakudo Star 2026.08, passes 5/5 with the fix
  - rakudo#3057 fd-leak check unchanged
  - roast `S17-procasync/*`, `S32-io/pipe.t`, `S29-os/system.t`: same results before and after
- **To submit:** push the branch to your MoarVM fork, open the PR against `MoarVM/MoarVM` `main` with `moarvm-pr.md`.

## NQP

### #3 Write bytecode files to a temporary file and rename it into place

- **Status:** tested, unsubmitted
- **Branch:** `atomic-mbc-write` in `~/git/cognominal---nqp`, 1 commit (5b8779a8f) on `upstream/main` 5397dd7da (Raku/nqp)
- **Patch:** `0001-Write-bytecode-files-to-a-temporary-file-and-rename-.patch`
- **PR body:** `nqp-pr.md`
- **Depends on:** nothing
- **What:** `src/vm/moar/QAST/QASTCompilerMAST.nqp`, `assemble_to_file`. Rebuilding truncated `.moarvm` files that running processes had memory-mapped, which caused SIGBUS. The writer now writes `$filename.tmp-$pid` and renames it over the target.
- **Tested:**
  - recompiling gives the output a new inode, leaves no temp file, and the output runs
  - NQP `make test`: 150 files, 13746 tests, all pass
- **Reproduced:** recompiling a `.moarvm` file while a process is blocked in one of its subs makes that process fail when it resumes, 3/3 per variant (wrong-type and string-heap errors). With the patched NQP doing the recompile: 3/3 normal exit.
- **Not tested:** the SIGBUS itself (needs the file to shrink under a mapped page; the diagnosis rests on the two core dumps' fault offsets); Windows `rename` over an existing file.
- **To submit:** push the branch to your NQP fork, open the PR against `Raku/nqp` `main` with `nqp-pr.md`.

## roast

### #2 Test tapping a stdout after the process bound to it exited

- **Status:** tested, unsubmitted
- **Branch:** `bind-stdin-tap-after-exit` in a **shallow clone in the Claude scratchpad**, which may be cleared. Commit a5df4d5 on Raku/roast 7639d08. The durable copy is the patch here.
- **Patch:** `0001-Test-tapping-a-stdout-after-the-process-bound-to-it-.patch`
- **PR body:** `roast-pr.md`
- **Depends on:** #1 merged and in a Rakudo release. Otherwise the test fails, as it does on Rakudo Star 2026.08.
- **What:** adds test 18 to `S17-procasync/bind-handles.t`. It runs in a subprocess, so an abort fails one test instead of killing the file.
- **To submit:** clone Raku/roast (or your fork), `git am` the patch, push, open the PR against `Raku/roast` `master` with `roast-pr.md`, referencing the MoarVM PR. Submit after #1.

## Rakudo

### #4 Issue: closing a Proc's `.out` early buffers the rest of the output without limit

- **Status:** issue written, unsubmitted. No PR: the fix needs a design decision first.
- **Draft:** `rakudo-issue-proc-out-close-oom.md`
- **Depends on:** nothing to file it. The likely fix (close the read end so the producer gets SIGPIPE) would need a new MoarVM operation to close one output pipe of a running process: a follow-up MoarVM PR that doesn't exist yet.
- **What:** `run 'yes', :out` then `.out.close` never returns and memory grows until the OOM killer steps in. Output piles up in MoarVM's read queue (Rakudo grants unlimited read permits) and in `Proc`'s `Channel`.
- **Tested:**
  - peak memory measured on Rakudo Star 2026.08: 0.8 GB for 300 MB of discarded output, 1.4 GB for 1 GB
  - an attempted Rakudo-only fix (discard output after close) only slowed the growth, so it was dropped
  - the workaround in the draft (kill the process instead of closing `.out`) was run: one line printed, returns, 166 MB peak
- **Check before posting:** the "about 45 GB" figure for the original OOM comes from the earlier diagnosis and wasn't re-measured.
- **To submit:** open an issue on `rakudo/rakudo` with the draft as its body.

## Not attributed to a repo

### #5 SIGSEGV of 20 Nov 04:49

- **Status:** diagnosed, most likely the same cause as #3. No separate fix.
- **What crashed:** a Rakudo REPL (`rak/install/bin/moar`, no script argument) on the main thread, inside `READ`, called from `IO::Handle.get` → `get-line-slow-path` → `repl-read`: it was waiting for the next line of input.
- **Proven from the core:**
  - a dispatch op loaded a null inline-cache entry and called through it (`call *(%rbx)`, rbx = 0)
  - the interpreter's `cur_op` lies inside `READ`'s bytecode, but its `bytecode_start` points elsewhere, and `cur_op` sits 290 bytes into a 296-byte frame where no dispatch op fits, so the frame metadata and the bytes being run disagree
  - some frames have names that exist in no current Rakudo source, such as `<Argument 'count' should be greater than zero>`: names read from the wrong place in the string heap
  - every `blib/*.moarvm` file the process had mapped is marked `(deleted)` or was rewritten after the process started
- **Inferred:** the REPL sat idle at its prompt while Rakudo was rebuilt in place under it. When input arrived, it resumed on the rebuilt bytes with the old metadata. A reproduction of this pattern (see #3) gives the same kind of corruption: frames running foreign bytecode and garbled string-heap lookups. It didn't produce a SIGSEGV in a few tries, so the link is strong but not demonstrated end to end.
- **To avoid it now:** quit running REPLs and programs before rebuilding Rakudo, or install to a separate prefix. #3 removes the cause.

---

## Files in this folder

| File | Purpose |
|---|---|
| `README.md` | this status page |
| `moarvm-pr.md` | PR body for #1 |
| `nqp-pr.md` | PR body for #3 |
| `roast-pr.md` | PR body for #2 |
| `rakudo-issue-proc-out-close-oom.md` | issue body for #4 |
| `0001-*.patch` | one `git format-patch` per commit, for #1, #2 and #3 |

## Suggested order

1. Submit #1 (MoarVM) and #3 (NQP); they are independent.
2. File #4 (Rakudo issue).
3. Submit #2 (roast) once #1 is merged.
4. Update the status column here as each one is submitted and accepted.
