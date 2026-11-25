Thanks for the review. All three points are fixed, and the four branches are force-pushed.

1. **CPU/RAM hits** (#2445): each readout is now measured without the segment's margin. The code was in `renderDockRightCells` in `internal/app/dock_components.go`. `TestHoverHelpExplainsEachMeter` puts CPU and RAM side by side and hovers the first column of `RAM:` and the last column of the CPU graph. It fails when the margin is put back.
2. **Help keys shadowing tuios keys** (#2445): I took the second option. The defaults are now ctrl+alt+arrows to walk, ctrl+alt+pgup/pgdown to scroll, and alt+shift+h for the keys. No other table binds any of them. Two tests cover this:
   - `TestHoverHelpShadowsNoDefaultBinding` reuses the reachability fixtures with hover help on, so a help key that shadows another section's default fails there. It failed 14 subtests on the shifted arrows: terminal scroll, copy mode's word moves, the rail's reorder and quick look's seek.
   - `TestDefaultHelpKeysAreBoundInNoOtherTable` checks the help defaults against every table, the GUI client's included. It also caught `gui_resize`'s alt+shift+up/down.

   `docs/KEYBINDINGS.md` notes that Ghostty on Linux keeps ctrl+alt+arrows for its splits.
3. **Stacking order** (#2446, where the pane parts live): each part now has a layer. The desktop is at the bottom, each pane at `HitZ`+1, and the dock and the rail on top. The pointer takes the highest layer under it, then the smallest part there. `TestHoverHelpExplainsThePaneOnTop` opens a popup larger than the floating pane under it and hovers a cell they share. Without the fix it explains the hidden pane.

The negative controls are recorded in `e2e/tui/NEGATIVE_CONTROLS.md`. The hover help e2e tests pass on the real and sim backends at each branch, and `just check --changed` passes at the head. The fixes add 512 bytes on windows/amd64, which leaves 446,368 under the ceiling.
