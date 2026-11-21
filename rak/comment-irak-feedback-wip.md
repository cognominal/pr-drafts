Work in progress on branch [`irak-feedback`](https://github.com/cognominal/rak/tree/irak-feedback), commits 6cd8eb21d8 (the feature) and 01a1a6dc23 (tracks the Terminal::LineEditor patch it needs).

- **Highlighting works:** the first Enter colors each word as keyword, routine, command, naked string or undeclared; `NO_COLOR` turns it off.
- **The insertion of `my` does not work yet** in the live REPL, though the analysis tests pass (`t/02-rakudo/rak/022-irak-feedback.t`).
- **The highlighting is lost as soon as the line is edited.** That is better than nothing for now.

The line editor needs an `&on-finish` callback, and a timeout on its terminal queries, which Terminal::LineEditor lacks. Until they are proposed upstream, the build patches the pinned 0.0.23 with `tools/build/rak-line-editor-patches/Terminal-LineEditor-0.0.23.patch`.
