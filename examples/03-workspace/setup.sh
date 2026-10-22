#!/usr/bin/env bash
# setup.sh: remove the demo sandboxes, then rebuild .work/sample-repo from ./sample-repo
set -euo pipefail
cd "$(dirname "$0")"

for name in workspace-direct workspace-clone workspace-scratch; do
  sbx rm --force "$name" >/dev/null 2>&1 || true
done
rm -rf .work

mkdir -p .work && cp -R sample-repo .work/sample-repo
cd .work/sample-repo
export GIT_AUTHOR_DATE="2026-10-26T05:30:00-10:00" GIT_COMMITTER_DATE="2026-10-26T05:30:00-10:00"
git init -q -b main
git add -A
git -c user.name=Demo -c user.email=demo@example.invalid commit -qm "Initial commit"
echo "ready: $(pwd)"
