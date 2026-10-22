# Agent Sandboxes

Small, self-contained examples of running a coding agent inside a sandbox
instead of directly on your machine. Each one shows a single idea:

| Example | What it shows |
|---|---|
| [`01-network`](examples/01-network) | The agent can only reach the sites you allow |
| [`02-secrets`](examples/02-secrets) | The agent can use your API key without ever seeing it |
| [`03-workspace`](examples/03-workspace) | The agent's changes reach your files only when you accept them |
| [`04-agentic-workflow`](examples/04-agentic-workflow) | An agent works unattended until a check it can't change passes |

The examples use [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/)
(the `sbx` CLI). Examples 01–03 don't need an AI agent: each runs a short
script that does the risky thing an agent might do, and example 02 calls a
model hosted on [Groq](https://groq.com). Example 04 runs a real agent of your
choice; see [Pick an agent](#pick-an-agent).

## Before you start

1. **Create a Groq API key.** Sign in to the
   [Groq console](https://console.groq.com/keys) and click **Create API Key**.
   Copy the key somewhere safe; you'll need it in example 02.

2. **Install `sbx` and sign in.** Follow the
   [Docker Sandboxes installation guide](https://docs.docker.com/ai/sandboxes/install/), then run:

   ```bash
   sbx login
   ```

3. **Start with [example 01](examples/01-network).** It shows how `sbx`
   decides which sites a sandbox can reach, which the later examples build
   on.

## Pick an agent

`sbx` can run any of these agents. Each one is a *harness* (the program that
edits files and runs commands) talking to a *provider* (the company hosting
the model). Pick the pair you already have an account for:

| Agent (`sbx run …`) | Providers it can use | How to sign in |
|---|---|---|
| `opencode` | OpenAI, Anthropic, Google, xAI, Groq, OpenRouter, GitHub Copilot | `sbx secret set <provider>` for each one you use (Copilot: `github`) |
| `docker-agent` | OpenAI, Anthropic, Google, xAI, Mistral, Nebius, OpenRouter | `sbx secret set <provider>` for each one you use |
| `claude` | Anthropic | `sbx secret set anthropic`, or `/login` with a Claude subscription |
| `codex` | OpenAI | `sbx secret set openai`, or `sbx secret set openai --oauth` with a ChatGPT account |
| `gemini` | Google | `sbx secret set google`, or sign in with a Google account at startup |
| `copilot` | GitHub Copilot | `sbx secret set github --command 'gh auth token'` |
| `cursor` | Cursor | `sbx secret set cursor`, or sign in on first run |
| `droid` | Factory | `sbx secret set droid`, or sign in on first run |
| `devin` | Devin | Sign in on first run |
| `kiro` | Kiro | Sign in with a device code on first run |
| `shell` | None: a plain Bash sandbox | Bring your own (see [example 02](examples/02-secrets)) |

**Not sure which to pick?**

- **You pay for one company's plan** (Claude, ChatGPT, Copilot, Cursor):
  use that company's agent.
- **You want to switch between providers:** use `opencode` or
  `docker-agent`. Store a key for each provider; the agent finds them.
- **Hoping to use a free tier?** Groq's free tier is enough for examples
  01–03, which make one small request at a time. It's **not** enough for a
  real agent: OpenCode's first request is about 12,000 tokens (its
  instructions plus tool descriptions), over the free tier's per-minute limit
  for the Groq models we tried (7,000–8,000). Use a paid Groq tier, or a
  provider you already pay for.

**Good to know, whichever you pick:**

- Every key works the way [example 02](examples/02-secrets) shows: it stays
  on your machine, and the proxy adds it to the agent's requests. A sign-in
  done *inside* the sandbox (Gemini, Kiro) is lost when you remove the sandbox.
- Everything the agent reaches still goes through your network policy
  ([example 01](examples/01-network)). If the agent can't reach its provider,
  check with `sbx policy check network --sandbox <name> <host>`. (`opencode`
  reached Groq without an extra rule when we tested it.)
- Sandboxes don't read your agent settings from your home folder (such as
  `~/.claude` or `~/.codex`), only the ones in the project folder.

Each agent's page in the
[Docker Sandboxes docs](https://docs.docker.com/ai/sandboxes/agents/) has the
details.
