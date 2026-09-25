#!/usr/bin/env bash
# Summarize the current branch's changes relative to a base branch, as Markdown.
# Usage: collect_changes.sh [base-ref]   (defaults to main, then master)
set -euo pipefail

base="${1:-}"
if [[ -z "$base" ]]; then
  for candidate in main master; do
    if git rev-parse --verify -q "$candidate" >/dev/null; then base="$candidate"; break; fi
  done
fi
if [[ -z "$base" ]]; then
  echo "error: no base ref given and neither main nor master exists" >&2
  exit 2
fi

if ! git rev-parse --verify -q "$base" >/dev/null; then
  echo "error: base ref '$base' does not exist" >&2
  exit 2
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
merge_base="$(git merge-base "$base" HEAD)"
count="$(git rev-list --count "$merge_base"..HEAD)"

echo "# Change summary: ${branch}"
echo
echo "- Base: \`${base}\` (merge-base \`$(git rev-parse --short "$merge_base")\`)"
echo "- Head: \`$(git rev-parse --short HEAD)\`"
echo "- Commits: ${count}"
if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  echo "- Upstream: \`${upstream}\` ($(git rev-list --count "$upstream"..HEAD) commits not pushed)"
else
  echo "- Upstream: none (not pushed)"
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo
  echo "> WARNING: the working tree has uncommitted changes; they are not included below."
fi
echo
echo "## Overall diffstat"
echo
echo '```'
git diff --stat "$merge_base"..HEAD
echo '```'
echo
echo "## Commits (oldest first)"
git log --reverse --format='%n### `%h` %s%n%n%b' --stat "$merge_base"..HEAD | cat -s
