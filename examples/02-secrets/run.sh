#!/usr/bin/env bash
# run.sh: show that the agent can use your Groq key without seeing it
#   ./run.sh          the right way: key stored with `sbx secret set-custom`
#   ./run.sh leaky    the wrong way: key copied in with `-e GROQ_API_KEY`
#   ./run.sh clean    remove both sandboxes (and the key stored for secrets-demo)
#   MODEL=<groq-model-id> ./run.sh   ask a different Groq model
set -euo pipefail
cd "$(dirname "$0")"

AGENT=shell    # plain Bash sandbox: no AI agent installed
MODEL="${MODEL:-openai/gpt-oss-120b}"    # any Groq model ID

step() { printf '\n\033[1m── %s\033[0m\n' "$*"; }
in_box() { sbx exec "$NAME" bash -c "$1"; }

# Prints the key the way hello_groq.py does: placeholders in full, real keys masked.
SHOW_KEY='v="${GROQ_API_KEY:-}"
case "$v" in
  "")    echo "(not set)" ;;
  gsk_*) echo "a REAL key: ${v:0:4}…${v: -2} (${#v} characters)" ;;
  *)     echo "\"$v\" (a placeholder, not a key)" ;;
esac'

case "${1:-safe}" in
  safe)
    NAME=secrets-demo
    # sbx's built-in `groq` secret only reaches agents that use Groq (e.g. opencode),
    # not a plain shell sandbox, so store the key as a custom secret for this sandbox.
    has_key() { sbx secret ls --sandbox "$NAME" --json 2>/dev/null | grep -q '"env": "GROQ_API_KEY"'; }
    if ! sbx ls 2>/dev/null | grep -qw "$NAME"; then
      # The secret must exist before the sandbox, or GROQ_API_KEY stays empty inside it.
      if ! has_key; then
        echo "Storing your Groq key for $NAME (paste it at the prompt; it stays on this machine)."
        sbx secret set-custom --sandbox "$NAME" --host api.groq.com \
          --env GROQ_API_KEY --placeholder 'groq-placeholder-{rand}'
      fi
      sbx create --name "$NAME" "$AGENT" "$PWD"
    elif ! has_key; then
      echo "$NAME was created without a Groq key. Run:  $0 clean && $0" >&2
      exit 1
    fi
    # Balanced doesn't include Groq (see 01-network). An HTTP rule (--method) lets
    # the proxy open the request and swap in the key. Re-adding it is a no-op.
    sbx policy allow network --sandbox "$NAME" "api.groq.com" --method ANY >/dev/null

    step "1. What does the sandbox see in GROQ_API_KEY?"
    in_box "$SHOW_KEY"

    step "2. Can code in the sandbox still call Groq?"
    in_box "GROQ_MODEL=$(printf %q "$MODEL") python3 hello_groq.py"

    step "3. Is the real key anywhere in the sandbox?"
    in_box 'found=$( { cat /proc/*/environ 2>/dev/null | tr "\0" "\n";
                       grep -rhoI "gsk_[A-Za-z0-9]*" /home /root /etc /tmp 2>/dev/null; } \
                     | grep -c "gsk_" || true)
            echo "Matches for a Groq key: $found"'
    ;;

  leaky)
    NAME=secrets-leaky
    if [[ -z "${GROQ_API_KEY:-}" ]]; then
      read -rsp "Paste your Groq key (it will be copied into the sandbox): " GROQ_API_KEY
      echo
      export GROQ_API_KEY
    fi
    if [[ -z "$GROQ_API_KEY" ]]; then
      echo "No key entered." >&2
      exit 1
    fi
    if ! sbx ls 2>/dev/null | grep -qw "$NAME"; then
      sbx create --name "$NAME" -e GROQ_API_KEY "$AGENT" "$PWD"
    # -e only applies at creation, so an existing sandbox keeps whatever it started with.
    elif ! in_box '[[ -n "${GROQ_API_KEY:-}" ]]' 2>/dev/null; then
      echo "$NAME was created without GROQ_API_KEY. Run:  $0 clean && $0 leaky" >&2
      exit 1
    fi
    sbx policy allow network --sandbox "$NAME" "api.groq.com" >/dev/null

    step "1. What does the sandbox see in GROQ_API_KEY?"
    in_box "$SHOW_KEY"

    step "2. Can code in the sandbox still call Groq?"
    in_box "GROQ_MODEL=$(printf %q "$MODEL") python3 hello_groq.py"

    step "3. Any program the agent runs can read it (and send it anywhere):"
    in_box 'python3 -c "import os; k = os.environ[\"GROQ_API_KEY\"]; print(\"Read by a random script:\", k[:4] + \"…\", len(k), \"characters\")"'
    ;;

  clean)
    for NAME in secrets-demo secrets-leaky; do
      sbx rm --force "$NAME" >/dev/null 2>&1 || true
    done
    echo "Removed both sandboxes, and the Groq key stored for secrets-demo with them."
    echo "Your global secrets are untouched."
    ;;

  *) echo "usage: $0 [safe|leaky|clean]" >&2; exit 1 ;;
esac
