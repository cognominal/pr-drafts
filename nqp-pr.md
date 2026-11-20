# Write bytecode files to a temporary file and rename it into place

Branch: `atomic-mbc-write` in ~/git/cognominal---nqp (on upstream/main 5397dd7da)

## Summary

```diff
 MoarVM::BytecodeWriter.assemble_to_file($filename)
-  open $filename, 'w'                 # truncates the live file
+  open "$filename.tmp-$pid", 'w'
   write sections, seek back, write header
   close
+  rename "$filename.tmp-$pid" → $filename
```

MoarVM mmaps the bytecode files it loads. Rebuilding Rakudo while a program still runs from `blib/CORE.c.setting.moarvm` truncated and rewrote that file in place. The running program then lost its mapped pages and died of SIGBUS when the file shrank, or ran on mixed old/new bytecode when it didn't, which can end in any error up to a SIGSEGV. After a rename it keeps the old inode until it exits, and no reader ever sees a half-written file.

## Evidence

- **Before:** two SIGBUS core dumps, both faulting at offset 31664594 of a mapped `CORE.c.setting.moarvm` that had since been rebuilt (mapped size 34627584, new file 34838880).
  **After:** recompiling over an existing `.moarvm` gives it a new inode (51183 → 51184), leaves no `.tmp-*` file behind, and the output runs correctly.
- **Before:** a process blocked inside a sub loaded from `M.moarvm`, while `M.moarvm` is recompiled from a different source, fails 3/3 when it resumes (`is_cclass requires a concrete string, but got a type object`, or `Attempt to read past end of string heap`): it runs the new file's bytes with the old file's frame metadata.
  **After:** the same script, with the patched NQP doing the recompile, finishes normally 3/3 on the old code.
- `make test`: All tests successful (150 files, 13746 tests).

## Merge Danger

**Door:** two-way

**Blast Radius:** small. Every `--target=mbc --output` compile, including the NQP and Rakudo builds. The output directory must allow creating a file, which it already had to for a first build. A compile that dies part-way leaves a `.tmp-<pid>` file instead of a truncated target.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
