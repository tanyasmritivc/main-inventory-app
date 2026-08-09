# What we actually did, and why — a beginner's walkthrough

Written 2026-08-06, the night we moved the FindEZ backend from Render onto the OpenStack VM.
Every command you ran is explained here, along with what the words mean and why that step
existed at all.

---

## The one-paragraph version

Your backend is a Python program. For people to use it, that program has to be running on a
computer that is always switched on and reachable from the internet. Tonight you took a blank
Linux machine, got yourself in, copied your code onto it, installed everything the code needs,
gave it its passwords, arranged for it to start automatically and restart if it dies, and put a
traffic director in front of it. All of that works. The only thing left is a routing rule on your
uncle's side of the network.

---

## Part 1 — Getting into a computer that isn't in front of you

### SSH

**SSH** stands for Secure Shell. It's a way to type commands into a computer somewhere else and
see the results, with everything encrypted in transit so nobody in between can read it.

When you type `ssh findez` and the prompt changes to `ubuntu@findez`, your keyboard is now
connected to that machine. Every command goes there instead of to your Mac. Typing `exit` brings
you home.

**Why it matters:** the VM has no screen, no keyboard, no mouse. SSH is the only way to touch it.

### Public and private keys

Your uncle said "private-key authentication only — no password." Here's what that means.

A **key pair** is two matching files generated together:

- The **private key** stays on your Mac and is never sent anywhere. Ever.
- The **public key** is installed on the server. It's not secret.

When you connect, the server sends a random puzzle that can only be solved by someone holding the
private key. You solve it, the server lets you in. **Your private key never travels across the
network**, which is why this is much safer than a password — there's nothing to intercept.

It's also why losing the private key means losing access, and why pasting one into a chat window
means it should be regenerated.

### `chmod 600` and `chmod 700`

**chmod** means "change mode" — it sets who is allowed to read, write, or run a file.

The numbers are three digits: **you**, **your group**, **everyone else**. Each digit adds up
read (4) + write (2) + execute (1).

- `600` = you can read and write, nobody else can do anything.
- `700` = you can read, write and enter (for folders, "execute" means "look inside").

SSH **refuses to use a private key that other accounts could read.** It's not being fussy — a key
readable by others isn't really private. That's why `chmod 600 ~/.ssh/openstack_findez` wasn't
optional, and why forgetting it produces `Permission denied (publickey)`.

You used `chmod 600` twice more: on `~/.ssh/config` and on `.env`. Same reasoning — both contain
things that shouldn't be readable by other accounts on the machine.

### `~/.ssh/config`

Without it, connecting means typing the address, port, username and key path every single time.
The config file stores all that under a nickname:

```
Host findez              ← the nickname you type
  HostName openstack.ftctools.com   ← the real address
  Port 22005             ← which door to knock on
  User ubuntu            ← who to log in as
  IdentityFile ~/.ssh/openstack_findez   ← which key to use
  IdentitiesOnly yes     ← don't offer any other keys
```

That's what your uncle meant by a "login batch file."

`IdentitiesOnly yes` matters if you ever have several keys: without it, SSH offers them all in
turn, and some servers cut you off after a few wrong guesses.

### Why the connection kept dropping

Idle network connections get closed — by the server, or by equipment in between that reclaims
connections nobody seems to be using. You'd be reading in your browser for two minutes, and by the
time you came back the connection was gone.

```
ServerAliveInterval 30    ← send a tiny "still here" ping every 30 seconds
ServerAliveCountMax 6     ← give up only after 6 unanswered pings
TCPKeepAlive yes
```

That keeps a trickle of traffic flowing so nothing decides you've left.

**This caused the most confusing bug of the night.** When SSH drops, you land back on your Mac —
but the terminal looks almost identical. You then ran `sudo tee /etc/systemd/...` on your *Mac*,
which has no `/etc/systemd/` because that's a Linux thing, and got "No such file or directory."

**The habit that prevents it:** read the prompt before every command.

- `ubuntu@findez:~$` → the VM
- `tanyasmritivictorcharles@Tanyas-Mac-mini %` → your Mac

### Ports, briefly

A computer has one address but many **ports** — numbered doors, 1 to 65535. Different services
listen on different ones so they don't collide.

