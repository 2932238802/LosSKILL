#!/usr/bin/env bash
# Launch the ci-artifacts MCP server with whichever Python actually works.
# `python3` may be the broken Windows Store shim, so probe before using it.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
  exec python3 -E -s "$here/server.py" "$@"
elif command -v py >/dev/null 2>&1 && py -3 -c 'import sys' >/dev/null 2>&1; then
  exec py -3 -E -s "$here/server.py" "$@"
else
  echo "ci-artifacts MCP: no working python3 or py launcher found" >&2
  exit 1
fi
