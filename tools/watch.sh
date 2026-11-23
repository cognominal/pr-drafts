#!/usr/bin/env bash
# Checks on GitHub the PRs and issues that README.md links, and reports the
# ones that changed since the last run: state, merge, comments, reviews or
# last update. A systemd user timer runs it hourly (tools/systemd/).
#
# Nothing changed: it exits quietly, and no agent runs.
# Something changed: a desktop notice, then a Claude agent in the tuios session
# `pr-drafts` updates README.md per the pr-drafts skill, commits, pushes, and
# leaves a summary in the tuios Inbox.
#
# The snapshot lives in ${XDG_STATE_HOME:-~/.local/state}/pr-drafts/.
# The first run only records it. `watch.sh --dry-run` reports without acting.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
state=${XDG_STATE_HOME:-$HOME/.local/state}/pr-drafts
tuios=${TUIOS:-$HOME/.local/bin/tuios}
dry=${1:-}
mkdir -p "$state"
old=$state/snapshot.tsv
new=$(mktemp) err=$(mktemp)
trap 'rm -f "$new" "$err"' EXIT
# gh's stderr is noise (hints), except when it fails.
gh() { command gh "$@" 2>"$err" || { cat "$err" >&2; return 1; }; }

git -C "$repo" pull -q --ff-only || true

# One line per item: URL, state, merged, comments, reviews, updated.
grep -oE 'https://github.com/[^/ )]+/[^/ )]+/(pull|issues)/[0-9]+' "$repo/README.md" |
  sort -u |
  while read -r url; do
    path=${url#https://github.com/}
    slug=${path%/*/*} n=${url##*/}
    line=$(gh api "repos/$slug/issues/$n" \
      --jq '[.state, (.pull_request.merged_at // "-"), .comments, .updated_at] | @tsv')
    reviews=-
    [[ $url == */pull/* ]] && reviews=$(gh api "repos/$slug/pulls/$n/reviews" --jq length)
    IFS=$'\t' read -r st merged comments updated <<<"$line"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$url" "$st" "$merged" "$comments" "$reviews" "$updated"
  done >"$new"

if [[ ! -s $old ]]; then
  [[ $dry ]] || cp "$new" "$old"
  echo "First run: watching $(wc -l <"$new") items."
  exit 0
fi

# Changed or new items, one line each: "URL: what changed".
changes=$(awk -F'\t' '
  function show(f) { return f[2] (f[3] != "-" ? " merged" : "") ", " f[4] " comments" (f[5] != "-" ? ", " f[5] " reviews" : "") }
  NR == FNR { was[$1] = $0; next }
  !($1 in was) { split($0, n); print $1 ": new, " show(n); next }
  $0 != was[$1] {
    split(was[$1], o); split($0, n)
    a = show(o); b = show(n)
    print $1 ": " (a == b ? "updated (" b ")" : a " -> " b)
  }
' "$old" "$new")

if [[ -z $changes ]]; then
  [[ $dry ]] || cp "$new" "$old"
  exit 0
fi
printf '%s\n' "$changes"
[[ $dry ]] && exit 0

count=$(wc -l <<<"$changes")
notify-send -a pr-drafts "pr-drafts: $count item(s) changed on GitHub" "$changes" || true

prompt="The PRs and issues tracked in pr-drafts changed on GitHub since the last hourly check:

$changes

Follow the pr-drafts skill: look at each one on GitHub (gh), update its entry in README.md (status, what happened), then commit and push. Do not post anything on GitHub. Then tell me in a few lines what changed and what, if anything, I should do, with: tuios ask-human '<summary>' -o ok"

"$tuios" start-agent -s pr-drafts claude --name "watch-$(date +%H%M)" \
  --cwd "$repo" --permission-mode auto --no-wait --prompt "$prompt"

# Recorded only once the agent started, so a failed start is retried next hour.
cp "$new" "$old"