- **22** — SSH (yours is reachable from outside on 22005, which gets translated to 22 internally)
- **80** — HTTP, ordinary web traffic
- **443** — HTTPS, encrypted web traffic
- **8000** — nothing special, just where we told your app to sit

Ports below 1024 are **privileged**: only an administrator can open one. That becomes relevant
later.

---

## Part 2 — Getting your code onto the machine

### Git, repositories, cloning

**Git** tracks every change to your code. A **repository** ("repo") is a project's folder plus its
entire history. Yours lives on GitHub.

**Cloning** downloads a full copy including history. That's why `git clone` was the right move
rather than copying files by hand — later, `git pull` fetches your newest changes in one command.

### Deploy keys

Your repo is private, so the VM needed permission to read it. Options were:

1. Put your personal GitHub credentials on the VM — bad. That key can reach *all* your repos, and
   your uncle has root on that machine.
2. Create a **deploy key**: a key pair authorised for exactly one repository.

You generated a key pair on the VM and gave GitHub the public half. **"Allow write access"
unchecked** means it can download but never upload. If that key ever leaked, the worst case is
someone reads this one repo — they can't push malicious code that then gets deployed.

This is the **principle of least privilege**: give every component the minimum access it needs.

---

## Part 3 — Making the code runnable

### `apt` and packages

**apt** is Ubuntu's app store for command-line software. `sudo apt update` refreshes the catalogue;
`sudo apt install` installs.

**sudo** means "do this as the administrator." Linux normally stops you from changing system files,
and `sudo` is you saying "I mean it."

You installed `python3-venv` and `python3-pip`. Ubuntu ships Python but leaves out some pieces to
keep the base system small — those were the missing pieces.

### Virtual environments

This one confuses everyone at first.

Your system has one Python. If every project installed its libraries into it, Project A needing
version 1 of something and Project B needing version 2 would break each other.

A **virtual environment** is a private folder holding one project's libraries:

```bash
python3 -m venv .venv     # create the private folder
source .venv/bin/activate # use it for this terminal session
```

After activating, your prompt shows `(.venv)`. Now `pip install` puts libraries in that folder
instead of system-wide, and your project can't break anything else on the machine.

**The systemd file never activates it** — instead it runs
`/home/ubuntu/findez/.venv/bin/uvicorn` directly. Pointing at the executable inside the virtual
environment has exactly the same effect, and is more reliable for a background service.

### `pip` and `requirements.txt`

**pip** installs Python libraries. **`requirements.txt`** lists what your project needs, with exact
versions:

```
fastapi==0.115.6
uvicorn==0.34.0
```

Pinned versions mean the VM gets *identical* libraries to everywhere else. Without pinning, a
library could release a new version tomorrow, install itself on your next deploy, and break
something with no change on your part.

### What the main libraries do

- **FastAPI** — the framework that turns Python functions into web endpoints. When something calls
  `/add_item`, FastAPI routes it to the right function.
- **uvicorn** — the actual web server that runs FastAPI. FastAPI defines *what* to do; uvicorn
  listens on a port and handles the network.
- **pydantic** — checks data is the right shape. It's what refused to start when configuration was
  wrong, which is a feature: better a loud failure at startup than mysterious behaviour later.
- **supabase** — talks to your database.
- **openai** — talks to the AI.
- **slowapi** — rate limiting, so nobody can hammer your API.

---

## Part 4 — Configuration and secrets

### Environment variables

Your app needs API keys and database addresses. These must not be written into your code, because
code goes to GitHub and secrets must never go to GitHub.

An **environment variable** is a named value handed to a program when it starts. The program reads
`OPENAI_API_KEY` from its environment rather than having it written inside.

This also means the same code runs anywhere — on your laptop, on Render, on this VM — with
different values each time. That's why moving hosts was mostly about moving *configuration*, not
changing code.

### The `.env` file

A plain text file of `NAME=value` lines. The rules that bit you:

- No spaces around `=`
- No quotes, **except** where a value contains characters that need protecting
- One per line

`chmod 600` matters here more than anywhere: this file contains your Supabase service role key.

### What each variable is

