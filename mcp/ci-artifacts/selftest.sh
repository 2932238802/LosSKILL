#!/usr/bin/env bash
# ci-artifacts MCP selftest: unit tests + stdio protocol smoke test.
# Offline: no CI tokens or network needed.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
  py="python3"
elif command -v py >/dev/null 2>&1 && py -3 -c 'import sys' >/dev/null 2>&1; then
  py="py -3"
else
  echo "Error: no working python3 or py launcher" >&2
  exit 2
fi

cd "$here" || exit 2
# shellcheck disable=SC2086
$py -E -s -m unittest discover -s tests -t . -v
