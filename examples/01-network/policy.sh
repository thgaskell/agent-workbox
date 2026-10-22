#!/usr/bin/env bash
# policy.sh: a tighter network policy for one sandbox
#   ./policy.sh <sandbox-name>
#
# Rules here apply only to the named sandbox, on top of your global preset.
# A deny always beats an allow, whatever order they were added in.
set -euo pipefail
NAME="${1:?usage: $0 <sandbox-name>}"

# What this project actually needs: Python packages.
ALLOW="pypi.org,files.pythonhosted.org"

# Code hosts: the usual source of `curl … | sh` install scripts.
# `example.com` doesn't cover `*.example.com` (and vice versa), so list both.
DENY="github.com,*.github.com,githubusercontent.com,*.githubusercontent.com"

sbx policy allow network --sandbox "$NAME" "$ALLOW"
sbx policy deny  network --sandbox "$NAME" "$DENY"
sbx policy ls "$NAME"
