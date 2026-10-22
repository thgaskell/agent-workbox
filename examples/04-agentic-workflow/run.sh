#!/usr/bin/env bash
# run.sh: give an agent the task in AGENTS.local.md, and keep going until verify.sh passes
#   ./run.sh                 run the loop in ./work
#   ./run.sh clean           remove the sandbox (keeps work/ and the report)
#
#   AGENT=claude ./run.sh    pick the agent: opencode (default), claude, codex, gemini, copilot, cursor
#   MODEL=groq/qwen/qwen3.8-27b ./run.sh     pick the model (opencode only)
#   MAX_ATTEMPTS=5 ./run.sh                  attempts before the loop gives up (default 3)
#   ATTEMPT_TIMEOUT=15m ./run.sh             time limit for each attempt (default 10m)
set -euo pipefail
cd "$(dirname "$0")"

AGENT="${AGENT:-opencode}"
MODEL="${MODEL:-}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
ATTEMPT_TIMEOUT="${ATTEMPT_TIMEOUT:-10m}"
NAME=agentic-workflow
WORK="$PWD/work"          # the only folder the agent may change
OUT="$PWD/.outputs"       # report templates (read-only) and the report itself
LOGS="$OUT/logs"

step() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# The agent's command for one unattended run: take the prompt, approve
# everything, exit when done. See the table in README.md.
agent_cmd() {
  case "$AGENT" in
    opencode) echo opencode run --auto ${MODEL:+-m "$MODEL"} ;;
    claude)   echo claude --dangerously-skip-permissions -p ;;
    codex)    echo codex exec --dangerously-bypass-approvals-and-sandbox ;;
    gemini)   echo gemini --yolo -p ;;
    copilot)  echo copilot --yolo -p ;;
    cursor)   echo cursor-agent --yolo -p ;;
    *) echo "Unknown AGENT: $AGENT (try opencode, claude, codex, gemini, copilot or cursor)" >&2; exit 1 ;;
  esac
}

# Run the agent once with a prompt, capped by ATTEMPT_TIMEOUT. The cap is
# enforced outside the agent, so a stuck agent can't run forever.
run_agent() {   # run_agent <prompt> <log file>
  # shellcheck disable=SC2046  # agent_cmd's words are meant to split
  sbx exec "$NAME" timeout "$ATTEMPT_TIMEOUT" $(agent_cmd) "$1" </dev/null 2>&1 | tee "$2" || true
}

if [[ "${1:-}" == clean ]]; then
  sbx rm --force "$NAME" >/dev/null 2>&1 || true
  echo "Removed $NAME. work/ and .outputs/REPORT.md are kept; delete them to start fresh."
  exit 0
fi
[[ -z "${1:-}" ]] || { echo "usage: $0 [clean]" >&2; exit 1; }

agent_cmd >/dev/null   # fail early on an unknown AGENT

# Your task stays yours: never commit edits to AGENTS.local.md (see README).
git update-index --skip-worktree AGENTS.local.md 2>/dev/null || true

mkdir -p "$WORK" "$LOGS"
rm -f "$OUT/REPORT.md" "$LOGS"/attempt-*.log

# A fresh sandbox for every run. The agent may write to work/ and .outputs/;
# verify.sh and both templates are mounted read-only, so it can't change
# what counts as success or how it reports.
step "Creating sandbox $NAME ($AGENT)"
sbx rm --force "$NAME" >/dev/null 2>&1 || true
sbx create --name "$NAME" "$AGENT" "$WORK" "$OUT" \
  "$PWD/verify.sh:ro" "$OUT/SUCCESS.md:ro" "$OUT/FAILURE.md:ro" >/dev/null

TASK="$(cat AGENTS.local.md)"
FEEDBACK=""
RESULT=FAILURE
for (( attempt = 1; attempt <= MAX_ATTEMPTS; attempt++ )); do
  step "Attempt $attempt of $MAX_ATTEMPTS: the agent works"
  PROMPT="$TASK

---
Work in the current folder. When you've finished the task, stop."
  if [[ -n "$FEEDBACK" ]]; then
    PROMPT="$PROMPT

Your previous attempt didn't pass the check. It printed:
\`\`\`
$FEEDBACK
\`\`\`
Fix the problem and finish the task."
  fi
  run_agent "$PROMPT" "$LOGS/attempt-$attempt-agent.log"

  step "Attempt $attempt of $MAX_ATTEMPTS: verify.sh"
  if sbx exec "$NAME" bash "$PWD/verify.sh" >"$LOGS/attempt-$attempt-verify.log" 2>&1; then
    cat "$LOGS/attempt-$attempt-verify.log"
    RESULT=SUCCESS
    break
  fi
  cat "$LOGS/attempt-$attempt-verify.log"
  FEEDBACK="$(tail -n 40 "$LOGS/attempt-$attempt-verify.log")"
done
(( attempt > MAX_ATTEMPTS )) && attempt=$MAX_ATTEMPTS

step "$RESULT after $attempt of $MAX_ATTEMPTS attempts: the agent writes its report"
if [[ "$RESULT" == SUCCESS ]]; then
  OUTCOME="The task passed verification on attempt $attempt of $MAX_ATTEMPTS."
else
  OUTCOME="The task did not pass verification after $MAX_ATTEMPTS attempts. The last check printed:
\`\`\`
$FEEDBACK
\`\`\`"
fi
run_agent "$TASK

---
$OUTCOME

Write a report for the person who gave you this task. Fill in the template
$OUT/$RESULT.md: keep its headings, replace every <…> placeholder, and remove
the HTML comments. Save the result as $OUT/REPORT.md. Don't change anything
else." "$LOGS/report.log" >/dev/null

if [[ -f "$OUT/REPORT.md" ]]; then
  step "Report (.outputs/REPORT.md)"
  cat "$OUT/REPORT.md"
else
  echo "The agent didn't write a report. See .outputs/logs/report.log." >&2
fi

[[ "$RESULT" == SUCCESS ]]
