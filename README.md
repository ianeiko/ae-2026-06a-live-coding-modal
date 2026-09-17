# Your first Modal app

A plain Python function that runs on someone else's computer. One decorator, one
command. Nothing in `main.py` is Modal-specific except two lines — that is the
point of the exercise: you are not learning a framework, you are learning where
the boundary between *your* machine and *their* machine sits, and what crosses it.

This repo is deliberately tiny. By the end you will have run a function
remotely, read its logs in the dashboard, deployed it so it outlives your
terminal, and called it from a one-liner.

```
   your machine                          Modal
   ─────────────                         ─────
   main.py
     @app.local_entrypoint()  ────┐
     def main():                  │  square.remote(42)
         square.remote(42)        └────────────────────▶  container
                                                            @app.function()
                                  ◀────────────────────     def square(x)
                                       1764
```

The code on both sides of that arrow is in the same file. Modal works out which
half to ship.

## TL;DR

1. **Account** (§1) — sign up for Modal, note which identity you use.
2. **Tools** (§2) — just `uv`. This repo already has the lockfile.
3. **Auth** (§3) — `uv run modal setup`.
4. **Run it** (§4) — `uv run modal run main.py`.
5. **Read the dashboard** (§5) — where the 404 trap lives.
6. **Deploy it** (§6) — `uv run modal deploy main.py`, then call it.

`bash scripts/check.sh` tells you where you are at any point.

Fifteen minutes, no card, no cloud project, no YAML.

## 1. Account

| Sign up for | Where | You leave with |
| --- | --- | --- |
| Modal | https://modal.com/signup | an account and a workspace (free tier; no card) |

Two things to note now, because both bite later:

- **Your workspace is named after your GitHub username** — or something random
  if that name is taken. Write it down. It shows up in every dashboard URL.
- **Remember which identity you signed up with** (GitHub? Google? which Google?).
  §5 explains why.

## 2. Tools

Only `uv`. That is the whole list.

```bash
brew install uv        # macOS — Windows: Appendix B
```

Modal's own docs open with `pip install modal`. **Ignore that here.** This repo
ships a `pyproject.toml`, a `uv.lock` and a `.python-version`, so `uv run`
installs the exact pinned `modal` into a project-local `.venv` the first time you
use it — no `pip`, no `venv` to activate, no global install to go stale. Every
Modal command in this README is therefore `uv run modal ...` rather than
`modal ...`.

```bash
uv sync          # optional — the first `uv run` does this for you
```

Checkpoint:

```bash
bash scripts/check.sh
```

It prints `ok` / `MISSING` for every step in this README and names the section
that fixes each one. Expect `MISSING no Modal token` until §3 — that's the next
step, not a problem. The first run takes a minute while `uv` installs the pinned
Python and the `modal` client.

## 3. Auth

```bash
uv run modal setup
```

A browser tab opens, you approve, it closes. What that wrote is a token in
`~/.modal.toml` — **not** in this repo, so it works for every Modal project on
this machine, and there is no secret to keep out of git.

Checkpoint:

```bash
bash scripts/check.sh      # expect: all set — go to §4
```

Among the `ok` lines is **`active workspace (<name>)`** — the workspace your
token belongs to, straight from `uv run modal profile list`. **Check it matches
the name from §1 now**, rather than discovering the mismatch in §5. The script
prints the comparison to make.

## 4. Run it

```bash
uv run modal run main.py
```

Expect roughly this:

```
✓ Initialized. View run at https://modal.com/apps/<workspace>/main/ap-XXXXXXXX
✓ Created objects.
├── 🔨 Created mount /Users/you/code/ae-2026-06a-live-coding-modal/main.py
└── 🔨 Created function square.
the square is 1764
This code is running on a remote worker!
Stopping app - local entrypoint completed.
✓ App completed. View run at https://modal.com/apps/<workspace>/main/ap-XXXXXXXX
```

Four things worth stopping on:

- **`Created mount ...main.py`** — your file was uploaded. Modal did not read
  your code from a git remote or a Docker build; it shipped the file.
- **`Created function square`** — the decorator registered it. `square` is now a
  handle to something that runs elsewhere.
- **The output is out of order.** `the square is 1764` prints *before*
  `This code is running on a remote worker!` even though the remote `print` runs
  first. Remote stdout is streamed back to your terminal with a lag. If you ever
  debug a Modal function by print statement, remember this — the ordering lies.
- **`Stopping app`** — this was an *ephemeral* app. It existed for the duration
  of the command. §6 is about the other kind.

Two variations worth trying:

```bash
uv run modal run main.py::square --x 5     # skip main(), call square directly
```

Modal turns the function's parameters into CLI flags. `square(x)` becomes `--x`.

## 5. Read the dashboard

Click the link the run printed. You get the app, the function, its logs, the
container that served it, and how long it lived.

**If that page says "Error loading deployment — Not Found: Workspace not found",
your run did not fail.** The breadcrumb at the top of that page is read straight
out of the URL, so it renders your workspace name whether or not you have access
to it; only the panel underneath actually queries the API. What that error means
is that **the browser is signed into Modal as a different account than your CLI
token belongs to** — different Google account, different Chrome profile,
GitHub-vs-Google on the same email.

Confirm it in two moves:

```bash
uv run modal profile list      # the workspace your CLI owns
```

