#!/bin/sh
set -eu

executable=$1
expected_version=$2

if [ "${DRAUGHT_STANDALONE_SMOKE:-0}" = "1" ]; then
  if command -v erl >/dev/null 2>&1 || command -v elixir >/dev/null 2>&1; then
    echo "Standalone smoke PATH contains a system BEAM." >&2
    exit 1
  fi
fi

case "$executable" in
  /*) ;;
  *) echo "The smoke executable must use an absolute path." >&2; exit 1 ;;
esac

version=$("$executable" --version)
test "$version" = "draught $expected_version"
test "$("$executable" --version)" = "$version"

help=$("$executable" --help)
case "$help" in
  *--model*--session*) ;;
  *) echo "CLI help is missing supported options." >&2; exit 1 ;;
esac

status=0
"$executable" --unsupported-smoke-option >/dev/null 2>&1 || status=$?
test "$status" -eq 2

status=0
report=$("$executable" doctor --base-url http://127.0.0.1:1 --output jsonl) || status=$?
test "$status" -eq 3
case "$report" in
  *'"status":"error"'*) ;;
  *) echo "Unavailable-provider diagnostics are missing." >&2; exit 1 ;;
esac

echo "CLI smoke passed."
