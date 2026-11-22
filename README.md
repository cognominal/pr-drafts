# Issues and PRs

Upstream PRs and issues, and issues in my own repos. Four series: the MoarVM crash investigation (below), [tuios hover help](#tuios-hover-help-newhelp), [rak: irak feedback](#rak-irak-feedback-before-submission), and [oh-my-pi: OSC 133 marks](#oh-my-pi-osc-133-marks) (at the end).

## At a glance

- [MoarVM crash investigation](#moarvm-crash-investigation-issues-and-prs)
- [tuios: hover help](#tuios-hover-help-newhelp)
- [rak: irak feedback](#rak-irak-feedback-before-submission)
- [oh-my-pi: OSC 133 marks](#oh-my-pi-osc-133-marks)

## Contents

- [MoarVM crash investigation: issues and PRs](#moarvm-crash-investigation-issues-and-prs)
  - [Overview](#overview)
  - [MoarVM](#moarvm)
    - [#1 Close a bound stdin through libuv, not behind its back](#1-close-a-bound-stdin-through-libuv-not-behind-its-back)
  - [NQP](#nqp)
    - [#3 Write bytecode files to a temporary file and rename it into place](#3-write-bytecode-files-to-a-temporary-file-and-rename-it-into-place)
  - [roast](#roast)
    - [#2 Test tapping a stdout after the process bound to it exited](#2-test-tapping-a-stdout-after-the-process-bound-to-it-exited)
  - [Rakudo](#rakudo)
    - [#4 Issue: closing a Proc's `.out` early buffers the rest of the output without limit](#4-issue-closing-a-procs-out-early-buffers-the-rest-of-the-output-without-limit)
  - [Not attributed to a repo](#not-attributed-to-a-repo)
    - [#5 SIGSEGV of 20 Nov 04:49](#5-sigsegv-of-20-nov-0449)
  - [Layout](#layout)
  - [Suggested order](#suggested-order)
- [tuios: hover help (newhelp)](#tuios-hover-help-newhelp)
  - [T1 Hover help explains the dock and the desktop](#t1-hover-help-explains-the-dock-and-the-desktop)
  - [T2 Hover help explains the rail and the panes](#t2-hover-help-explains-the-rail-and-the-panes)
  - [T3 Hover help stands aside for the leader menu](#t3-hover-help-stands-aside-for-the-leader-menu)
  - [T4 An opt-in ? control on the dock](#t4-an-opt-in--control-on-the-dock)
- [rak: irak feedback before submission](#rak-irak-feedback-before-submission)
  - [R1 \[RFE\] in irak add feedback before submission](#r1-rfe-in-irak-add-feedback-before-submission)
  - [R2 Terminal::LineEditor: an `&on-finish` callback, and a timeout on terminal queries](#r2-terminallineeditor-an-on-finish-callback-and-a-timeout-on-terminal-queries)
- [oh-my-pi: OSC 133 marks](#oh-my-pi-osc-133-marks)
  - [O1 The OSC 133 marks on a user message leave the command empty](#o1-the-osc-133-marks-on-a-user-message-leave-the-command-empty)

# MoarVM crash investigation: issues and PRs

Status as of 2026-11-21. #1, #3 and #4 are submitted; #2 waits for #1 to be merged. Each body links back here and to rak.

**Claude session:** `c931c668-6e04-4d17-8ea8-8a92fadb9e27`. Resume it with `cd ~/git/cognominal---moarvm && claude --resume c931c668-6e04-4d17-8ea8-8a92fadb9e27`; transcript in `~/.claude/projects/-home-cog-git-cognominal---moarvm/c931c668-6e04-4d17-8ea8-8a92fadb9e27.jsonl`.

**Trigger:** MoarVM kept crashing on this machine while I worked on rak, and one run took down my whole terminal session. I asked Claude to investigate the core dumps (4 × SIGABRT, 2 × SIGBUS, 1 × SIGSEGV) and the out-of-memory kill, reproduce each with a minimal program, and fix them against the upstream repos. Each cause sat in a different layer, so the fixes span MoarVM, NQP, roast and Rakudo.

Status values: **WIP** (work in progress) · **tested** (fix written and verified locally) · **unsubmitted** · **submitted** · **accepted** · **open** (no fix yet)

## Overview

| # | Repo | Kind | Fixes | Status | Needs |
|---|---|---|---|---|---|
| 1 | MoarVM | [PR](https://github.com/MoarVM/MoarVM/pull/2087) | 4 × SIGABRT | submitted | — |
| 2 | roast | PR | test for #1 | tested | #1 merged |
| 3 | NQP | [PR](https://github.com/Raku/nqp/pull/882) | 2 × SIGBUS, SIGSEGV | submitted | — |
| 4 | Rakudo | [issue](https://github.com/rakudo/rakudo/issues/6951) | OOM | filed | — |
| 5 | — | crash | SIGSEGV | diagnosed | fixed by #3 |

#1, #3 and #4 are submitted. Details per repo below.

---

## MoarVM

### #1 Close a bound stdin through libuv, not behind its back

- **Status:** submitted 2026-11-21 as [MoarVM/MoarVM#2087](https://github.com/MoarVM/MoarVM/pull/2087), awaiting review
- **Branch:** `fix-bind-stdin-close` in `~/git/cognominal---moarvm`, 1 commit (94401a2a9) on `upstream/main` 5249be7aa (MoarVM/MoarVM), pushed to `cognominal/MoarVM-hamt`
- **Patch:** [`moarvm/0001-Close-a-bound-stdin-through-libuv-not-behind-its-bac.patch`](moarvm/0001-Close-a-bound-stdin-through-libuv-not-behind-its-bac.patch)
- **PR body:** [`moarvm/pr-fix-bind-stdin-close.md`](moarvm/pr-fix-bind-stdin-close.md)
- **Depends on:** nothing
- **Needed by:** #2 (roast test)
- **What:** `src/io/procops.c`. When a process whose stdin was bound to another process's stdout exits, MoarVM called `close()` on a descriptor still owned by the producer's `uv_pipe_t`. A later read made libuv `abort()` in `uv__epoll_ctl_flush`. The fix closes it through `uv_close` on the owning handle, and falls back to `close()` only when no handle owns it.
- **Tested:**
  - repro aborts 3/3 before, exits normally 3/3 after
  - roast test #2: fails on Rakudo Star 2026.08, passes 5/5 with the fix
  - rakudo#3057 fd-leak check unchanged
  - roast `S17-procasync/*`, `S32-io/pipe.t`, `S29-os/system.t`: same results before and after
- **Next:** answer review comments on #2087; once merged, submit #2.

## NQP

### #3 Write bytecode files to a temporary file and rename it into place

- **Status:** submitted 2026-11-21 as [Raku/nqp#882](https://github.com/Raku/nqp/pull/882), awaiting review
- **Branch:** `atomic-mbc-write` in `~/git/cognominal---nqp`, 1 commit (5b8779a8f) on `upstream/main` 5397dd7da (Raku/nqp), pushed to `cognominal/nqp`
- **Patch:** [`nqp/0001-Write-bytecode-files-to-a-temporary-file-and-rename-.patch`](nqp/0001-Write-bytecode-files-to-a-temporary-file-and-rename-.patch)
- **PR body:** [`nqp/pr-atomic-mbc-write.md`](nqp/pr-atomic-mbc-write.md)
- **Depends on:** nothing
- **What:** `src/vm/moar/QAST/QASTCompilerMAST.nqp`, `assemble_to_file`. Rebuilding truncated `.moarvm` files that running processes had memory-mapped, which caused SIGBUS. The writer now writes `$filename.tmp-$pid` and renames it over the target.
- **Tested:**
  - recompiling gives the output a new inode, leaves no temp file, and the output runs
  - NQP `make test`: 150 files, 13746 tests, all pass
- **Reproduced:** recompiling a `.moarvm` file while a process is blocked in one of its subs makes that process fail when it resumes, 3/3 per variant (wrong-type and string-heap errors). With the patched NQP doing the recompile: 3/3 normal exit.
- **Not tested:** the SIGBUS itself (needs the file to shrink under a mapped page; the diagnosis rests on the two core dumps' fault offsets); Windows `rename` over an existing file.
- **Next:** answer review comments on #882.

## roast

### #2 Test tapping a stdout after the process bound to it exited

- **Status:** tested, unsubmitted
- **Branch:** `bind-stdin-tap-after-exit` in `~/git/cognominal---roast`, 1 commit (1e6f0c19e) on `upstream/master` 7639d08 (Raku/roast)
- **Patch:** [`roast/0001-Test-tapping-a-stdout-after-the-process-bound-to-it-.patch`](roast/0001-Test-tapping-a-stdout-after-the-process-bound-to-it-.patch)
- **PR body:** [`roast/pr-bind-stdin-tap-after-exit.md`](roast/pr-bind-stdin-tap-after-exit.md)
- **Depends on:** #1 merged and in a Rakudo release. Otherwise the test fails, as it does on Rakudo Star 2026.08.
- **What:** adds test 18 to `S17-procasync/bind-handles.t`. It runs in a subprocess, so an abort fails one test instead of killing the file.
- **To submit:** push the branch to your roast fork, open the PR against `Raku/roast` `master` with `roast/pr-bind-stdin-tap-after-exit.md`, which references MoarVM/MoarVM#2087. Submit after #1.

## Rakudo

### #4 Issue: closing a Proc's `.out` early buffers the rest of the output without limit

- **Status:** filed 2026-11-21 as [rakudo/rakudo#6951](https://github.com/rakudo/rakudo/issues/6951). No PR: the fix needs a design decision first.
- **Draft:** [`rakudo/issue-proc-out-close-oom.md`](rakudo/issue-proc-out-close-oom.md)
- **Depends on:** nothing to file it. The likely fix (close the read end so the producer gets SIGPIPE) would need a new MoarVM operation to close one output pipe of a running process: a follow-up MoarVM PR that doesn't exist yet.
- **What:** `run 'yes', :out` then `.out.close` never returns and memory grows until the OOM killer steps in. Output piles up in MoarVM's read queue (Rakudo grants unlimited read permits) and in `Proc`'s `Channel`.
- **Tested:**
  - peak memory measured on Rakudo Star 2026.08: 0.8 GB for 300 MB of discarded output, 1.4 GB for 1 GB
  - an attempted Rakudo-only fix (discard output after close) only slowed the growth, so it was dropped
  - the workaround in the draft (kill the process instead of closing `.out`) was run: one line printed, returns, 166 MB peak
- **Checked:** the "about 45 GB" figure matches the systemd-oomd log of 20 Nov 16:49: 15.7 GB RAM plus 29.5 GB swap in use, machine-wide.
- **Next:** follow the discussion on #6951; if option B is chosen, it needs a MoarVM PR for an op that closes one output pipe of a running process.

## Not attributed to a repo

### #5 SIGSEGV of 20 Nov 04:49

- **Status:** diagnosed, most likely the same cause as #3 ([Raku/nqp#882](https://github.com/Raku/nqp/pull/882)). No separate fix.
- **What crashed:** a Rakudo REPL (`rak/install/bin/moar`, no script argument) on the main thread, inside `READ`, called from `IO::Handle.get` → `get-line-slow-path` → `repl-read`: it was waiting for the next line of input.
- **Proven from the core:**
  - a dispatch op loaded a null inline-cache entry and called through it (`call *(%rbx)`, rbx = 0)
  - the interpreter's `cur_op` lies inside `READ`'s bytecode, but its `bytecode_start` points elsewhere, and `cur_op` sits 290 bytes into a 296-byte frame where no dispatch op fits, so the frame metadata and the bytes being run disagree
  - some frames have names that exist in no current Rakudo source, such as `<Argument 'count' should be greater than zero>`: names read from the wrong place in the string heap
  - every `blib/*.moarvm` file the process had mapped is marked `(deleted)` or was rewritten after the process started
- **Inferred:** the REPL sat idle at its prompt while Rakudo was rebuilt in place under it. When input arrived, it resumed on the rebuilt bytes with the old metadata. A reproduction of this pattern (see #3) gives the same kind of corruption: frames running foreign bytecode and garbled string-heap lookups. It didn't produce a SIGSEGV in a few tries, so the link is strong but not demonstrated end to end.
- **To avoid it now:** quit running REPLs and programs before rebuilding Rakudo, or install to a separate prefix. #3 removes the cause.

---

## Layout

One folder per upstream repo. Each holds the `git format-patch` files of its PRs and the PR or issue bodies to paste.

| Folder | Upstream | Items | Session |
|---|---|---|---|
| [`moarvm/`](moarvm/) | MoarVM/MoarVM | #1 | `c931c668` |
| [`nqp/`](nqp/) | Raku/nqp | #3 | `c931c668` |
| [`roast/`](roast/) | Raku/roast | #2 | `c931c668` |
| [`rakudo/`](rakudo/) | rakudo/rakudo | #4 | `c931c668` |
| [`tuios/`](tuios/) | Gaurav-Gosain/tuios | T1–T4 | `25d34f6d` |
| [`rak/`](rak/) | cognominal/rak | R1 | `c931c668` |
| [`terminal-lineeditor/`](terminal-lineeditor/) | japhb/Terminal-LineEditor | R2 | `7c865896` |
| [`oh-my-pi/`](oh-my-pi/) | can1357/oh-my-pi | O1 | `40df6d54` |

Sessions are local Claude Code sessions (no web link). The full IDs and resume commands are at the top of each series.

## Suggested order

1. ~~Submit #1 (MoarVM) and #3 (NQP)~~ done: MoarVM#2087, nqp#882.
2. ~~File #4 (Rakudo issue)~~ done: rakudo#6951.
3. Submit #2 (roast) once #1 is merged.
4. Update the status column here as each one is submitted and accepted.

---

# tuios: hover help (newhelp)

Status as of 2026-11-21. **Nothing has been pushed, submitted or posted.**

**Trigger:** my own feature work on tuios: bringing Gaurav-Gosain/tuios#1859 (help mode) up to date.

A stacked series that redoes Gaurav-Gosain/tuios#1859 (help mode) on current main, as **hover help**: Ctrl+b h toggles a borderless explainer next to the thing it explains. No localisation. Worktree: `~/.local/share/tuios/worktrees/Gaurav-Gosain---tuios/newhelp`. Branches `feat/newhelp-N-<topic>`, each on the one before. Files are in [`tuios/`](tuios/).

**Claude session:** `25d34f6d-d9d7-4dfb-bf4a-f84f83552d81`. Resume it with `cd ~/git/Gaurav-Gosain---tuios && claude --resume 25d34f6d-d9d7-4dfb-bf4a-f84f83552d81`; transcript in `~/.claude/projects/-home-cog-git-Gaurav-Gosain---tuios/25d34f6d-d9d7-4dfb-bf4a-f84f83552d81.jsonl`.

| # | What | Status | Needs |
|---|---|---|---|
| T1 | engine, dock, desktop | tested | main |
| T2 | rail and panes | tested | T1 |
| T3 | aside for leader menu | tested | T2 |
| T4 | `?` control on the dock | tested | T3 |

None is submitted yet. T1 also raises the size ceiling to 50.5 MB. Branches are `feat/newhelp-N-<topic>`.

### T1 Hover help explains the dock and the desktop

- **Status:** tested, unsubmitted
- **Commits:** 7d91c76e4 `chore: raise the binary size ceiling to 50.5 MB`, then ee501bdbe, on origin/main 4c12ece99
- **Patches:** [`tuios/0001-chore-raise-the-binary-size-ceiling-to-50.5-MB.patch`](tuios/0001-chore-raise-the-binary-size-ceiling-to-50.5-MB.patch), [`tuios/0002-feat-hover-help-explains-the-dock-and-the-desktop.patch`](tuios/0002-feat-hover-help-explains-the-dock-and-the-desktop.patch)
- **PR body:** [`tuios/pr1-engine.md`](tuios/pr1-engine.md)
- **Tested:**
  - 7 e2e tests in `e2e/tui/hover_help_test.go`: pass on the real and sim backends, and all 7 fail on main
  - `just check --changed` green
  - the unit tests of config, input, app and cmd/tuios pass
  - `TestIdleCostStaysLow` passes
  - size: +106,496 B on linux/amd64, +107,008 B on windows/amd64. Main had 84,096 B of room on Windows, so the first commit raises the ceiling to 50,500,000 B (your decision, 2026-11-20). `just size` passes, with 477,088 B left on windows/amd64.
- **To submit:**
  1. Push the branch to your fork.
  2. Open the PR against `Gaurav-Gosain/tuios` `main` with `tuios/pr1-engine.md`, marked ready only after `just check --changed`.
  3. The maintainer lands it with the `full-suite` label.

### T2 Hover help explains the rail and the panes

- **Status:** tested, unsubmitted
- **Commit:** 50cbf5143 on T1 ee501bdbe
- **Patch:** [`tuios/0003-feat-hover-help-explains-the-rail-and-the-panes.patch`](tuios/0003-feat-hover-help-explains-the-rail-and-the-panes.patch)
- **PR body:** [`tuios/pr2-rail-panes.md`](tuios/pr2-rail-panes.md)
- **Tested:**
  - 9 hover help e2e tests pass on the real and sim backends
  - the 2 new tests fail on a T1 build
  - `just check --changed` green
  - the unit tests pass
  - `TestIdleCostStaysLow` passes
  - size against T1: +24,576 B on linux/amd64, +27,648 B on windows/amd64, 449,440 B under the new ceiling
  - 2026-11-21: fixed after your manual test. A rail section's explainer covered the rest of the rail; it now goes beside the rail. The rail test checks it, and fails on the old build
- **To submit:** after T1 is open, push the branch and open the PR with `tuios/pr2-rail-panes.md`, replacing `#T1` with T1's number.

### T3 Hover help stands aside for the leader menu

- **Status:** tested, unsubmitted
- **Commit:** 5dfbf0ef8 on T2 50cbf5143
- **Patch:** [`tuios/0004-feat-hover-help-stands-aside-for-the-leader-menu.patch`](tuios/0004-feat-hover-help-stands-aside-for-the-leader-menu.patch)
- **PR body:** [`tuios/pr3-leader.md`](tuios/pr3-leader.md)
- **Tested:**
  - 10 hover help e2e tests pass on the real and sim backends
  - the new test fails on a T2 build, and on a build without the pointer freeze
  - `just check --changed` green
  - `TestIdleCostStaysLow` passes, renders=0
  - size: +0 B on all three targets
- **To submit:** after T2 is open, push the branch and open the PR with `tuios/pr3-leader.md`, replacing `#T2`.

### T4 An opt-in ? control on the dock

- **Status:** tested, unsubmitted
- **Commit:** 13f751c95 on T3 5dfbf0ef8
- **Patch:** [`tuios/0005-feat-an-opt-in-control-on-the-dock-for-hover-help.patch`](tuios/0005-feat-an-opt-in-control-on-the-dock-for-hover-help.patch)
- **PR body:** [`tuios/pr4-dock-control.md`](tuios/pr4-dock-control.md)
- **Tested:**
  - 11 hover help e2e tests pass on the real and sim backends
  - the new test fails on a T3 build
  - `just check --changed` green
  - the unit tests of config, app, input and cmd/tuios pass
  - `TestIdleCostStaysLow` passes
  - size at the head: 49,619,104 B linux/amd64, 50,053,120 B windows/amd64 (446,880 B under the ceiling)
- **To submit:** after T3 is open, push the branch and open the PR with `tuios/pr4-dock-control.md`, replacing `#T3`.

---

# rak: irak feedback before submission

**Trigger:** a feature request of mine for irak, the interactive rak: before running a submission, insert `my` before undeclared variables and color each word by what it denotes; a second Enter within a second runs it.

**Claude sessions:**

- R1 was filed from `c931c668-6e04-4d17-8ea8-8a92fadb9e27` (the MoarVM session, see above).
- R2 and the implementation of R1 come from `7c865896-317a-4fb4-8b4a-9676a664420e`. Resume it with `cd ~/.local/share/tuios/worktrees/cognominal---rak/irak-feedback && claude --resume 7c865896-317a-4fb4-8b4a-9676a664420e`; transcript in `~/.claude/projects/-home-cog--local-share-tuios-worktrees-cognominal---rak-irak-feedback/7c865896-317a-4fb4-8b4a-9676a664420e.jsonl`.

| # | Repo | Kind | Topic | Status |
|---|---|---|---|---|
| R1 | rak | [issue](https://github.com/cognominal/rak/issues/1) | irak feedback | WIP |
| R2 | LineEditor | PR | on-finish | tested |

### R1 [RFE] in irak add feedback before submission

- **Status:** filed 2026-11-21 as [cognominal/rak#1](https://github.com/cognominal/rak/issues/1), label `enhancement`. The first issue of the repo: issues were enabled for it.
- **Body:** [`rak/issue-irak-feedback.md`](rak/issue-irak-feedback.md), also kept in the rak repo as `.scratch/irak/issues/01-feedback-before-submission.md` on branch `rak` (not committed yet).
- **Contents:** the proposed behavior (where `my` goes, typos left alone, the one-second window) and an implementation in three parts: analysis by compiling without running, an `&on-finish` hook to propose upstream to Terminal::LineEditor, and coloring through a subclass of its input field.
- **Open point:** compiling for the analysis runs `BEGIN` and `use` once more.
- **Work:** being implemented by Claude in the tuios session `cognominal-rak-irak-feedback`, branch `irak-feedback` from `rak`, worktree `~/.local/share/tuios/worktrees/cognominal---rak/irak-feedback`. It is built against the latest NQP `main` (5397dd7da) and the MoarVM it pins, newer than the NQP_REVISION of `rak`.
- **Status:** WIP. Pushed to branch [`irak-feedback`](https://github.com/cognominal/rak/tree/irak-feedback) of cognominal/rak: 6cd8eb21d8 (the feature), 01a1a6dc23 (tracks the Terminal::LineEditor patch) and b4e8f70a24 (variables and paths highlighted, the terminal cheat sheet).
- **Works:** the first Enter colors each word; a second Enter within a second runs the line; `NO_COLOR` turns the colors off. `my` goes before the first occurrence of an undeclared variable, wherever it compiles. Variables are italic and paths blue (redirection targets always, command arguments when they read as paths). The convention is in `PLANS/highlight.md`.
- **Cheat sheet:** `tools/rak-cheatsheet.raku` (`make rak-cheatsheet`) renders `PLANS/docs/CHEATSHEET.md` as `PLANS/docs/CHEATSHEET.ans` with irak's highlighting; read it with `less -R`. The cheat sheet and the three irak tutorials moved to `PLANS/docs/`.
- **Tests:** `t/02-rakudo/rak/022-irak-feedback.t` (42 tests), `023-cheatsheet.t` (5), `t/02-rakudo/repl.t` and `make rak-test` pass.
- **Does not work yet:** the insertion of `my` does not show up in the live REPL, although the analysis tests pass. The colors are lost as soon as the line is edited.
- **Comment:** posted 2026-11-21 as [issuecomment-7068783661](https://github.com/cognominal/rak/issues/1#issuecomment-7068783661); text in [`rak/comment-irak-feedback-wip.md`](rak/comment-irak-feedback-wip.md).
- **Depends on:** R2. Until it is merged, the rak build applies R2 as `tools/build/rak-line-editor-patches/Terminal-LineEditor-0.0.23.patch` to the pinned Terminal::LineEditor 0.0.23.
- **Next:** make the `my` insertion work in the live REPL, keep the colors while editing, then merge into `rak` and close R1.

### R2 Terminal::LineEditor: an `&on-finish` callback, and a timeout on terminal queries

- **Status:** tested, unsubmitted
- **Branch:** `on-finish` in `~/git/japhb---Terminal-LineEditor`, 2 commits (371eff6, 2f97d14) on 97fa744 (release 0.0.23, japhb/Terminal-LineEditor). Not pushed anywhere: a fork is needed to submit.
- **Patches:** [`terminal-lineeditor/0001-Time-out-terminal-queries-in-read-input.patch`](terminal-lineeditor/0001-Time-out-terminal-queries-in-read-input.patch), [`terminal-lineeditor/0002-Add-an-on-finish-callback-to-read-input-and-prompt.patch`](terminal-lineeditor/0002-Add-an-on-finish-callback-to-read-input-and-prompt.patch)
- **PR body:** [`terminal-lineeditor/pr-on-finish.md`](terminal-lineeditor/pr-on-finish.md)
- **Depends on:** nothing
- **Needed by:** R1 (applied as a patch in the meantime)
- **What:** `lib/Terminal/LineEditor/RawTerminalInput.rakumod`.
  - `read-input` and `prompt` take `:&on-finish`, called with the buffer on Enter: `True` finishes, a string replaces the buffer and keeps editing, a false value keeps editing.
  - The cursor-position and screen-size queries are sent together and time out after `$.query-timeout` (1 s), falling back to column 1 and 80 columns. A terminal that never answered hung the prompt.
- **Tested:** the module's own tests pass; irak uses both changes (see R1).
- **To submit:** fork japhb/Terminal-LineEditor, push `on-finish`, open the PR with the body above. The two commits are independent and could be split into two PRs.

---

# oh-my-pi: OSC 133 marks

**Trigger:** omp sends OSC 133, but the tuios scrollback browser (`<leader> s`) lists no command in an omp pane. Diagnosed in tuios, then filed upstream instead of working around it in tuios.

**Claude session:** `40df6d54-c106-447d-acd9-d8c333c2a809`. Resume it with `cd ~/.local/share/tuios/worktrees/Gaurav-Gosain---tuios/omp-osc133 && claude --resume 40df6d54-c106-447d-acd9-d8c333c2a809`; transcript in `~/.claude/projects/-home-cog--local-share-tuios-worktrees-Gaurav-Gosain---tuios-omp-osc133/40df6d54-c106-447d-acd9-d8c333c2a809.jsonl`.

| # | Repo | Kind | Topic | Status |
|---|---|---|---|---|
| O1 | oh-my-pi | [issue](https://github.com/can1357/oh-my-pi/issues/20123) | OSC 133 | filed |

### O1 The OSC 133 marks on a user message leave the command empty

- **Status:** filed 2026-11-22 as [can1357/oh-my-pi#20123](https://github.com/can1357/oh-my-pi/issues/20123)
- **Body:** [`oh-my-pi/issue-osc133-empty-command.md`](oh-my-pi/issue-osc133-empty-command.md)
- **What:** `UserMessageComponent.render()` in `packages/tui/src/chat/user-message.ts` puts `133;A` at the start of the bubble and `133;B`, `C` and `D;0` together at the end of its last row. The message lands in the prompt span, and the command span (`B`..`C`) is empty. tuios's scrollback parser (`internal/scrollback/parser.go`, `parseWithMarkers`) skips a block with an empty command, so an omp pane lists none.
- **Proposed:** emit `B` right after `A`, keep `C` and `D` at the end of the same render, so the caret fix of #8030 holds. Optionally move `D` after the reply.
- **Checked:** a `script` recording of omp 19.1.0 with two prompts: 6 copies of each mark (repaints write them again), all with `B`, `C` and `D` adjacent. `main` places the marks the same way.
- **Related:** #8030 and #6115 (the caret bug), #17145 and #17307 (OSC 7501 side effects of the same marks).
- **Depends on:** nothing
- **Not done:** no workaround in tuios. tuios also drops a `working` OSC 7501 record on `133;A` (`internal/session/program_status.go`), as #17145 describes for Rex; omp now turns the marks off while a run is active.
- **Next:** follow the discussion on #20123.
