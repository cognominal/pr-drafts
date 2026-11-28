The four PRs are rebased onto current main (b89f70f10). Only #2445 conflicted: the new Files view and hover help both add actions, a context-only scope and a reachability section on the same lines of `internal/config/actions.go`, `internal/config/registry.go` and `internal/input/reachability_test.go`. I kept both sides.

I also split the seven help strings that used a semicolon into two sentences, each in the commit that adds it: five in #2445, one in #2446 and one in #2448. You have nothing left to edit when you land them.

The hover help e2e tests pass on each branch, on the real and sim backends (8, 11, 12 and 13 tests). The unit tests of `internal/config`, `internal/input` and `internal/app` pass. One of them checks that no help key is bound in another table, and the Files view's tables are now among those it checks. `just check --changed` and `just size` pass at the head. The stack adds 137,216 bytes on windows/amd64, 135,168 on linux/amd64 and 116,384 on darwin/arm64.
