#!/usr/bin/env bash

#
#  Copyright © 2026 SHBFN. All rights reserved.
#  See LICENSE in the project root for full details.
#

# Tests for the pure functions in .github/scripts/swift-bump.sh.
#
# Usage: ./.github/scripts/swift-bump-test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0

# shellcheck source=.github/scripts/swift-bump.sh
source "$ROOT/.github/scripts/swift-bump.sh"
set +e

expect() {
  if [[ "$2" == "$3" ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1: expected '$2', got '$3'"
    failures=$((failures + 1))
  fi
}

expect "latest: numeric order" "6.10.0" "$(printf '6.4.2\n6.10.0\n6.9.1\n' | sb_latest_release)"
expect "latest: snapshots and names ignored" "6.4.2" "$(printf '6.4.2\n6.5-DEVELOPMENT-SNAPSHOT\nmain\n' | sb_latest_release)"
expect "latest: no versions" "" "$(printf '' | sb_latest_release)"

sb_version_gt 6.5.0 6.4.2; expect "gt: newer minor" 0 $?
sb_version_gt 6.4.2 6.4.2; expect "gt: equal" 1 $?
sb_version_gt 6.4.1 6.4.2; expect "gt: older" 1 $?

expect "title: bump PR" "6.5.0" "$(sb_version_from_title "${SB_TITLE_PREFIX}6.5.0")"
expect "title: other PR" "" "$(sb_version_from_title "Support structs")"

expect "decide: current" up-to-date "$(sb_decide 6.4.2 6.4.2 "")"
expect "decide: lookup failed" up-to-date "$(sb_decide 6.4.2 "" "")"
expect "decide: new, no PR" open "$(sb_decide 6.4.2 6.5.0 "")"
expect "decide: PR has it" already-tried "$(sb_decide 6.4.2 6.5.0 6.5.0)"
expect "decide: PR is older" rewrite "$(sb_decide 6.4.2 6.5.1 6.5.0)"

expect "syntax: 6.4.2" 604 "$(sb_syntax_major 6.4.2)"
expect "syntax: 6.10.0" 610 "$(sb_syntax_major 6.10.0)"
expect "syntax: 7.0.0" 700 "$(sb_syntax_major 7.0.0)"

ci="$WORK/ci.yml"
printf '      - uses: SwiftyLab/setup-swift@v1\n        with:\n          swift-version: "6.4.2"\n' > "$ci"
expect "ci: pinned read" 6.4.2 "$(sb_pinned_swift "$ci")"
sb_set_ci_swift "$ci" 6.5.0
expect "ci: pinned set" 6.5.0 "$(sb_pinned_swift "$ci")"
expect "ci: indent kept" 1 "$(grep -c '^          swift-version: "6.5.0"$' "$ci")"

manifest="$WORK/Package.swift"
printf '        .package(url: "https://github.com/swiftlang/swift-syntax.git", "604.0.0"..<"700.0.0"),\n' > "$manifest"
sb_set_syntax_floor "$manifest" 605
expect "floor: raised, upper bound kept" 1 "$(grep -c '"605.0.0"..<"700.0.0"' "$manifest")"
expect "floor: no backup files" 0 "$(find "$WORK" -name '*.bak' | wc -l | tr -d ' ')"

if [[ $failures -gt 0 ]]; then
  echo "$failures test(s) failed."
  exit 1
fi
echo "All tests passed."
