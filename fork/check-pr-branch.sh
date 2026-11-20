#!/bin/sh
# Refuse to call the current branch PR-ready if it carries anything that must
# stay in this fork: agent files, fork docs, or history from our main branch.
# Usage: fork/check-pr-branch.sh [base]   (base defaults to upstream/master)
set -eu

base=${1:-upstream/master}
fail=0

git rev-parse --verify --quiet "$base" >/dev/null || {
	echo "error: $base not found; run: git fetch upstream" >&2
	exit 2
}

# Fork-only paths. Keep in sync with the list in FORK.md.
forkonly='^(AGENTS\.md|CLAUDE\.md|FORK\.md|\.claude/|\.agents/|fork/|REVIEW\.md)'

files=$(git diff --name-only "$base...HEAD")
bad=$(printf '%s\n' "$files" | grep -E "$forkonly" || true)
if [ -n "$bad" ]; then
	echo "FAIL: branch touches fork-only paths:" >&2
	printf '  %s\n' $bad >&2
	fail=1
fi

# A merge commit here almost always means main (or upstream) was merged in,
# which drags fork-only history into the PR.
merges=$(git rev-list --merges "$base..HEAD")
if [ -n "$merges" ]; then
	echo "FAIL: branch contains merge commits; rebase onto $base instead:" >&2
	git log --oneline --merges "$base..HEAD" >&2
	fail=1
fi

# Any commit that also exists on our main but not upstream is fork history.
if git rev-parse --verify --quiet origin/main >/dev/null; then
	leaked=$(git rev-list "$base..HEAD" | while read -r c; do
		if git merge-base --is-ancestor "$c" origin/main; then echo "$c"; fi
	done)
	if [ -n "$leaked" ]; then
		echo "FAIL: branch contains commits from origin/main:" >&2
		for c in $leaked; do git log -1 --oneline "$c" >&2; done
		fail=1
	fi
fi

[ "$fail" -eq 0 ] || exit 1

echo "OK: $(git rev-list --count "$base..HEAD") commit(s) on top of $base:"
git log --oneline "$base..HEAD"
echo
git diff --stat "$base...HEAD"
