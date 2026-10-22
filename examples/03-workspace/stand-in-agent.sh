#!/usr/bin/env bash
# stand-in-agent.sh: does what task.md asks, with no model and no tokens.
# Run inside a sandbox:  sbx exec workspace-clone bash -c "$(cat stand-in-agent.sh)" stand-in-agent.sh [--execute]
#   --execute    run the notebook's cells, so it's committed with its outputs
set -euo pipefail
EXECUTE="${1:-}"
say() { printf '\033[2m[agent]\033[0m %s\n' "$*"; sleep 1; }
# commit <message> [paths…]   (default: everything)
commit() { local msg="$1"; shift
           git add -A -- "${@:-.}" && git -c user.name=agent -c user.email=agent@sandbox commit -qm "$msg" \
             || say "(couldn't commit here: no git access in this mode)"; }

say "Creating branch add-sales-viz"
git switch -qc add-sales-viz 2>/dev/null || say "(couldn't create a branch here)"

say "Writing notebooks/sales.ipynb"
mkdir -p notebooks
python3 - <<'PY'
import json
md   = lambda s: {"cell_type": "markdown", "metadata": {}, "source": s}
code = lambda s: {"cell_type": "code", "metadata": {}, "execution_count": None, "outputs": [], "source": s}
nb = {"nbformat": 4, "nbformat_minor": 5,
      "metadata": {"kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"}},
      "cells": [
        md("# Monthly revenue by region"),
        code("import pandas as pd\nimport matplotlib.pyplot as plt\n\ndf = pd.read_csv('../data/sales.csv')\ndf.groupby('region')['revenue'].sum()"),
        code("ax = df.pivot(index='month', columns='region', values='revenue').plot(marker='o')\n"
             "ax.set(title='Monthly revenue by region', xlabel='Month', ylabel='Revenue ($)')\nplt.xticks(rotation=45)\nplt.tight_layout()"),
        md("**Finding:** West leads at both ends of the year but drops below North from April to September."),
      ]}
json.dump(nb, open("notebooks/sales.ipynb", "w"), indent=1)
PY

say "Writing requirements.txt"
printf 'pandas\nmatplotlib\njupyter\n' > requirements.txt

if [[ "$EXECUTE" == --execute ]]; then
  # Packages go in a virtual env outside the repo, so they're never committed.
  # They come from PyPI, so this needs a network policy that allows it, and can take a minute.
  say "Installing requirements.txt (from PyPI, outside the repo)"
  ENV=/tmp/agent-nb-env
  if uv venv -q --allow-existing "$ENV" && VIRTUAL_ENV="$ENV" uv pip install -q -r requirements.txt; then
    say "Running the notebook's cells and saving the outputs"
    # jupyter-execute logs to stderr even on success, so only show it if a cell fails.
    if ! log=$(cd notebooks && "$ENV/bin/jupyter-execute" --inplace sales.ipynb 2>&1); then
      printf '%s\n' "$log" >&2; exit 1
    fi
  else
    say "(couldn't install the packages, so the notebook is committed without outputs)"
  fi
fi

commit "Add sales notebook" notebooks
commit "Add requirements"

say "Done. Changes are on branch add-sales-viz."
