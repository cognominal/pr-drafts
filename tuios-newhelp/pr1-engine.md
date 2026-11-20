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
| `help_next` / `help_prev` | shift+right / shift+left |
| `help_deeper` / `help_shallower` | shift+down / shift+up |
| `help_scroll_up` / `help_scroll_down` | shift+pgup, alt+shift+up / shift+pgdown, alt+shift+down |
| `help_keys` | alt+shift+h |

Hover help is a view, not a mode: every other key reaches the pane. `?` still opens the key list. This part covers the dock, each dock cell, and the desktop. The rail, panes and the leader menu come in parts 2 and 3.

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
 Shift+←/Shift+→ components · Shift+↑/Shift+↓ parts         ───────────────────────────────────────────────────────────╯
 Alt+Shift+h keys · Ctrl+b h close                          ────────────────────────────────────────────────────────────
  V   1   +  1:1                                                                                              
```

## Evidence

`e2e/tui/hover_help_test.go`, 7 tests, each saves its screens as artifacts:

- **Before** (main 4c12ece99): all 7 fail at their first wait for the explainer.
- **After:** all 7 pass on the `real` and `sim` backends.
  - toggles twice
  - explains the dock cell under the pointer
  - walks with the shift arrows, and alt+shift+h shows all keys
  - leaves typing to the pane
  - passes plain keys through: `cat -v` gets Up, Down and h, and no shift arrow
  - the footer shows a rebound key
  - lets a click through: the dock's `+` makes workspace 2

Also checked:

- `just check --changed`: all checks pass.
- `go test` on internal/config, internal/input, internal/app and cmd/tuios: pass.
- `TestIdleCostStaysLow`: pass, with renders=0 at idle.
- Size, release build (`just size`):
  - linux/amd64: +106,496 bytes (49,483,936 → 49,590,432), 409,568 under the ceiling.
  - windows/amd64: +107,008 bytes (49,915,904 → 50,022,912). Main had only 84,096 bytes of room there, so this PR's first commit raises the ceiling from 50,000,000 to 50,500,000 bytes, with its reason in `docs/perf.md`. That leaves 477,088 bytes on windows/amd64 after this PR. About 57 KB of the growth is code, mostly drawing and walking the explainer, and 35 KB its function table. Moving the page text into a static table saved nothing, so the series fits under the old ceiling only by dropping features. The raise is the maintainer's call; it is a commit of its own so it can be dropped or changed.

## Merge Danger

**Door:** two-way. It is new code behind a new key. Ctrl+b h is a yielding default: a config that already binds h after the prefix keeps its own action. The screen preset keeps `h` for its screenshot and offers hover help on its tuios prefix.

**Blast Radius:** keybindings, binary size.

- The size ceiling goes up by 500,000 bytes for every target, in commit `chore: raise the binary size ceiling to 50.5 MB`.

- The help keys (shift+arrows, alt+shift+h …) are read only while hover help is on. The rest of the time they reach the pane as before.
- The dock now records the position of each named cell as it draws.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
