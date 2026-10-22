# 04 – Agentic workflow

**The agent works on its own until a check it can't change says it's done.**

You write a task, start `./run.sh`, and walk away. The agent gets no
questions and no approvals, and it can't decide for itself that it's
finished: after every attempt, `run.sh` runs `verify.sh`, and only a passing
`verify.sh` ends the loop. At the end, the agent writes a report.

```
 AGENTS.local.md ──▶ agent works in work/ ──▶ verify.sh (read-only)
                            ▲                     │        │
                            └─── fails: output ───┘        │ passes, or
                                 goes into the             │ MAX_ATTEMPTS used up
                                 next prompt               ▼
                                         agent fills SUCCESS.md or FAILURE.md
                                                ──▶ .outputs/REPORT.md
```

## What's in here

| File | What it's for | Can the agent change it? |
|---|---|---|
| [`AGENTS.local.md`](AGENTS.local.md) | Your task | It's not in the sandbox; the agent gets its text as the prompt |
| [`verify.sh`](verify.sh) | Your definition of "done" | **No**, it's mounted read-only |
| [`.outputs/SUCCESS.md`](.outputs/SUCCESS.md), [`.outputs/FAILURE.md`](.outputs/FAILURE.md) | Report templates | **No**, they're mounted read-only |
| `work/` | The agent's workspace | Yes |
| `.outputs/REPORT.md` | The agent's report, written at the end | Yes |
| [`run.sh`](run.sh) | Runs the loop on your machine | It's not in the sandbox |

The prompt never tells the agent how it will be checked, and the loop
doesn't trust the agent to say it's done. The agent can find and *read*
`verify.sh`, but it can't edit its own success criteria.

## Run it

The repo comes with an example task: write a `slugify()` function, checked
by six test cases in `verify.sh`.

1. Pick an agent and sign in (see
   [Pick an agent](../../README.md#pick-an-agent)).
2. Start the loop with that agent:

   ```bash
   AGENT=claude ./run.sh
   ```

You'll see each attempt, what `verify.sh` printed, and then the report.
`run.sh` exits with 0 if the task passed and 1 if it didn't, and it keeps a
log of every attempt in `.outputs/logs/`.

| Setting | Default | What it does |
|---|---|---|
| `AGENT` | `opencode` | `opencode`, `claude`, `codex`, `gemini`, `copilot` or `cursor` |
| `MODEL` | the agent's default | Model to use, for `opencode` only (for example `groq/openai/gpt-oss-120b`) |
| `MAX_ATTEMPTS` | `3` | Attempts before the loop gives up and reports a failure |
| `ATTEMPT_TIMEOUT` | `10m` | Time limit for each attempt; the agent is stopped when it runs out |

`run.sh` enforces both limits from outside the agent. That matters: in
testing, OpenCode hit a rate-limit error and kept retrying for over five
minutes on its own. Here it's stopped after `ATTEMPT_TIMEOUT`, and the loop
moves on.

> **Groq's free tier is too small for an agent.** OpenCode's first request is
> about 12,000 tokens, and the free tier allows 7,000–8,000 per minute for the
> Groq models we tried. Use a paid tier or another provider.

## Make it your own

1. **Write your task in `AGENTS.local.md`.** Keep the four headings (Goal,
   Requirements, Out of scope, Notes) and replace the example under them.
2. **Write the check in `verify.sh`.** It runs inside `work/` and must exit 0
   only when the task is really done. When it fails, whatever it prints goes
   to the agent in the next prompt, so make the messages useful.
3. **Edit the report templates in `.outputs/`**, if you want different
   headings.

### Your task stays on your machine

`AGENTS.local.md` is committed once, so it's there when you clone. Every
`./run.sh` then tells git to ignore your edits to it:

```bash
git update-index --skip-worktree AGENTS.local.md
```

Your edits never show up in `git status`, so they can't be committed or
pushed by accident. If you edit the file before your first `./run.sh`, run
that command yourself. To commit a change to the template on purpose, run
`git update-index --no-skip-worktree AGENTS.local.md` first.

## What this doesn't protect against

- **Tampering inside the sandbox.** `verify.sh` runs in the same sandbox the
  agent worked in, and the agent has `sudo` there. It can't edit
  `verify.sh`, but it could, for example, replace `python3`. A passing check
  is evidence, not proof: read the work before you use it.
- **A weak check.** Anything `verify.sh` doesn't test, the agent can skip and
  still pass.
- **Cost.** Every attempt uses your provider's quota. The most time it can
  spend is `MAX_ATTEMPTS` × `ATTEMPT_TIMEOUT`, plus the report.

`work/` is mounted straight into the sandbox, like
[example 03's direct mode](../03-workspace). Apart from `.outputs/`, nothing
else on your machine is mounted read-write.

## Clean up

```bash
./run.sh clean                                 # removes the sandbox
rm -r work .outputs/logs .outputs/REPORT.md    # removes the agent's output
```
