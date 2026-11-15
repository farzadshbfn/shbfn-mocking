#!/usr/bin/env bash

#
#  Copyright © 2026 SHBFN. All rights reserved.
#  See LICENSE in the project root for full details.
#

# Bumps the CI Swift version to the newest swift.org release on one fixed branch, and opens or rewrites one PR.
# A green test run gets auto-merge; a red one makes the PR a draft and exits 1.
# The same version is never tried twice, and a newer release rewrites the open PR, so PRs never pile up.
#
# Usage: swift-bump.sh plan                          prints action, current, latest, pr (also to $GITHUB_OUTPUT)
#        swift-bump.sh apply <version>               edits ci.yml and the swift-syntax floor, then updates Package.resolved
#        swift-bump.sh publish <version> <passed|failed> <log>   commits, pushes, and opens or updates the PR

set -euo pipefail

SB_BRANCH="swift-bump"
SB_TITLE_PREFIX="[Bot]: Bump Swift to "
SB_CI=".github/workflows/ci.yml"
SB_MANIFEST="Package.swift"
SB_RELEASES_URL="https://www.swift.org/api/v1/install/releases.json"
SB_SYNTAX_REMOTE="https://github.com/swiftlang/swift-syntax.git"

# Prints the highest plain X.Y.Z version read from stdin.
sb_latest_release() {
  { grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true; } | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1
}

# Succeeds when version $1 is strictly newer than version $2.
sb_version_gt() {
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sb_latest_release)" == "$1" ]]
}

# Prints the version in a bump PR title, or nothing for any other title.
sb_version_from_title() {
  [[ "$1" == "$SB_TITLE_PREFIX"* ]] && printf '%s\n' "${1#"$SB_TITLE_PREFIX"}"
  return 0
}

# Prints the action for pinned $1, newest release $2, and open bump PR version $3: up-to-date | already-tried | rewrite | open
sb_decide() {
  local current="$1" latest="$2" open_pr="$3"
  if [[ -z "$latest" ]] || ! sb_version_gt "$latest" "$current"; then
    echo up-to-date
  elif [[ "$open_pr" == "$latest" ]]; then
    echo already-tried
  elif [[ -n "$open_pr" ]]; then
    echo rewrite
  else
    echo open
  fi
}

# Prints the swift-syntax major that matches Swift version $1 (6.4.2 -> 604).
sb_syntax_major() {
  local major minor
  IFS=. read -r major minor _ <<<"$1"
  echo $((major * 100 + minor))
}

# Prints the Linux Swift version pinned in ci.yml $1.
sb_pinned_swift() {
  sed -n 's/^ *swift-version: "\([0-9][0-9.]*\)".*/\1/p' "$1" | head -n 1
}

# Sets the pinned Swift version in ci.yml $1 to $2.
sb_set_ci_swift() {
  sed -E -i.bak "s/^( *swift-version: \")[0-9][0-9.]*(\".*)$/\1$2\2/" "$1"
  rm -f "$1.bak"
}

# Sets the lower bound of the swift-syntax range in manifest $1 to $2.0.0; the open upper bound stays.
sb_set_syntax_floor() {
  sed -E -i.bak "s#(swift-syntax\.git\", \")[0-9]+\.[0-9]+\.[0-9]+(\"\.\.<)#\1$2.0.0\2#" "$1"
  rm -f "$1.bak"
}

sb_plan() {
  local current latest pr_json pr_number pr_version action
  current="$(sb_pinned_swift "$SB_CI")"
  latest="$(curl -fsSL --max-time 30 "$SB_RELEASES_URL" | jq -r '.[].name' | sb_latest_release)"
  pr_json="$(gh pr list --head "$SB_BRANCH" --state open --json number,title --jq '.[0] // empty')"
  pr_number="$(jq -r '.number // empty' <<<"${pr_json:-null}")"
  pr_version="$(sb_version_from_title "$(jq -r '.title // empty' <<<"${pr_json:-null}")")"
  action="$(sb_decide "$current" "$latest" "$pr_version")"
  echo "swift-bump: pinned ${current:-none}, newest ${latest:-none}, open PR ${pr_number:-none} (${pr_version:-none}) -> $action"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'action=%s\ncurrent=%s\nlatest=%s\npr=%s\n' "$action" "$current" "$latest" "$pr_number" >> "$GITHUB_OUTPUT"
  fi
}

sb_apply() {
  local version="${1:?usage: swift-bump.sh apply <version>}" syntax
  git checkout -q -B "$SB_BRANCH"
  sb_set_ci_swift "$SB_CI" "$version"
  syntax="$(sb_syntax_major "$version")"
  if git ls-remote --exit-code --tags "$SB_SYNTAX_REMOTE" "refs/tags/$syntax.0.0" >/dev/null; then
    sb_set_syntax_floor "$SB_MANIFEST" "$syntax"
  else
    echo "swift-bump: swift-syntax $syntax.0.0 has no tag yet; the floor stays."
  fi
  swift package update swift-syntax
  git diff --stat
}

sb_publish() {
  local version="${1:?}" result="${2:?}" log="${3:?}" current pr_json pr_number title body
  current="$(git show "origin/main:$SB_CI" | sed -n 's/^ *swift-version: "\([0-9][0-9.]*\)".*/\1/p' | head -n 1)"
  title="$SB_TITLE_PREFIX$version"
  body="Automated bump of the CI Swift from $current to $version by \`.github/scripts/swift-bump.sh\`. Linux tests with Swift $version: $result."
  git add "$SB_CI" "$SB_MANIFEST" Package.resolved
  git commit -q -m "$title" -m "The newest Swift release is $version; CI pinned $current."
  git push -q --force origin "$SB_BRANCH"

  pr_json="$(gh pr list --head "$SB_BRANCH" --state open --json number --jq '.[0] // empty')"
  pr_number="$(jq -r '.number // empty' <<<"${pr_json:-null}")"
  if [[ -n "$pr_number" ]]; then
    gh pr edit "$pr_number" --title "$title" --body "$body" >/dev/null
  else
    pr_number="$(gh pr create --base main --head "$SB_BRANCH" --title "$title" --body "$body" | grep -oE '[0-9]+$')"
  fi

  if [[ "$result" == passed ]]; then
    gh pr ready "$pr_number" >/dev/null 2>&1 || true
    gh pr merge "$pr_number" --auto --squash
    echo "swift-bump: PR #$pr_number will merge when its checks pass."
  else
    gh pr ready "$pr_number" --undo >/dev/null 2>&1 || true
    { echo "The tests failed on Linux with Swift $version. New attempts wait for a newer release."; echo; echo '```'; tail -n 60 "$log"; echo '```'; } > "$log.comment"
    gh pr comment "$pr_number" --body-file "$log.comment" >/dev/null
    echo "swift-bump: PR #$pr_number is a draft; the tests failed." >&2
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  cd "$(git rev-parse --show-toplevel)"
  case "${1:-}" in
    plan) sb_plan ;;
    apply) shift; sb_apply "$@" ;;
    publish) shift; sb_publish "$@" ;;
    *) sed -n 's/^# Usage: /Usage: /p; s/^#        /       /p' "$0" >&2; exit 2 ;;
  esac
fi
