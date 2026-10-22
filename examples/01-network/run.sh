#!/usr/bin/env bash
# run.sh: the same requests from two sandboxes with different network policies
#   ./run.sh          create both sandboxes and compare
#   ./run.sh clean    remove both sandboxes (and their rules)
set -euo pipefail
cd "$(dirname "$0")"

AGENT=shell    # plain Bash sandbox: no AI agent installed
OPEN=net-default    # your global preset only
TIGHT=net-tight     # global preset + policy.sh

# Each line: a label and a URL. Nothing is executed, only downloaded.
PROBE='
check() {
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$2"); rc=$?
  if [ "$rc" -ne 0 ]; then printf "  %-28s no connection (curl exit %s)\n" "$1" "$rc"
  else                     printf "  %-28s HTTP %s\n" "$1" "$code"; fi
}
check "Python packages (PyPI)"   https://pypi.org/simple/requests/
check "Script on GitHub"         https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore
check "Unknown site"             https://example.com/
'

case "${1:-}" in
  "")
    for NAME in "$OPEN" "$TIGHT"; do
      if ! sbx ls 2>/dev/null | grep -qw "$NAME"; then
        sbx create --name "$NAME" "$AGENT"      # no workspace: nothing from your machine is mounted
      fi
    done
    ./policy.sh "$TIGHT" >/dev/null

    for NAME in "$OPEN" "$TIGHT"; do
      printf '\n\033[1m── %s\033[0m\n' "$NAME"
      sbx exec "$NAME" bash -c "$PROBE"
    done

    printf '\n\033[1m── What the policy log recorded for %s\033[0m\n' "$TIGHT"
    sbx policy log "$TIGHT" --limit 10
    ;;

  clean)
    for NAME in "$OPEN" "$TIGHT"; do
      sbx rm --force "$NAME" >/dev/null 2>&1 || true
    done
    echo "Removed $OPEN and $TIGHT."
    ;;

  *) echo "usage: $0 [clean]" >&2; exit 1 ;;
esac
