# 02 – Secrets

**The agent can use your API key without ever seeing it.**

You'll store your Groq key with `sbx`, then check three things from inside a
sandbox: what the key looks like there, whether code can still call Groq, and
whether the real key can be found anywhere. Then you'll do it the wrong way
for comparison.

## How it works

```
 your machine                              sandbox
 ┌───────────────────────┐                ┌──────────────────────────────┐
 │ keychain: real key    │                │ GROQ_API_KEY=<placeholder>   │
 │          │            │   request to   │                              │
 │          ▼            │◀── api.groq ───│ python3 hello_groq.py        │
 │ proxy adds real key ──┼──▶ api.groq.com│                              │
 └───────────────────────┘                └──────────────────────────────┘
```

The key stays in your operating system's keychain. When something in the
sandbox sends a request to `api.groq.com`, a proxy on your machine puts the
real key into that request on the way out. The sandbox only ever holds a
placeholder.

## 1. Store your key and run the demo

You need a Groq API key first (see the [main README](../../README.md)).

```bash
./run.sh
```

The first time, the script asks for your key and stores it with `sbx` for
a sandbox called `secrets-demo` only. Under the hood it runs:

```bash
sbx secret set-custom --sandbox secrets-demo --host api.groq.com \
  --env GROQ_API_KEY --placeholder 'groq-placeholder-{rand}'
```

That tells `sbx`: inside `secrets-demo`, set `GROQ_API_KEY` to a placeholder;
when a request leaves for `api.groq.com`, swap the placeholder for the real
key. Check it's there with `sbx secret ls`.

The script also opens the network for Groq. As you saw in
[example 01](../01-network), the Balanced preset doesn't include
`api.groq.com`, so it adds a rule for this sandbox only:

```bash
sbx policy allow network --sandbox secrets-demo api.groq.com --method ANY
```

`--method` makes it an HTTP rule, which lets the proxy open the request and
swap in the key.

> **Why not `sbx secret set groq`?** That built-in secret only reaches
> sandboxes whose agent uses Groq, like OpenCode. This demo
> uses a plain shell sandbox, so it needs a custom secret instead. Order
> matters too: the secret has to exist *before* the sandbox is created, or
> `GROQ_API_KEY` stays empty inside it. The script handles both.

## 2. The right way

The script then creates the `secrets-demo` sandbox and runs three checks
inside it:

1. **What's in `GROQ_API_KEY`?** A placeholder, not your key.
2. **Can code call Groq?** Yes. `hello_groq.py` gets a real answer.
3. **Is the real key anywhere?** The script searches the environment of every
   process and the usual config folders. It finds nothing.

## 3. The wrong way, for comparison

```bash
./run.sh leaky
```

This creates a second sandbox, `secrets-leaky`, using `-e GROQ_API_KEY`. That
copies the real key into the sandbox as an ordinary environment variable.
(The script asks for your key if it isn't already set in your terminal.)

The Groq call still works, which is the trap: both approaches *look* the same
from the outside. The difference is that now any program the agent runs can
read your key and send it anywhere.

> Outputs are masked so your key never appears on screen in full. Keep it
> that way if you're presenting or recording.

## Choosing a model

`hello_groq.py` asks this model by default:

```
openai/gpt-oss-120b
```

To use a different one, set `MODEL` when you run the script:

```bash
MODEL=openai/gpt-oss-20b ./run.sh
```

To see which models are available, check
[Groq's model list](https://console.groq.com/docs/models) and use the model ID
as listed.

Groq's free tier limits how many tokens you can use per minute. If you see
`429 Too Many Requests`, wait a moment or switch models.

## Try it

- **Revoke the key while a sandbox is running.** On your machine, find the
  placeholder with `sbx secret ls --sandbox secrets-demo`, then run
  `sbx secret rm --sandbox secrets-demo --placeholder <placeholder>` and
  `./run.sh` again: the Groq call fails with 401. To get it back, run
  `./run.sh clean && ./run.sh` and paste the key again.
- **Notice the scope.** The key belongs to `secrets-demo` alone: no other
  sandbox gets a `GROQ_API_KEY`, and removing the sandbox removes the key.
- **Talk about it:** the agent can't *steal* the key, but it can still *use*
  it. What could a misbehaving agent do with your Groq quota? What would you
  put in place to limit that?

## Troubleshooting

**`python3: command not found`.**
The sandbox image doesn't include Python. Run
`sbx exec secrets-demo bash -c "sudo apt-get install -y python3"` (this needs
the package mirrors to be allowed by your network policy).

**Step 1 shows `(not set)`.**
The sandbox was created before the key was stored (for example, by an older
version of this script). Run `./run.sh clean && ./run.sh`. The same goes for
`./run.sh leaky`: `-e` only applies when a sandbox is created, so an existing
`secrets-leaky` keeps whatever it started with.

**The Groq call fails with "Could not reach Groq".**
The network policy is blocking `api.groq.com`. Run `sbx policy log` on your
machine to confirm, and `sbx policy ls secrets-demo` to check the rule from
step 1 is there.

## Clean up

```bash
./run.sh clean
```

This removes both sandboxes, and the key and network rule stored for
`secrets-demo` go with them.
