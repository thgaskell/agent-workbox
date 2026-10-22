# 01 – Network policies

**The agent can only reach the sites you allow.**

Agents download things: packages, datasets, and sometimes an install script
piped straight into a shell (`curl … | sh`). Inside a sandbox, every request
leaves through a proxy on your machine that checks it against your policy
first.

You'll send the same three requests from two sandboxes and compare what gets
through.

## How policies work

- **Everything is blocked unless a rule allows it.**
- The first time you use `sbx`, you pick a **global preset** (or set one
  with `sbx policy init`):

  | Preset | What it allows |
  |---|---|
  | Open | Everything |
  | Balanced | Major AI provider APIs, package managers, code hosts, registries, common cloud services |
  | Locked Down | Nothing until you add rules |

- You can add rules **for one sandbox** on top of the preset.
- A **deny always beats an allow**, no matter which is more specific.
- Changes take effect immediately, with no restart.

See your current rules with `sbx policy ls`.

## Run it

```bash
./run.sh
```

This creates two sandboxes with no files mounted:

- `net-default` uses your global preset only.
- `net-tight` also gets the rules in [`policy.sh`](policy.sh): allow PyPI,
  deny GitHub.

Each sandbox then tries to download three things. Nothing is executed.

| Request | `net-default` (Balanced) | `net-tight` |
|---|---|---|
| Python packages (PyPI) | ✅ reachable | ✅ reachable |
| Script on GitHub | ✅ **reachable** | ⛔ blocked |
| Unknown site (`example.com`) | ⛔ blocked | ⛔ blocked |

(If you picked Open or Locked Down instead of Balanced, the first column will
look different.)

**What to notice:**
- With Balanced, the unknown site is blocked, but a script on GitHub gets
  through, because Balanced trusts code hosts. That's exactly where most
  `curl … | sh` scripts live.
- You can ask the policy directly, without sending anything:
  `sbx policy check network --sandbox net-tight raw.githubusercontent.com`.
- The script finishes with `sbx policy log`, which lists every request
  `net-tight` made, which rule matched, and whether it was allowed.

## Try it

- **Change a rule live.** On your machine:
  ```bash
  sbx policy allow network --sandbox net-tight example.com
  ./run.sh
  ```
  The unknown site is now reachable from `net-tight` only. Remove it again:
  `sbx policy rm network --sandbox net-tight --resource example.com`
- **Try to override a deny with an allow.**
  `sbx policy allow network --sandbox net-tight raw.githubusercontent.com`. It's still
  blocked, because the deny wins.
- **Hit the wall yourself.** Run `sbx run --name net-tight` to open a shell in the
  sandbox, then try an install script the way an agent would:
  `curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash`.
  Then check `sbx policy log net-tight`.

## Talk about it

- An allowlist is only as strong as its loosest entry. PyPI is on the list,
  and `pip install` can run any code a package author wrote. What would you
  allow for your own projects?
- Balanced is convenient, Locked Down is safe. Which would you choose for an
  agent running unattended overnight?

## Clean up

```bash
./run.sh clean
```

Your global preset is untouched. Run `sbx policy ls` afterwards to check that
no `net-tight` rules were left behind; if any were, remove them with
`sbx policy rm network --sandbox net-tight --resource <domain>`.
