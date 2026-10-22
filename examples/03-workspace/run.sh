#!/usr/bin/env bash
# run.sh: run the workspace demo
#   ./run.sh direct    stand-in agent works directly on your files
#   ./run.sh clone     stand-in agent works in its own clone
#   add --execute      also run the notebook's cells, so outputs are saved before committing
set -euo pipefail
cd "$(dirname "$0")"

AGENT=shell    # plain Bash sandbox: no AI agent installed, nothing to upgrade
REPO="$PWD/.work/sample-repo"

case "${1:-}" in
  direct) NAME=workspace-direct; CLONE_FLAG="" ;;
  clone)  NAME=workspace-clone;  CLONE_FLAG="--clone" ;;
  *) echo "usage: $0 direct|clone [--execute]" >&2; exit 1 ;;
esac
MODE="$1"

case "${2:-}" in
  "")        EXECUTE="" ;;
  --execute) EXECUTE="--execute" ;;
  *) echo "usage: $0 direct|clone [--execute]" >&2; exit 1 ;;
esac

[[ -d "$REPO/.git" ]] || { echo "No repo yet. Run ./setup.sh first." >&2; exit 1; }

step() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# Start the sandbox in the background. It keeps running after this script
# ends, which clone mode needs for `git fetch` to work.
if ! sbx ls 2>/dev/null | grep -qw "$NAME"; then
  sbx run -d $CLONE_FLAG --name "$NAME" "$AGENT" "$REPO"
fi

step "Inside the sandbox ($MODE mode): the agent does what task.md asks"
sbx exec "$NAME" bash -c "$(cat stand-in-agent.sh)" stand-in-agent.sh $EXECUTE

step "On your machine: git status"
git -C "$REPO" status --short --branch

if [[ "$MODE" == clone ]]; then
  step "Your repo is unchanged. To review the agent's work:"
  cat <<EOF
  cd .work/sample-repo
  git fetch sandbox-$NAME
  git log --oneline main..sandbox-$NAME/add-sales-viz
  git diff --stat  main..sandbox-$NAME/add-sales-viz
EOF
fi