| Variable | What it is |
|---|---|
| `SUPABASE_URL` | Your database's address |
| `SUPABASE_ANON_KEY` | Public key. Safe in the phone app. Restricted by security rules. |
| `SUPABASE_SERVICE_ROLE_KEY` | **Master key. Ignores every security rule.** Backend only, never in an app, never in GitHub. |
| `SUPABASE_JWKS_URL` | Where to fetch the public keys that verify user logins |
| `OPENAI_API_KEY` | Bills AI usage to your account |
| `OPENAI_MODEL` | Which AI model to use |
| `STRIPE_*` | Payment configuration |
| `BACKEND_CORS_ORIGINS` | Which websites may call your backend from a browser |
| `ENV` | `production` — switches off the developer documentation pages |

### Why `BACKEND_CORS_ORIGINS` needed single quotes

**CORS** (Cross-Origin Resource Sharing) is a browser rule: a page on site A can't call site B
unless B explicitly permits it. This list is your backend's permission slip. It only affects
browsers — your phone app ignores CORS entirely.

The value is a JSON list, which contains double quotes:

```
["https://www.findez.ai","http://localhost:3000"]
```

systemd reads `.env` more strictly than a shell does, and it **strips double quotes** as it parses.
That would have turned your list into invalid JSON and crashed the app on startup. Wrapping the
whole thing in single quotes protects the doubles inside:

```
BACKEND_CORS_ORIGINS='["https://www.findez.ai","http://localhost:3000"]'
```

---

## Part 5 — Keeping it running

### Why the app died when you closed the terminal

A running program is a **process**. Processes started from your SSH session are children of that
session, so when the session ends, they end. Fine for testing, useless for a real service.

### systemd

**systemd** is the program that manages everything running on a Linux machine. It starts things at
boot, restarts them when they crash, and collects their logs. You describe a service in a **unit
file** and systemd handles the rest.

Your unit file, line by line:

```ini
[Unit]
Description=FindEZ backend      # human-readable label
After=network.target            # don't start until networking is up

[Service]
Type=simple                     # the command stays running; it isn't a one-off task
User=ubuntu                     # run as ubuntu, NOT as root
WorkingDirectory=/home/ubuntu/findez/backend   # which folder to start from
EnvironmentFile=/home/ubuntu/findez/.env       # load the secrets
ExecStart=...uvicorn app.main:app --host 127.0.0.1 --port 8000 ...
Restart=always                  # if it dies, start it again
RestartSec=5                    # wait 5 seconds first

[Install]
WantedBy=multi-user.target      # start automatically at boot
```

**`User=ubuntu` matters.** If your app is ever compromised, the attacker gets an ordinary user's
powers, not the whole machine. Never run a web app as root without a reason.

**`WorkingDirectory` caused your `ModuleNotFoundError`.** Python looks for code relative to where
it was started. Your code says `from app.api.router import ...`, so Python must start inside
`backend/`, where the `app` folder lives. We first pointed it at the repo root, from where there is
no `app` folder — hence `No module named 'app'`. Moving `WorkingDirectory` one level down fixed it.

(Your `CLAUDE.md` documents `uvicorn backend.app.main:app` from the repo root. That command cannot
work for the same reason — worth correcting.)

### The three systemctl verbs

- `sudo systemctl start findez` — run it now
- `sudo systemctl enable findez` — run it at every boot
- `sudo systemctl enable --now findez` — both

`daemon-reload` tells systemd to re-read unit files after you edit one. Skip it and systemd keeps
using the old version, which is a genuinely maddening way to lose ten minutes.

### Reading logs

```bash
journalctl -u findez -n 40 --no-pager
```

`-u` picks the service, `-n 40` shows the last 40 lines, `--no-pager` prints it all at once instead
of trapping you in a scroll viewer.

This is where you found `ModuleNotFoundError: No module named 'app'`. **The useful line in a Python
error is almost always the last one** — everything above is the path the error took to get there.

---

## Part 6 — Putting it on the internet

### `127.0.0.1` versus `0.0.0.0`

Every machine can talk to itself at **127.0.0.1**, also called **localhost**. Traffic there never
leaves the machine.

**0.0.0.0** means "accept connections on every network interface" — the outside world included.

