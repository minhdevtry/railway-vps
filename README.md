# Railway VPS — Ubuntu 24.04 + OpenSSH

[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**English** | [Tiếng Việt](README.vi.md)

Deploy a disposable **Ubuntu 24.04 LTS** box on [Railway](https://railway.com) with **OpenSSH**, reachable over a stable **TCP Proxy**. Ships with a full dev toolchain (Python 3, Node.js, git, tmux, build tools) and can expose an **API server / AI agent** to the internet.

---

## ✨ Features

- **SSH key first** — load `SSH_PUB_KEY` and password authentication is disabled automatically (brute-force proof). The root password stays as a fallback.
- **No default password** — leave `ROOT_PASSWORD` empty and a strong 24-character password is generated on first boot: printed once in the deploy log, persisted across restarts.
- **Stable endpoint** — the Railway TCP Proxy keeps the same host:port across redeploys.
- **Always on** — `restartPolicyType: ALWAYS`, sleep disabled, SSH keep-alive (`ClientAliveInterval 30`).
- **Auto-start apps** — set `START_COMMAND` and your API/agent boots with the container (logs at `/var/log/railway-vps/app.log`).
- **Dev-ready** — Python 3, Node.js LTS, gcc, git, tmux/screen, htop/btop, jq, sqlite3, zsh…

## 🚀 Deploy

1. On Railway: **New Project → Deploy from GitHub repo**, pick this repo.
2. *(Recommended)* In the service **Variables** tab, set `SSH_PUB_KEY` to your public key (`~/.ssh/id_ed25519.pub`) and a strong `ROOT_PASSWORD`.
3. In **Settings → Networking**, add a **TCP Proxy** for port `22` — Railway gives you a stable address like `roundhouse.proxy.rlwy.net:12345`.

## ⚙️ Configuration

| Variable | Default | Description |
| :--- | :---: | :--- |
| `ROOT_PASSWORD` | *(auto-generated)* | Root password for SSH. Empty = generate a strong 24-char password on first boot (see the deploy log) |
| `SSH_PUB_KEY` | *(empty)* | Your SSH public key — **recommended**. Loading a key disables password auth automatically |
| `PASSWORD_AUTH` | `auto` | `yes` / `no` / `auto`. `auto` = disable password auth when an SSH key is loaded |
| `START_COMMAND` | *(empty)* | Command to auto-run on boot, e.g. `uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}` |
| `PORT` | `8080` | Port for the Railway HTTP ingress (public domain) |

## 🔑 Connect via SSH

```bash
ssh root@<TCP_HOST> -p <TCP_PORT>
# e.g.
ssh root@roundhouse.proxy.rlwy.net -p 12345
```

- With an SSH key: you log straight in — no password needed (password auth is off).
- With a password: enter the root password (your `ROOT_PASSWORD`, or the generated one from the first deploy log).

## 🌐 Expose an API server / AI agent

**Automatic (recommended):** set `START_COMMAND`, for example:

```bash
uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
```

The app starts on every boot. Tail its logs over SSH: `tail -f /var/log/railway-vps/app.log`.

**Manual:** SSH in and run it yourself (use `tmux` to keep it alive after you disconnect).

Then **Settings → Networking → Generate Domain** for a public URL (e.g. `vps-production.up.railway.app`) — Railway routes it to your `$PORT`.

> **TCP Proxy vs. public domain:** the domain only routes HTTP to `$PORT`. Raw TCP (SSH, databases, game servers…) goes through TCP Proxy entries — add one per container port under **Settings → Networking**.

Need more than one port? Just add more TCP Proxy entries — each container port gets its own stable public host:port.

## 🔐 Security notes

- Never expose password auth with a weak password to the internet — the entrypoint warns about common ones (`123456`, `password`, …).
- Prefer SSH keys. With `PASSWORD_AUTH=auto` (the default), loading a key turns password auth off entirely.
- The generated password is printed **once** in the deploy log — save it, then set `ROOT_PASSWORD` explicitly.

## ⚠️ Limitations

- This is a **container, not a real VPS**: the filesystem is wiped on redeploy (plain restarts keep it). Persist important data on a Railway Volume or externally.
- Running 24/7 consumes Railway usage credits (billed by RAM×hours) — a cheap dedicated VPS is more economical for an always-on box.

## 📄 License

MIT — see [LICENSE](LICENSE).