Then open https://modal.com/apps with **no path** — it redirects to whatever
workspace the *browser* owns. Different names, there's your answer. Sign in with
the identity you used in §3, or use the workspace switcher at the top of the
dashboard if both accounts are yours.

## 6. Deploy it

`modal run` is a session. `modal deploy` is a thing that stays.

```bash
uv run modal deploy main.py
```

The app is now named and persistent (`example-get-started` — from
`modal.App("example-get-started")` at the top of `main.py`). The
`@app.local_entrypoint()` is *not* part of it; that decorator only ever means
"the thing to run locally when someone types `modal run`".

So call the deployed function from outside the file entirely:

```bash
uv run python -c "import modal; print(modal.Function.from_name('example-get-started', 'square').remote(7))"
```

`49`, from a process that never imported `main.py`. That one line is the payoff
of the whole tutorial: the function is now infrastructure. Anything holding your
token can call it — a cron job, a web handler, a colleague.

Housekeeping:

```bash
uv run modal app list                            # what's deployed
uv run modal app stop example-get-started        # tear it down
```

Stopping is destructive and one-way — a stopped app can't be restarted, you
redeploy instead. Nothing here costs anything on the free tier, so leaving it up
is fine too.

## What you actually learned

| You typed | What it means |
| --- | --- |
| `@app.function()` | this runs over there |
| `@app.local_entrypoint()` | this runs here, and is the entry point for `modal run` |
| `square.remote(42)` | call it over there, block for the answer |
| `modal run` | ephemeral — lives for one command |
| `modal deploy` | persistent — named, callable later |
| `Function.from_name(...)` | grab a handle to a deployed function from anywhere |
| `main` in the URL | your *environment*, not your branch |

The `main` in `modal.com/apps/<workspace>/main/...` is Modal's default
environment — a namespace for deployed apps, so staging and prod can hold the
same app name. You have exactly one and can ignore it.

## Appendix A — the lazy way

If you'd rather hand §2–§4 to Claude Code, open `claude` in this repo and paste:

> Set this machine up to run this Modal repo. Use **uv only** — never `pip`, never a
> global `modal` install; every Modal command is `uv run modal ...`. Install `uv` if
> it's missing. Then: `uv sync`, `uv run modal setup` (that one opens a browser and
> needs me — give me the command, I'll run it in another terminal and say "done").
> Run `bash scripts/check.sh` after each step and fix every `MISSING` line until it
> prints `all set`; `todo` lines are not yours to fix. Then `uv run modal run main.py`.
> Tell me the workspace name the check printed and paste the run output back to me. Don't change `main.py`, don't deploy anything, and don't put any
> token into a file in this repo.

## Appendix B — Windows

Everything above is a single `uv` binary and one Python file, so Windows is
almost entirely fine here. The one exception is `scripts/check.sh` — it is bash,
so run it from **Git Bash** (ships with
[Git for Windows](https://git-scm.com/download/win)). Every other command works
in PowerShell as written, bar the one noted below.

| Tool | Install (PowerShell) |
| --- | --- |
| uv | `winget install astral-sh.uv` |
| git | `winget install Git.Git` |
| Claude Code | `npm i -g @anthropic-ai/claude-code` |

Reopen your terminal after installing `uv` so it lands on `PATH`. Then every
command in §2–§6 works unchanged in PowerShell, **except** the `python -c`
one-liner in §6 — PowerShell mangles the nested quotes. Put it in a file instead:

```python
# call.py
import modal
print(modal.Function.from_name("example-get-started", "square").remote(7))
```

```powershell
uv run python call.py
```

(That is the nicer way on macOS too, once the one-liner stops fitting on a line.)

The token from §3 lands in `%USERPROFILE%\.modal.toml`.

## Troubleshooting

| What you see | Cause | Fix |
| --- | --- | --- |
| `scripts/check.sh: No such file` or `bash: not found` | you're in PowerShell or `cmd` | Appendix B — run it from Git Bash |
| check.sh says `couldn't parse the workspace name` | Modal changed its CLI output; not fatal | it prints the raw table underneath — read it yourself |
| Dashboard says `Not Found: Workspace not found`, but the run printed `1764` | browser signed into a different Modal account than your CLI token | §5 — compare `uv run modal profile list` against https://modal.com/apps |
| `modal: command not found` | you dropped the `uv run` prefix | there is no global `modal` here by design — always `uv run modal ...` |
| `Token missing` / `not authenticated` | §3 never completed | re-run `uv run modal setup`; check `~/.modal.toml` exists |
| Browser tab from `modal setup` hangs or you closed it | the CLI is still waiting on the callback | Ctrl-C and re-run; or `uv run modal token new` |
| `uv run` re-downloads Python every time | you're running it somewhere without the project's `.python-version` | run from the repo root |
| Remote logs appear in the wrong order | not a bug — streamed stdout lags | §4; don't debug ordering by `print` |
| `the square is 1764` but no dashboard link | older client | `uv sync --upgrade`, then re-run |
| Modal rejects the Python version | this repo pins 3.14 in `.python-version`, and Modal matches your local minor version remotely | pin the remote side instead: give the function an image with `python_version="3.13"` |
| Deployed function `NotFoundError` from `from_name` | name mismatch or wrong workspace | the app name is `example-get-started` (in `main.py`), the function is `square`; check `uv run modal app list` |
| Second `modal deploy` — did it duplicate? | no | deploy is idempotent per app name; it replaces |