Your app listens on `127.0.0.1:8000`, deliberately. **Nothing on the internet can reach it
directly.** Only nginx, running on the same machine, can — and nginx decides what gets through.

### nginx, and what a reverse proxy is

**nginx** is a web server. Here it acts as a **reverse proxy**: it takes requests from outside and
forwards them to your app, then passes the answer back.

Why not just let uvicorn face the internet?

1. **Privileged ports.** Web traffic arrives on port 80, and only root may open it. Running your
   Python app as root to achieve that would be far worse than putting nginx in front.
2. **Control.** Upload limits, timeouts, buffering — all configurable in one place.
3. **Room to grow.** One machine can host several apps on one port, routed by domain name.
4. **Robustness.** nginx is designed to absorb slow and malformed connections so your app doesn't
   have to.

Your config:

```nginx
server {
    listen 80;                                    # accept traffic on port 80
    server_name findez.openstack.ftctools.com;    # for this domain

    client_max_body_size 25M;                     # allow uploads up to 25MB

    location / {
        proxy_pass http://127.0.0.1:8000;         # hand off to your app
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
    }
}
```

**`client_max_body_size 25M`** — nginx's default is 1MB. Without this, every photo upload over 1MB
would fail with a confusing error that never reaches your app's logs.

**`proxy_buffering off`** — normally nginx collects the whole response before passing it on. Your
AI chat streams its answer word by word (this is called **SSE**, Server-Sent Events). With
buffering on, the user waits in silence and then gets everything at once. This line keeps it
flowing. It's the same problem the `~1200-byte padding` hack in `routes/ai.py` was working around
on Render.

**`proxy_read_timeout 300s`** — a long AI response can take a while. The default would cut it off.

**The `X-Forwarded-*` headers** — once traffic passes through a proxy, your app sees the *proxy's*
address, not the real visitor's. These headers carry the original details along. Which leads to the
one real bug this move exposed.

### The rate limiting bug

Your app limits `/search_items` to 30 requests per minute **per user**, identified by network
address. Behind nginx, every request appears to come from `127.0.0.1` — so all your users would
share a single limit between them. Ten teams at kickoff would collectively get 30 searches a
minute and constant errors.

`--proxy-headers --forwarded-allow-ips=*` tells uvicorn to trust the `X-Forwarded-For` header and
use the real visitor's address instead. That's why those flags are in the unit file.

**This still needs testing with a real phone.** If searches lock out under normal use, the proper
fix is a one-line change in `backend/app/core/limiter.py`.

---

## Part 7 — The last mile, and where it's stuck

### DNS

**DNS** is the internet's phone book: it turns `findez.openstack.ftctools.com` into
`99.21.70.217`, which is what computers actually route to. This part works — your `curl` resolved
the name correctly.

### Public and private addresses

Your VM has two:

- **99.21.70.217** — public. The street address of your uncle's whole setup.
- **10.20.0.85** — private. Your room number inside it. Anything starting `10.` is private by
  convention and unreachable from the open internet.

Private addresses **can change** when a machine is rebuilt or restarted, unless someone pins them.
That's why "is Caddy still pointing at 10.20.0.85?" is a fair question rather than a silly one.

### HTTPS, TLS and certificates

**HTTPS** is HTTP with encryption. The encryption is **TLS**. A **certificate** is a file proving
a server really owns the domain it claims — issued by a **certificate authority**, and yours comes
from **Let's Encrypt**, which issues them free and automatically.

Your `curl -v` output showed the certificate is valid and issued for exactly your domain. **That
part is already done for you** by Caddy, which is why you never had to set up certificates
yourself.

### Caddy

**Caddy** is a web server, like nginx. Your uncle runs it at the front of his network. It receives
everything arriving for `ftctools.com` and its subdomains, handles the certificates, and forwards
each request to whichever machine should answer.

So there are two reverse proxies in the chain:

```
phone → Caddy (uncle's machine) → nginx (your VM) → uvicorn → your Python code
```

Nothing wrong with that; it's a common shape. Caddy handles the public internet and encryption;
nginx handles the details of your app.

### What 502 means

**502 Bad Gateway** means: *"I'm a proxy, I tried to pass your request along, and the thing behind
me didn't answer."*

