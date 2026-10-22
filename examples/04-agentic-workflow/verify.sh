#!/usr/bin/env bash
# verify.sh: the success criteria for the task in AGENTS.local.md.
#   Exit 0 = done. Anything else = the attempt failed; what this prints is
#   shown to the agent on its next attempt.
#
# ./run.sh runs this inside the sandbox, from the agent's work folder, after
# every attempt. The sandbox mounts this file read-only: the agent can read it,
# but can't change what counts as success.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1   # don't leave __pycache__/ in the agent's work folder

[[ -f slugify.py ]] || { echo "slugify.py not found"; exit 1; }

python3 - <<'PY'
from slugify import slugify

cases = {
    "Hello, World!": "hello-world",
    "  Agents in a Box  ": "agents-in-a-box",
    "Café déjà vu": "cafe-deja-vu",
    "a--b__c": "a-b-c",
    "2026: the year of AI": "2026-the-year-of-ai",
    "": "",
}
failed = 0
for text, want in cases.items():
    got = slugify(text)
    if got != want:
        print(f"slugify({text!r}) returned {got!r}, expected {want!r}")
        failed += 1
print(f"{len(cases) - failed}/{len(cases)} checks passed")
raise SystemExit(1 if failed else 0)
PY
