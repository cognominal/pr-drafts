Stacked on #2446 (feat/newhelp-2-rail-panes). Review that first.

## Summary

Hover help now stands aside while the leader menu, or one of its menus, waits for a key. It comes back on the same part when the menu closes.

```diff
 renderHoverHelp
-  if !h.on
+  if !h.on || m.MenuOpen()        # the menu has the screen
     return
 HelpHoverAt
-  if !m.hoverHelp.on
+  if !m.hoverHelp.on || m.MenuOpen()   # the pointer under the menu chooses nothing
     return
```

The leader menu already has its "h Hover help" row (from T1), so Ctrl+b then h still toggles hover help from the menu.

## Evidence

New e2e test `TestHoverHelpStandsAsideForTheLeaderMenu`:

```
hover help on            → "Dock (" and the close line
Ctrl+b                   → "Command palette", the close line gone
hover the dock's mode cell under the menu
Esc                      → menu gone, "Dock (" back, and no "Dock › Mode"
```

- **Before** (T2 build): fails at "the explainer under the leader menu". The explainer and the menu are drawn side by side.
- **Before** (T2 + the render gate only, no pointer freeze): fails waiting for "Dock (" after the menu, because the hover under the menu moved the explainer.
- **After:** all 12 hover help e2e tests pass on the real and sim backends.

Also checked:

- `just check --changed`: all checks pass.
- `TestIdleCostStaysLow`: pass, renders=0.
- Size: +0 bytes on linux/amd64, darwin/arm64 and windows/amd64 against T2.

## Merge Danger

**Door:** two-way.

**Blast Radius:** hover help only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
