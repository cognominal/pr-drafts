# fix(tui): put the user message between the OSC 133 B and C marks

## What

<!-- CONTRIBUTOR'S OWN SENTENCE GOES HERE (required by CONTRIBUTING.md) -->

A user bubble now opens with `133;A` + `133;B` and closes with `133;C` + `133;D;0`, so the message is the command span:

```diff
-ESC]133;A <bubble rows> ESC]133;B ESC]133;C ESC]133;D;0
+ESC]133;A ESC]133;B <bubble rows> ESC]133;C ESC]133;D;0
```

The zone still opens and closes inside one render, so the caret fix of #8030 / #6115 holds: `C` clears Ghostty's sticky `.input` state as before.

## Why

Fixes #20123. Terminals that read the command from `B`..`C` got an empty string and skipped every omp prompt. tuios's scrollback browser (`<leader> s`) listed nothing in an omp pane.

## Testing

- **tuios's own parser:** fed both layouts to tuios `internal/scrollback.ParseBlocks` (via a `go test -overlay` test). Before: 0 blocks. After: 1 block, `cmd="hello from omp"`.
- **End to end in tuios 0.13.2:** ran this branch's omp in a tuios pane and sent two prompts. `tuios capture-pane --commands 5` splits the pane at both prompts, and `<leader> s` lists them.
- **Tests:** `user-message-keywords.test.ts` now checks that the bubble text sits between `B` and `C` and that the zone closes after the last row. The OSC 133 tests in `coding-agent` and `tui` pass (20 + 74).
- `bun check`: the TypeScript half passes. The Rust half could not run here (no `cargo` on PATH), and this change touches no Rust.

Not checked: Ghostty itself. The message cells now carry Ghostty's input mark between `B` and `C`. Click-to-move only acts while the cursor is at a prompt, and `C` in the same render ends that, but I have no Ghostty to confirm it.

---

- [ ] `bun check` passes
- [x] Tested locally
- [ ] CHANGELOG updated with the required attribution (if user-facing; internal issue fixes use issue links, external contributions add the PR link and contributor credit after creation)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
