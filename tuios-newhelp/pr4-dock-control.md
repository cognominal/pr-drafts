Stacked on #T3 (feat/newhelp-3-leader). Review that first.

## Summary

A new dock component, `help`, draws a `?` control. It is in no default list.

```diff
 [dock]
-left = ["mode", "workspaces", "trail", "tape"]
+left = ["mode", "workspaces", "trail", "tape", "help"]
```

```text
click on ?        → ToggleHoverHelp (same as Ctrl+b h)
hover help on     → ? on the accent ground (reverse video at 16 colours)
hover help + ?    → page "Dock › Help control"
```

Files: `internal/config/dock.go` (`DockComponentHelp`), `internal/app/dock_components.go` (`dockHelpCell`), `internal/input/mouse_click.go` (the click), `internal/app/hover_help.go` (its page), the docs (CONFIGURATION.md, KEYBINDINGS.md), and the regenerated `docs/config-options.md` and `docs/look-keys.json`.

## Evidence

New e2e test `TestHoverHelpDockControl`:

```
default config            → no lone ? on the dock row
[dock] left = [..., "help"]
click ?                   → explainer up, the ? cell's ground or reverse changed
hover ?                   → "Dock › Help control", "turns hover help on or off"
click ? again             → explainer gone
```

- **Before** (T3 build): fails at "the ? control on the dock".
- **After:** passes, with the other 10 hover help tests, on the real and sim backends.

```text
 Help control
 Dock › Help control
 window mode

 The ? control. A click turns hover help on or off, and it
 is lit while hover help is on. It is in no default list; a
 [dock] list that names "help" draws it.

 Keys
 Ctrl+b h  Explain the part of the screen under the
           pointer, or stop
```

Also checked:

- `just check --changed`: all checks pass.
- The unit tests of config, app, input and cmd/tuios pass.
- `TestIdleCostStaysLow`: pass.
- Size against T3: linux/amd64 +0 bytes, darwin/arm64 +16,512 bytes, windows/amd64 +2,560 bytes (50,051,584, 448,416 under the 50,500,000 ceiling).

## Merge Danger

**Door:** two-way. A config that names `help` would warn about an unknown component after a revert.

**Blast Radius:** none for the default dock.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