So Caddy is fine — it's telling you it couldn't reach the next hop.

And your nginx access log was **completely empty**, which is the decisive clue. Not "requests
arrived and failed" — **no requests arrived at all**.

### Two firewalls, not one

**ufw** is the firewall running *on* your VM. You checked: inactive. Not blocking anything.

An OpenStack **security group** is a firewall that sits *outside* the VM, at the cloud level. The
VM can't see it and turning off ufw doesn't affect it. Port 22 is clearly permitted — you're
SSHing in. Port 80 very likely was never added.

That's the leading theory, and only your uncle can check it.

### How you proved your side was correct

```bash
curl -sI http://10.20.0.85/health
```

Came back `405 Method Not Allowed`. That looks like an error but was the best possible outcome:
`-I` sends a **HEAD** request, your endpoint only accepts **GET**, so your application itself
replied "wrong method." A response like that can only come from your Python code — so the request
travelled nginx → uvicorn → FastAPI and back. **The whole chain inside the VM works.**

And it appeared in the access log, proving logging works. So the empty log genuinely means Caddy
never arrives.

---

## Part 8 — The mistakes, and what they teach

**`No such file or directory` when writing `/etc/systemd/...`** — you were on your Mac, not the VM.
macOS has no systemd. *Read the prompt before every command.*

**Long dashes instead of `--`** — text formatting turned `--host` into `—host`. *Paste into a plain
terminal; if a command fails inexplicably, look closely at the characters.*

**`ModuleNotFoundError: No module named 'app'`** — started from the wrong folder. *Python resolves
imports relative to where it starts.*

**systemd stripping quotes** — different programs parse the same file differently. *If a value has
special characters, quote it.*

**Skipping steps 1–5 and going straight to systemd** — systemd tried to run a program that didn't
exist yet and reported `Result: resources`, which is an unhelpfully vague message for "I can't find
that file." *When an error is vague, check the simplest assumption first: does the thing exist?*

---

## Quick reference

| Term | Meaning |
|---|---|
| **SSH** | Secure way to type commands on a remote computer |
| **Key pair** | Private key (yours, never shared) + public key (goes on servers) |
| **chmod** | Sets who may read/write/run a file. `600` = only you |
| **sudo** | Run this command as administrator |
| **apt** | Ubuntu's package installer |
| **Virtual environment** | Private library folder for one Python project |
| **pip** | Installs Python libraries |
| **Environment variable** | A named value passed to a program at startup |
| **Process** | A running program |
| **systemd** | Linux's service manager — starts, restarts, logs |
| **Unit file** | The config describing a service to systemd |
| **journalctl** | Reads systemd's logs |
| **Port** | A numbered door on a machine. 80 = web, 22 = SSH |
| **localhost / 127.0.0.1** | The machine talking to itself only |
| **0.0.0.0** | Listen on all interfaces, internet included |
| **nginx** | Web server; here, a reverse proxy |
| **Reverse proxy** | Receives requests and forwards them to the real app |
| **DNS** | Turns domain names into IP addresses |
| **TLS / HTTPS** | Encrypted web traffic |
| **Certificate** | Proof a server owns its domain |
| **Let's Encrypt** | Free certificate authority |
| **CORS** | Browser rule about which sites may call your API |
| **SSE** | Server-Sent Events — streaming a response bit by bit |
| **502** | A proxy couldn't reach the thing behind it |
| **405** | The endpoint exists but not for that method |
| **ufw** | Firewall on the machine itself |
| **Security group** | Firewall outside the machine, at the cloud level |

---

## Where things stand

**Done and verified:**

- SSH access with a key
- Code cloned via a read-only deploy key
- Python environment and dependencies installed
- Secrets configured
- Running under systemd, restarts on crash, starts at boot
- Health and database checks passing
- nginx in front with correct upload, streaming and header settings
- Valid TLS certificate on the domain

**Blocked, needs your uncle:**

- Traffic from Caddy reaching the VM on port 80

**Still to do once it's live:**

1. Reboot the VM and confirm everything comes back by itself
2. Point the mobile app at the new address (`mobile/lib/core/config.dart`)
3. Test AI chat on a real phone — check it streams, and check rate limiting behaves
4. Only then, shut down Render
