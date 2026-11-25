# Tiny test helpers for the bash tests.
# shellcheck shell=bash
# shellcheck disable=SC2034  # used by the tests that source this
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fails=0 passes=0
ok() { passes=$((passes + 1)); }
fail() { fails=$((fails + 1)); echo "  FAIL: $*"; }
check() {  # check <description> <command...>
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then ok; else fail "$what"; fi
}
check_not() {
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then fail "$what"; else ok; fi
}
equal() {  # equal <description> <expected> <actual>
  if [[ $2 == "$3" ]]; then ok; else fail "$1: expected [$2], got [$3]"; fi
}
finish() {
  echo "  $passes passed, $fails failed"
  (( fails == 0 ))
}
