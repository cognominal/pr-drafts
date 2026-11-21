# Test tapping a stdout after the process bound to it exited

Patch: roast/0001-Test-tapping-a-stdout-after-the-process-bound-to-it-.patch (on Raku/roast 7639d08)

## Summary

```diff
 S17-procasync/bind-handles.t
-plan 17;
+plan 18;
+  run in a subprocess:
+    consumer.bind-stdin(producer.stdout); start both
+    await consumer exit; tap producer.stdout; await producer
+    say "alive"
+  is output, 'alive'
```

This is a regression test for MoarVM PR (Close a bound stdin through libuv). The scenario runs in a subprocess, so an abort fails one test instead of killing the whole file.

## Evidence

- **Before:** (Rakudo Star 2026.08) `not ok 18`, 3/3 runs
  **After:** (MoarVM with the fix) `ok 18`, 18/18 passed, 5/5 runs

## Merge Danger

**Door:** two-way

**Blast Radius:** tests-only. It fails on Rakudo releases without the MoarVM fix, so merge it after the MoarVM PR.

## Context

Found while investigating MoarVM crashes I hit while working on [rak](https://github.com/cognominal/rak/tree/rak), a shell mode for Raku. The whole investigation, with the related PRs and issue: [pr-drafts](https://github.com/cognominal/pr-drafts#moarvm-crash-investigation-issues-and-prs).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
