# Stop the input parser without blocking in read

## Summary

One commit on `RawTerminalInput.rakumod`. After `leave-raw-mode`, the parser
thread stays blocked in `$.input.read(1)`, because it checks `$!done` only
after each byte. The next byte typed goes to that stale thread, so the next
reader loses it. The next reader is either a program that the caller runs
with the terminal, or the parser of the next prompt.

```diff
 start-parser
+  generation = ++parser-generation
+  stopped = done || parser-generation != generation
   until stopped
-    b = $.input.read(1)
+    wait with poll(2) in 50 ms slices, until input or stopped
+    if stopped: exit
+    b = read(2) of one byte from the descriptor
     parse b
```

Three details:

- **read(2):** the parser reads the descriptor itself. `IO::Handle.read`
  reads ahead into the handle's decoder, where `poll` does not see the bytes.
- **Generations:** each `start-parser` stops the parsers of older
  generations. Without this, a parser that has not yet seen `$!done` could
  carry on beside the new one when raw mode is entered again quickly.
- **Type-ahead:** the read-ahead used to keep keys typed ahead of the next
  prompt. `enter-raw-mode` now uses `DRAIN` instead of `FLUSH`, so it keeps
  unread input. A byte that a stopping parser has already read is still
  parsed, for the next prompt.

On Windows the parser reads as before.

## Evidence

Each check runs under `script(1)`, which feeds the keys and answers the
cursor queries.

- **Handover:** enter and leave raw mode, then `run 'head', '-c', '5'`, and
  type `hello`.
  **Before:** the child gets `ello` and waits for a fifth byte.
  **After:** the child gets `hello`.
- **Two prompts:** call `prompt` twice, typing `ab` Enter, then `xy` Enter.
  **Before:** the first prompt returns `ab`. The second prompt never sees
  `x`, which the stale thread took, and hangs.
  **After:** the prompts return `ab` and `xy`, whether `xy` is typed later or
  ahead, in the same burst as `ab`.
- The module's tests under `t/` pass, before and after.
- rak's REPL (cognominal/rak) carries this change as a build patch. Its
  `Ctrl-R` hands the terminal to `atuin search`, which now receives every key.

## Merge Danger

**Door:** two-way

Reverting the commit restores the old reader.

**Blast Radius:** small

- The parser now calls `poll` and `read` from libc through NativeCall, on
  every platform except Windows.
- Keys typed before a prompt are no longer flushed. They reach the prompt as
  they did before when the read-ahead had already buffered them.
- Bytes that a caller reads from `$*IN` through the handle, before raw mode,
  stay in the handle's decoder, and the parser does not see them.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
