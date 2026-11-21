# Closing a Proc's `.out` early buffers the rest of the output without limit

## The problem

```raku
my $p = run 'yes', :out;
$p.out.get;
$p.out.close;      # never returns, memory grows until the OOM killer steps in
```

`.out.close` waits for the process to exit, but `yes` never exits. In a shell, closing the read end of the pipe would kill `yes` with SIGPIPE. Rakudo keeps the pipe open and keeps reading, and stores every chunk it reads. Memory grows at roughly the speed `yes` writes. On a desktop machine with 16 GB of RAM and 32 GB of swap, memory use reached about 45 GB (15.7 GB RAM plus 29.5 GB swap) before systemd-oomd killed the whole terminal session, not just the Raku process.

A producer that does stop shows the same buffering, just with a ceiling. Here the output is read all the way to the end even though nothing will ever read it:

```raku
my $p = run 'sh', '-c', 'yes | head -c 1000000000', :out;
$p.out.get;
$p.out.close;
```

Peak memory with Rakudo 2026.08 (Rakudo Star):

| Output discarded after `close` | Peak memory |
|---|---|
| 300 MB | 0.8 GB |
| 1 GB | 1.4 GB |

To reproduce safely, cap the process:
`systemd-run --user --wait --pipe -p MemoryMax=2G -p MemorySwapMax=0 raku close-out.raku`

## Where the output piles up

```text
yes ──pipe──▶ MoarVM event loop
                reads whenever the pipe has data (permits: -1)
                queues each chunk for the thread pool        ← (1) no limit
              Proc::Async stdout Supply
              Proc: $stdout-supply.Channel                   ← (2) no limit
              $p.out.get / .lines / .slurp
```

1. **MoarVM's read queue.** MoarVM has backpressure. A spawned process's stdout is only read while it has permits, and reading stops at zero (`spawn_permit` / `async_read` in `src/io/procops.c`). `Proc::Async` grants `-1` (unlimited) as soon as the stdout supply is tapped (`nqp::permit($!process_handle, channel, -1)` in `src/core.c/Proc/Async.rakumod`). So MoarVM reads as fast as the producer writes, and if Raku code handles chunks more slowly, they queue up without limit.
2. **Proc's Channel.** `Proc` feeds stdout and stderr into a `Channel`, which has no limit either. On `close`, if nothing was read yet, it even creates that Channel (`$chan //= $stdout-supply.Channel; # If we never read`). After `close` nothing will ever read it, but it keeps filling until the process exits.

Fixing (2) alone isn't enough. Discarding output once the pipe is closed lowered the 1 GB case from 1.4 GB to 0.9 GB. With `yes` it only delayed reaching a 1.5 GB cap from 1.6 s to about 7 s. The queue in (1) still grows, because MoarVM reads faster than one thread can take chunks off the queue.

## Possible fixes

Any real fix starts by having `Proc` grant permits as output is consumed rather than `-1`. Then only a few chunks are ever buffered, and a slow reader slows the producer down the way a plain pipe would. What `.out.close` does with a producer that is still writing is the open question:

| | On `.out.close` | Downside |
|---|---|---|
| **A. Stop reading** (grant no more permits) | Memory stays bounded | The producer blocks on a full pipe, and `close`, which waits for exit, hangs forever |
| **B. Close the read end** | The producer gets SIGPIPE and exits, as in a shell or Perl | A behaviour change: a process that writes after its `.out` was closed is killed, and its exit status reports signal 13 rather than its own exit code |
| **C. Keep reading and discard** | Same as today, but without storing anything | The producer never exits, so `close` hangs forever and burns CPU; and today's unlimited queue (1) doesn't bound memory anyway |

B is what users coming from a shell or Perl expect, and the only option where `close` returns for a producer like `yes`. It needs a MoarVM operation to close one output pipe of a running process, which doesn't exist today. The same question applies to `.err`, and to `:merge` where both streams share one pipe.

Until then, the safe pattern for a producer that may not stop is to kill it rather than close its `.out`:

```raku
my $proc = Proc::Async.new('yes');
my $lines = $proc.stdout.lines;     # tap before .start, or yes inherits our stdout
my $done = $proc.start;
react whenever $lines { .say; done }
$proc.kill(SIGPIPE);
my $ = await $done;
```

This prints one `y`, returns, and peaks at 166 MB.

## Environment

- Rakudo 2026.08 (Rakudo Star) on MoarVM 2026.08; same `Proc` code on rakudo main 4b0d5f46f1
- Linux 7.2, x86_64

## Context

Found while investigating MoarVM crashes I hit while working on [rak](https://github.com/cognominal/rak/tree/rak), a shell mode for Raku. The whole investigation, with the related PRs and issue: [pr-drafts](https://github.com/cognominal/pr-drafts#moarvm-crash-investigation-issues-and-prs).
