"""Call Groq from inside a sandbox, and show which key this script can see.

Standard library only, so nothing needs to be installed.

    python3 hello_groq.py
    GROQ_MODEL=openai/gpt-oss-20b python3 hello_groq.py
"""

import json
import os
import urllib.error
import urllib.request

URL = "https://api.groq.com/openai/v1/chat/completions"
MODEL = os.environ.get("GROQ_MODEL", "openai/gpt-oss-120b")
key = os.environ.get("GROQ_API_KEY", "")


def describe(value: str) -> str:
    """Show a placeholder in full, but never print a real key."""
    if not value:
        return "(not set)"
    if value.startswith("gsk_"):
        return f"a REAL key: {value[:4]}…{value[-2:]} ({len(value)} characters)"
    return f"{value!r} (a placeholder, not a key)"


print(f"GROQ_API_KEY seen by this script: {describe(key)}")
print(f"Asking {MODEL} a question…\n")

body = json.dumps({
    "model": MODEL,
    "messages": [{"role": "user", "content": "In one sentence: why run an AI agent in a sandbox?"}],
    "max_tokens": 80,
}).encode()

request = urllib.request.Request(URL, data=body, headers={
    "Authorization": f"Bearer {key or 'missing'}",
    "Content-Type": "application/json",
    # Groq sits behind Cloudflare, which rejects Python's default User-Agent
    # ("Python-urllib/3.x") with "error code: 1010".
    "User-Agent": "hello-groq/1.0",
})

try:
    with urllib.request.urlopen(request, timeout=30) as response:
        reply = json.load(response)["choices"][0]["message"]["content"]
        print(f"Groq replied: {reply.strip()}")
except urllib.error.HTTPError as error:
    print(f"Groq returned HTTP {error.code}: {error.read().decode()[:200]}")
    if error.code == 401:
        print("→ The key was rejected. Check `sbx secret ls` on your machine.")
    elif error.code == 403:
        print("→ Blocked by Groq's firewall, not by the sandbox. Check the User-Agent header.")
except urllib.error.URLError as error:
    print(f"Could not reach Groq: {error.reason}")
    print("→ The network policy may be blocking api.groq.com. Run `sbx policy log` on your machine.")
