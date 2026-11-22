# Relay browser tests fail wherever Chromium can launch, since the native-host refactor

## What happens

On a Linux machine with a working Chromium, two relay test files fail on `main` (`e1a9f4b41d`):

```
packages/coding-agent$ bun test test/tools/browser-relay-tab-isolation.test.ts
 1 pass
 12 fail
error: net::ERR_FILE_NOT_FOUND at chrome-extension://<id>/options.html
      at launchBrowser (test/tools/browser-relay-tab-isolation.test.ts:201:16)

packages/coding-agent$ bun test test/tools/browser-background-input.test.ts
 1 pass
 3 fail
Expected: "ready"
Received: "no-extension"
      at withRelay (test/tools/browser-background-input.test.ts:136)
```

Rebuilding the extension (`bun run gen:relay-extension`) changes nothing.

## Why

**`browser-relay-tab-isolation`:** f2b60070e0 ("served the relay from the extension's native host", 2026-11-20) deleted `extension/options.html` and `options.js`. `launchBrowser` still waits for the extension to register by opening `chrome-extension://<id>/options.html`. The extension that `writeRelayExtension` writes now has `panel.html` and `offscreen.html` but no `options.html`, so every `goto` fails with `ERR_FILE_NOT_FOUND` instead of the `ERR_BLOCKED_BY_CLIENT` the loop retries on. `test/tools/browser-relay-foreign-frames.test.ts:130` still names `options.html` too.

**`browser-background-input`:** `waitForRelayExtension` returns `"no-extension"`: the test's relay answers 503 for the whole hello window, so the extension never says hello to it. The extension loads (its ID matches `unpackedExtensionId`). My guess, not confirmed: the test points the extension at its relay by prepending `chrome.storage.local.set({ port })` to `background.js`, and since the same refactor the extension no longer dials a relay port from storage.

## Why CI stays green

Both files use `describe.skipIf(!CHROMIUM_AVAILABLE)`. CI on `e1a9f4b41d` is green, so I assume its runners skip them. They only fail where Chromium can actually launch.

## Environment

- Arch Linux, Hyprland, system Chromium 157.0.8103.79 (picked by `ensureChromiumExecutable`)
- oh-my-pi `main` at `e1a9f4b41d`, bun test run from `packages/coding-agent`

Found while running the full `bun run test` for a TUI PR; the same failures appear with and without that change.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
