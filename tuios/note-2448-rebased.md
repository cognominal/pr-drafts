The four PRs are now rebased onto current main (3fd531be4) and marked ready for review.

With the rebase, the stack no longer needs a higher size ceiling. Main now has 151,168 bytes of room on windows/amd64, and the whole stack takes 137,216 of them (49,986,048 bytes at the head). So I dropped the commit that raised the ceiling to 50.5 MB. #2445 is now a single commit.

The hover help e2e tests pass on each branch, on the real and sim backends. `just check --changed` and `just size` pass at the head.
