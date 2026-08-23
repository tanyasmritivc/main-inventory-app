# What we used — migration reference

Everything involved in moving FindEZ off Render and Vercel and building a fully self-hosted
application and Supabase stack, August 2026. Written so it can be answered from quickly.

---

## The thirty-second answer

> We moved the backend off Render and the Next.js website off Vercel onto an Ubuntu VM, and
> stood up self-hosted Supabase alongside them. Supabase is open source, so it's the same
> software — PostgreSQL, PostgREST, GoTrue, Kong — running on our own machine in Docker. The
> app needed no data-layer changes because it talks to PostgREST either way. Everything is
> backed up nightly with restore verification.

---

## Infrastructure

| | What it does |
|---|---|
| **Ubuntu 24.04.4 LTS** | The VM's operating system |
| **OpenStack** | The virtualisation platform the VM runs on |
| **Docker + Docker Compose** | Runs the eleven Supabase containers |
| **systemd** | Runs the backend and Next.js web app as services; runs the nightly backup timer |
| **nginx** | Reverse proxy on the VM, ports 80 and 443, in front of the backend and website |
| **Caddy** | Edge proxy on the wider network. Terminates TLS, routes by hostname |
| **UniFi** | Network gear doing the port forwarding into Caddy |
| **OpenSSH** | Remote access, and the deploy key for pulling the repo |
| **Let's Encrypt** | The public TLS certificates, issued automatically by Caddy |
| **OpenSSL** | Self-signed cert for the internal hop; generating secrets |

## Database

| | |
|---|---|
| **PostgreSQL 17.6** | The database itself, both on Supabase and self-hosted |
| **pg_dump / pg_restore / psql** | Dumping and restoring. Client 17 required to match the server |
| **PGDG apt repository** | Ubuntu 24.04 only ships client 16, so PostgreSQL's own repo was added |

## The self-hosted Supabase stack — all open source

Supabase publishes its whole platform. These are the eleven containers:

| Component | Version | Role |
|---|---|---|
| **PostgreSQL** | `supabase/postgres:17.6.1.136` | The database |
| **PostgREST** | `v14.12` | Turns the database into a REST API. **This is what `supabase-py` actually talks to** — the reason no data-layer code had to change |
| **GoTrue** | `v2.189.0` | Authentication. Accounts, passwords, Google and Apple sign-in, tokens |
| **Kong** | `3.9.3` | API gateway. Everything enters through it; enforces the API key |
| **Storage API** | `v1.60.4` | File uploads and downloads |
| **Supavisor** | `2.9.5` | Connection pooler |
| **Realtime** | `v2.102.3` | Live subscriptions (unused by FindEZ) |
| **postgres-meta** | `v0.96.6` | Powers the Studio dashboard |
| **Studio** | `2026.08.03` | The web dashboard |
| **Edge Runtime** | `v1.74.0` | Deno functions runtime (unused) |
| **imgproxy** | `v3.30.1` | Image transformation |

## Backups

Custom shell script driven by a **systemd timer**, using `pg_dump` (custom format) and
`tar`/`gzip`. Verified by restoring into a throwaway container and comparing row counts, not
by checking a file exists. Failure surfaces in the SSH login banner via `pam_motd`.

**restic** to Backblaze B2 or S3 is the recommended off-machine backup — **recommended, not
implemented.** Everything currently sits on one disk.

## External services still in use

| | |
|---|---|
| **Supabase Cloud** (free tier) | Read-only migration source, fallback, and temporary off-machine copy |
| **GitHub** | The repository |
| **OpenAI** (`gpt-4o`, `gpt-4o-mini`) | The app's AI features |
| **Stripe** | Payments |

Render and Vercel are retired as production hosts. Their old accounts may remain during the
migration cleanup, and `findez.ai` may continue resolving to Vercel until its DNS is moved.

## AI tooling used to do the work

| | |
|---|---|
| **Claude** | Codebase audit, documentation, reviewing every plan before it ran |
| **OpenCode** | Open-source terminal coding agent. Did most of the VM work |
| **DeepSeek V4 Flash 0731** | The model behind OpenCode, self-hosted on 4× RTX 6000 Blackwell and reached through a private gateway |
| **Windsurf** | The Flutter and backend lane, kept separate by directory |

---

## Questions you'll actually get asked

**"Aren't you still using Supabase?"**
Supabase is open-source software, not just a hosted service. We run the identical software
on our own machine. Nobody else is involved and there's no bill.

**"Why not just PostgreSQL on its own?"**
Because Supabase is PostgreSQL *plus* four things the app depends on — a REST API, an auth
system, file storage, and a gateway. Plain PostgreSQL would mean rewriting 149 database
calls and building our own login system from scratch. We actually tried plain PostgreSQL
first; the data restored fine but nothing could use it.

**"What did the migration cost?"**
Nothing in money — we were on Supabase's free tier and using about 0.3% of it. It cost time,
and it was done while there were no real users, which is when it's cheapest.

**"What's the risk now?"**
One machine, one disk. Backups exist and are restore-tested, but they live on that same
disk, so it's protection against mistakes rather than hardware failure. Cloud Supabase stays
alive as the real second copy until off-machine backups exist.
