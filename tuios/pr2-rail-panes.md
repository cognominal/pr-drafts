Stacked on #2445 (feat/newhelp-1-engine). Review that first.

## Summary

Hover help now explains the rail and the panes. Each is a **component**, and its sections or its title bar and body are its **parts**.

```diff
 buildHelpComponents
   helpDockComponents        # dock, then a part per cell
+  helpRailComponents        # rail, then a part per section the frame drew
+    rail/sessions · rail/terminals · rail/agents · rail/files · rail/git · …
+  helpPaneComponents        # per visible pane of this workspace
+    pane:ID
+      pane:ID/title         # only when the pane draws a title bar
+      pane:ID/body
   helpDesktopComponent      # last, the whole screen
```

- A section's key list holds the keys that act while the rail has the keyboard (Ctrl+b e), with the rail's own descriptions.
- A hidden rail keeps a page with no rectangle, so shift+→ still reaches it and the page names Ctrl+b b.
- A pane's rectangles follow the pane's own geometry, its title position (top, bottom or hidden) and the cropped session view.
- A part's explainer first looks for a place that keeps off the whole component, then one that keeps off the part alone. Beside a short target it is clamped into the rows it may use, so a rail section's explainer goes beside the rail instead of over the rest of it.
- The CLI lines only name commands that exist: `focus-window`, `set-window --name`, `capture-pane -w`, `split-window`, `set-layout`, `close-window`. A pane name is shell-quoted.

New file: `internal/app/hover_help_parts.go`.

## Evidence

- **Before** (on T1): the pane and rail tests fail at their first page.
  ```
  TestHoverHelpExplainsAPaneAndItsParts   FAIL  waiting for the body's page
  TestHoverHelpExplainsTheRailSections    FAIL  waiting for shift+right reaches the rail
  ```
- **After:** all 9 hover help e2e tests pass on the real and sim backends.
  ```
  pane test:  hover body   → "Pane: Terminal … › Terminal: …"
              hover title  → "› Title bar: …"
              shift+↓ / shift+↑ walk title ↔ body, shift+↑ again → "Pane: … (2 parts)"
  rail test:  shift+→ from the dock → "Rail (…)"
              shift+↓ shift+↓ → "Rail › Sessions", "Rail › Terminals", shift+↑ ×2 → "Rail ("
              hover the sessions header → "Rail › Sessions"
              each section's explainer starts right of the rail's edge
  ```
  Each step saves its frame, plain and styled, under `artifactDir`.

```text
 Terminals
 Rail › Terminals
 window mode

 The panes of the session the rail follows. Enter focuses
 one, r renames it, and the + in the header opens another.

 Keys
 ↵  Activate the row: attach, or focus the pane
 t  New terminal, the terminals header's +
 r  Rename the window under the cursor
 …
```

Also checked:

- `just check --changed`: all checks pass.
- `go test` on internal/app, internal/config, internal/input and cmd/tuios: pass.
- `TestIdleCostStaysLow`: pass, with renders=0 at idle.
- Size against T1 (`just size`): linux/amd64 +24,576 bytes (49,615,008). windows/amd64 +27,648 bytes (50,050,560), 449,440 under the 50,500,000 ceiling T1 sets.

## Merge Danger

**Door:** two-way. Only hover help reads the new code.

**Blast Radius:** none outside hover help.

- The two T1 walk tests reach the desktop with shift+← now, because the rail and the panes sit between the dock and the desktop.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
