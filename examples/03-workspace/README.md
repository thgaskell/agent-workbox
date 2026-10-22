# 03 – Workspace isolation

**Nothing reaches your machine until you say so.**

An agent is given the same task twice: build a Jupyter notebook that charts
`data/sales.csv`. The first time it works directly on your files. The second
time it works in its own clone, and you decide what to bring back.

| Mode | Your files | When you see the agent's changes |
|---|---|---|
| `direct` | Mounted read-write | Immediately, as the agent writes them |
| `clone` | Read-only copy at `/run/sandbox/source` | Only after you `git fetch` |

The "agent" here is [`stand-in-agent.sh`](stand-in-agent.sh), a script that
does exactly what [`task.md`](task.md) asks in a few seconds, with no API
calls. It runs in a plain `shell` sandbox, with no AI agent installed. The
sandbox's rules are the same whether a model or a script is typing.

## Before you start

- `sbx` installed and signed in (see the [main README](../../README.md))
- `.work/` listed in the repo's `.gitignore`

## Part A: direct mode

```bash
./setup.sh
./run.sh direct
```

The agent creates a notebook and a `requirements.txt`. Then `git status` runs
**on your machine**, and the new files are already there.

**What to notice:** the agent writes straight into your working tree.
Anything it changes, including `.git/hooks`, a `Makefile` or a
`requirements.txt`, is already on your machine, waiting for you to run it.

## Part B: clone mode

```bash
./setup.sh          # start fresh
./run.sh clone
```

Same agent, same task. This time `git status` on your machine shows **no
changes**: the agent's work exists only inside the sandbox.

Try writing to your original repo from inside the sandbox:

```bash
sbx exec workspace-clone touch /run/sandbox/source/hello     # fails: read-only
```

Review the agent's work from your machine:

```bash
cd .work/sample-repo
git fetch sandbox-workspace-clone
git log --oneline main..sandbox-workspace-clone/add-sales-viz
git diff --stat  main..sandbox-workspace-clone/add-sales-viz
```

To open the notebook without touching `main`, check the branch out next to it:

```bash
git worktree add ../review sandbox-workspace-clone/add-sales-viz
```

Happy with it? `git merge sandbox-workspace-clone/add-sales-viz`. Not happy? Do nothing.

**What to notice:** your repo only changes when *you* run `git fetch` and
`git merge`. Until then, the agent's work exists only inside the sandbox.

## Running the notebook's cells

By default the agent commits the notebook without running it, so it has no
outputs. Add `--execute` to either mode to have the agent run the cells first,
so the notebook is committed with its table and chart:

```bash
./setup.sh
./run.sh clone --execute
```

To run the cells, the agent installs what it listed in `requirements.txt`
(pandas, matplotlib and Jupyter) from PyPI into a virtual environment in the
sandbox's `/tmp`, outside the repo.
That needs a network policy that allows PyPI (Balanced does), and it can take
a few minutes, because every fresh sandbox downloads the packages again.

## Try to break it

Edit `stand-in-agent.sh` to:

- write a file outside the repo, e.g. in your home directory;
- push the branch somewhere (the repo has no remote);
- download a dataset instead of using `data/sales.csv`, then run
  `sbx policy log workspace-clone` on your machine.

## Clean up

```bash
./setup.sh      # removes both sandboxes and rebuilds a fresh repo
```

To remove everything: `./setup.sh && rm -rf .work`
