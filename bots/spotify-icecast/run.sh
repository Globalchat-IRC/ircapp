#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [[ -f config.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source config.env
  set +a
fi

CMD="${1:-run}"
shift || true
exec python3 "$DIR/spotify_icecast.py" "$CMD" "$@"
