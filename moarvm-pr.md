# Close a bound stdin through libuv, not behind its back

Branch: `fix-bind-stdin-close` in ~/git/cognominal---moarvm (on upstream/main 5249be7aa)

## Summary

When a process whose stdin is bound (with close) to another process's stdout exits, MoarVM `close()`d the descriptor, while the producer's `uv_pipe_t` still owned it.

```diff
 async_spawn_on_exit / spawn_setup error path
-  close(si->stdin_to_close)
+  close_bound_stdin(loop, si)
+    uv_walk(loop) → handle whose uv_fileno == fd
+    found     → uv_close(handle)    # stops its read watcher too
+    not found → close(fd)           # keeps the a71eee4c2 leak fix
```

Tapping the producer's stdout afterwards made libuv add a dead fd to epoll and `abort()` in `uv__epoll_ctl_flush` (`linux.c:1338`). If the fd number had been reused, it read from an unrelated file instead. Now `uv_read_start` on the closed handle just returns `UV_EINVAL`.

## Evidence

```raku
my $a = Proc::Async.new('sh', '-c', 'sleep 0.3; echo x');
my $b = Proc::Async.new('true');
my $s = $a.stdout;
$b.bind-stdin($s);
my $pa = $a.start;
await $b.start;
$s.tap(-> $ { });
my $ = await $pa;
```

- **Before:** SIGABRT 3/3 (upstream main and Rakudo Star 2026.08)
  **After:** exits normally 3/3. The producer gets SIGPIPE, as expected once its reader is gone.
- roast `S17-procasync/bind-handles.t` with the new test 18 (Raku/roast branch `bind-stdin-tap-after-exit`):
  **Before:** `not ok 18` 3/3. **After:** 18/18 5/5.
- rakudo#3057 fd-leak check: 300 bound pipelines leave the same number of open fds before and after.
- roast `S17-procasync/*`, `S32-io/pipe.t`, `S29-os/system.t`: same results before and after.

## Merge Danger

**Door:** two-way

**Blast Radius:** small. Only processes spawned with `stdin_fd_close`, i.e. Rakudo's `bind-stdin` given another process's pipe. A descriptor no libuv handle owns is closed exactly as before.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
