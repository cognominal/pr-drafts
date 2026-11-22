# [tui] The OSC 133 marks on a user message leave the command empty, so terminals that list commands find none

### Description

`UserMessageComponent.render()` (`packages/tui/src/chat/user-message.ts`) wraps each user message like this:

```
ESC]133;A BEL <first row of the bubble>
              <the message>
              <last row of the bubble> ESC]133;B ESC]133;C ESC]133;D;0 BEL
```

`A` opens the bubble, and `B`, `C` and `D;0` all sit together at the end of its last row. In OSC 133, `A`..`B` is the prompt, `B`..`C` is the command the person typed, and `C`..`D` is its output. Here the message lands in the prompt, and the command and the output are both empty.

That shape fixed the caret bug (#8030, #6115), and it serves a terminal that only jumps from prompt to prompt. A terminal that reads the command between `B` and `C` gets nothing. In [tuios](https://github.com/Gaurav-Gosain/tuios), the scrollback browser (`<leader> s`) builds its list from those spans. It skips a prompt with an empty command, so an omp pane shows no entries at all. The same happens wherever a terminal shows, copies or searches "the last command".

### Steps to Reproduce

1. Run omp under `script -q -f omp.raw -c omp`.
2. Send two short prompts, such as `reply with the single word pong` and `and now say ping`.
3. Quit, then look at the marks: `grep -ao $'\e]133;[A-D][^\a]*\a' omp.raw | cat -v`.

This is what one bubble looks like (the pane was 50 columns wide):

```
\x1b]133;A\x07\x1b[48;2;15;18;22m                ...
... ngle word pong\x1b[39m   \x1b[49m\x1b[0m\r\r\n
\x1b[48;2;15;18;22m        (50 spaces)        \x1b[49m\x1b]133;B\x07\x1b]133;C\x07\x1b]133;D;0\x07\x1b[0m\r\r\n
```

`B` comes after the bubble's last row, which is blank padding. The text from `B` to `C` is empty. In tuios, open the scrollback browser on that pane with `<leader> s`: it lists no command.

### Expected Behavior

The message is the command: it sits between `B` and `C`. The smallest change that does this moves `B` next to `A` and keeps the zone closed in the same render, so the caret fix holds:

```ts
wrapped[0] = OSC133_ZONE_START + OSC133_ZONE_END + wrapped[0];
wrapped[wrapped.length - 1] += OSC133_COMMAND_START + OSC133_COMMAND_DONE;
```

The prompt is then empty and the command is the message. `C` still follows in the same render, which clears Ghostty's `.input` state as it does today. The cells of the message would now carry the input mark in Ghostty. As far as I can tell, click-to-move only acts while the cursor is at a prompt, and `C` ends that, but someone who knows Ghostty's code should confirm it.

A further step, for terminals that show a command's output: emit `D` after the turn's last output instead of right after `C`, so the reply sits between `C` and `D`. That is a larger change, because the reply is drawn by other components, and repaints write the marks again.

### Error Output

None. The marks are well formed. Only their placement leaves the command empty.

### Platform

Linux

### omp version

19.1.0. `user-message.ts` on `main` places the marks the same way.

### Area

TUI / Display

### Additional context

- **Terminal:** tuios. It reads OSC 133 the way the FinalTerm convention lays it out: command from `B` to `C`, output from `C` to `D`.
- **Related:**
  - #8030 and #6115: the caret bug that the closing `C` and `D` fix.
  - #17145 and #17307: other side effects of the same marks, on OSC 7501.
