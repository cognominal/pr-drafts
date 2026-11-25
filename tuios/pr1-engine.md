# feat: hover help explains the dock and the desktop

Part 1 of 4. Builds on the ideas of #1859, redone on current main. Ctrl+b h turns on **hover help**: a borderless **explainer** next to its **target** says what the target is for, what it shows, its keys and the CLI that changes it.

## Summary

```diff
 HandleKeyPress
   ShowKeys capture
+  hoverHelpKey            # [keybindings.help], only while hover help is on
   mode dispatch
 mouse click / motion / wheel
+  click on the explainer: swallowed; elsewhere: passes through
+  motion: picks the target, then passes on
+  wheel over the explainer: scrolls it
 View
   dock layer
+  explainer layer (z = which-key + 1), nil while off
```

Help keys (rebindable, footer shows the bound ones):

| Action | Default |
|---|---|
| `toggle_hover_help` | Ctrl+b h |
| `help_next` / `help_prev` | ctrl+alt+right / ctrl+alt+left |
| `help_deeper` / `help_shallower` | ctrl+alt+down / ctrl+alt+up |
| `help_scroll_up` / `help_scroll_down` | ctrl+alt+pgup / ctrl+alt+pgdown |
| `help_keys` | alt+shift+h |

The help keys are read before every other key route while hover help is on, so no default is a key that another table binds. `TestHoverHelpShadowsNoDefaultBinding` presses every section's default keys with hover help on, and `TestDefaultHelpKeysAreBoundInNoOtherTable` checks the help defaults against every table, including the GUI client's. Ghostty on Linux, and some desktops, keep Ctrl+Alt with the arrows for themselves; `docs/KEYBINDINGS.md` says to bind other keys there.

Hover help is a view, not a mode: every other key reaches the pane. `?` still opens the key list. This part covers the dock, each dock cell, and the desktop. The rail and panes come in part 2, the leader menu in part 3, and the dock `?` control in part 4.

The explainer on the dock's mode pill (`TestHoverHelpExplainsTheDockCellUnderThePointer`):

```text
│                                                                                                                      │
 Mode                                                                                                                  │
 Dock › Mode                                                                                                           │
 window mode                                                                                                           │
                                                                                                                       │
 The input mode: window management or terminal. It answers                                                             │
 where the next key goes, and it changes while the leader                                                              │
 waits for its key.                                                                                                    │
                                                                                                                       │
 What it shows                                                                                                         │
 H        Tiling is on and the next split is stacked.                                                                  │
 V        Tiling is on and the next split is side by side.                                                             │
 HOLD     The hold key has borrowed window mode while it is                                                            │
          held.                                                                                                        │
 HINTS    Hints mode owns the keyboard.                                                                                │
 SIDEBAR  The rail owns the keyboard.                                                                                  │
 MULTI    Multi-copy drives several panes.                                                                             │
 row:col  The focused pane is in copy mode, at that row and                                                            │
          column.                                                                                                      │
 Z        A pane of this workspace is zoomed.                                                                          │
                                                                                                                       │
 Keys                                                                                                                  │
 Ctrl+b t      Enter window prefix                                                                                     │
 ?             Toggle help                                                                                             │
 Ctrl+b Space  Toggle tiling mode                                                                                      │
                                                                                                                       │
 CLI                                                                                                                   │
 $ tuios set-config appearance.dock_mode_pill input                                                                    │
 $ tuios set-config appearance.dock_mode_split_letter false                                                            │
 $ tuios set-config appearance.dock_prefix_indicator badge                                                             │
 $ tuios keybinds list                                                                                                 │
                                                                                                                       │
 Ctrl+Alt+←/Ctrl+Alt+→ components
 Ctrl+Alt+↑/Ctrl+Alt+↓ parts · Alt+Shift+h keys
 Ctrl+b h close                                             ────────────────────────────────────────────────────────────
  V   1   +  1:1                                                                                              
```

## Evidence

`e2e/tui/hover_help_test.go`, 8 tests, each saves its screens as artifacts:

- **Before** (main 4c12ece99): all 8 fail at their first wait for the explainer.
- **After:** all 8 pass on the `real` and `sim` backends.
  - toggles twice
  - explains the dock cell under the pointer
  - explains the CPU and the RAM readouts side by side, each at its own columns
  - walks with the help keys, and alt+shift+h shows all keys
  - leaves typing to the pane
  - passes plain keys through: `cat -v` gets Up, Down and h, and no help key
  - the footer shows a rebound key
  - lets a click through: the dock's `+` makes workspace 2

Also checked:

- `just check --changed`: all checks pass.
- `go test` on internal/config, internal/input, internal/app and cmd/tuios: pass.
- Unit tests for key shadowing, on the old shift defaults:
  - `TestHoverHelpShadowsNoDefaultBinding` fails 14 subtests: terminal scroll, copy mode's word moves, the rail's reorder and quick look's seek.
  - `TestDefaultHelpKeysAreBoundInNoOtherTable` finds 14 collisions, the GUI client's alt+shift+up/down among them.
- `TestIdleCostStaysLow`: pass, with renders=0 at idle.
- Size, release build (`just size`):
  - linux/amd64: +106,496 bytes (49,483,936 → 49,590,432), 909,568 under the new ceiling.
  - windows/amd64: +107,008 bytes (49,915,904 → 50,022,912). Main had only 84,096 bytes of room there, so this PR's first commit raises the ceiling from 50,000,000 to 50,500,000 bytes, with its reason in `docs/perf.md`. That leaves 477,088 bytes on windows/amd64 after this PR. About 57 KB of the growth is code, mostly drawing and walking the explainer, and 35 KB its function table. Moving the page text into a static table saved nothing, so the series fits under the old ceiling only by dropping features. The raise is the maintainer's call; it is a commit of its own so it can be dropped or changed.

## Since the review

Gaurav reviewed the stack on #2448 (2026-11-25). Two of his three points are fixed in this PR:

- The CPU and RAM readouts were each measured with the segment's two-column margin, so the first two columns of the RAM readout explained the CPU. They are now measured without it. `TestHoverHelpExplainsEachMeter` covers this, and it fails when the margin is put back.
- The shifted arrows shadowed terminal scroll, copy mode's word moves and the rail's reorder keys. The defaults are now ctrl+alt keys that no other table binds, and the two tests above check this.

The third point, stacking order, is fixed in #2446, which adds the panes.

## Merge Danger

**Door:** two-way. It is new code behind a new key. Ctrl+b h is a yielding default: a config that already binds h after the prefix keeps its own action. The screen preset keeps `h` for its screenshot and offers hover help on its tuios prefix.

**Blast Radius:** keybindings, binary size.

- The size ceiling goes up by 500,000 bytes for every target, in commit `chore: raise the binary size ceiling to 50.5 MB`.

- The help keys (ctrl+alt+arrows, ctrl+alt+pgup/pgdown, alt+shift+h) are read only while hover help is on. The rest of the time they reach the pane as before.
- The dock now records the position of each named cell as it draws.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
