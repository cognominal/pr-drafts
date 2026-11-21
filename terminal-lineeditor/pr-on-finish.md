# Add an &on-finish callback, and time out the terminal queries

## Summary

Two commits on `RawTerminalInput.rakumod`, both in `CLIInput.read-input`.

**1. `&on-finish`.** A caller can now look at the buffer when the user presses
Enter, and keep editing instead of returning. A REPL can use it to rewrite or
annotate a line before it runs, or to ask for a second Enter.

```diff
 read-input(Str :$mask, :&on-suspend, :&on-continue,
+           :&on-finish --> Str)
 prompt(Str:D $prompt = '', Str :$mask,
+       :&on-finish --> Str)

 when 'finish'
-  self.set-done; done
+  $verdict = &on-finish ?? on-finish($buffer) !! True
+  if $verdict ~~ Str:D
+    replace the input field with $verdict, keep editing
+  elsif $verdict
+    self.set-done; done
+  # a false verdict keeps editing, buffer unchanged
```

Without `&on-finish` the behavior is unchanged.

**2. Query timeout.** `read-input` asks the terminal for the cursor position and
the screen size, then waits without a limit. A terminal or pty that never
answers hangs the prompt forever.

```diff
+has Real:D $.query-timeout = 1
 read-input
-  $col  = await detect-cursor-pos
-  $cols = await detect-terminal-size
+  send both queries, then await both (concurrent)
+  each answer is Str after $.query-timeout
+  $col  //= 1;  $cols //= 80
```

A late answer stays matched to its own query record, so it is consumed and
never mistaken for typed input or another query's answer.

## Evidence

- **`&on-finish`, before:** Enter always returns the buffer.
  **After:** with `-> $b { $b eq 'x' ?? True !! 'x' }`, typing `abc` Enter
  shows `x` in the field; a second Enter returns `x`.
- **Timeout, before:** in a pty that never answers `\e[6n`, `prompt` hangs.
  **After:** the prompt appears after 1 s with an 80-column field; a terminal
  that answers sees no delay, since both queries are now in flight at once.
- `zef test .`: all tests pass, before and after.
- Used by the rak REPL (irak, cognominal/rak#1): the first Enter inserts `my`
  before undeclared variables and colors the line, a second Enter within a
  second runs it. Tested there in a pty and with `t/02-rakudo/repl.t`.

## Merge Danger

**Door:** two-way

Both changes are additive; reverting them restores the old behavior.

**Blast Radius:** small

Callers that pass no `&on-finish` see no change. The timeout only affects
terminals that do not answer within 1 s; they get default sizes instead of a
hang. `$.query-timeout` is configurable at construction.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
