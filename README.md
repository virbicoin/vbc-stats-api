<p align="center">
  <img src="public/VBC.svg" alt="VirBiCoin Logo" width="120" height="120">
</p>

<h1 align="center">VBC Stats API</h1>

<p align="center">
  <strong>VirBiCoin Network Intelligence API — Node Reporter Agent for VBC Stats</strong>
</p>

<p align="center">
  <a href="https://stats.virbicoin.com">
    <img src="https://img.shields.io/badge/Dashboard-stats.virbicoin.com-cyan?style=for-the-badge&logo=google-chrome&logoColor=white" alt="Dashboard">
  </a>
  <a href="https://explorer.virbicoin.com">
    <img src="https://img.shields.io/badge/Explorer-Live-green?style=for-the-badge&logo=ethereum&logoColor=white" alt="Explorer">
  </a>
  <a href="https://discord.virbicoin.com">
    <img src="https://img.shields.io/badge/Discord-Join-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Node.js-≥20-339933?style=flat-square&logo=node.js&logoColor=white" alt="Node.js">
  <img src="https://img.shields.io/badge/Primus-8-purple?style=flat-square" alt="Primus">
  <img src="https://img.shields.io/badge/web3-0.x-F16822?style=flat-square&logo=web3dotjs&logoColor=white" alt="web3">
  <a href="https://opensource.org/licenses/LGPL-3.0">
    <img src="https://img.shields.io/badge/License-LGPL--3.0-yellow?style=flat-square" alt="License: LGPL-3.0">
  </a>
</p>

---

## 📑 Table of Contents

- [About](#-about)
- [Features](#-features)
- [Quick Start](#-quick-start)
- [Configuration](#-configuration)
- [Run](#-run)
- [Compatibility](#-compatibility)
- [Security](#-security)
- [Related Repositories](#-related-repositories)
- [Community](#-community)
- [License](#-license)

---

## ⛓️ About

**VBC Stats API** is the reporter agent that runs next to a VirBiCoin node,
reads chain data over JSON-RPC, and feeds it to the
[VBC Stats](https://github.com/virbicoin/vbc-stats) dashboard over WebSockets.

It is a fork of
[eth-net-intelligence-api](https://github.com/cubedro/eth-net-intelligence-api),
updated so its WebSocket client (Primus) matches the version used by the current
VBC Stats server.

> **Why this fork exists:** VBC Stats runs **Primus 8 / ws 8**. The upstream
> agent shipped **Primus 4 / ws 1**, and the two major versions are not
> wire-compatible — most connections were dropped before they could
> authenticate, so reporters kept reconnecting and their node appeared stuck at
> an old block. This fork bumps the client to Primus 8 / ws 8 to fix that.

Use this agent for nodes whose client does **not** have a built-in ethstats
reporter (e.g. OpenVirBiCoin / Ovbc). VirBiCoin's Go client (Gvbc) already
reports directly and does not need this agent.

## ✨ Features

- 📡 **Node Reporting** — Pushes block, pending, and stats data to VBC Stats
- 🔌 **Primus 8 WebSocket** — Matches the current VBC Stats server protocol
- ♻️ **Auto Reconnect** — Recovers the WebSocket link without manual restart
- 🔐 **Shared-Secret Auth** — Authenticates with the dashboard via `WS_SECRET`
- ⚙️ **Env-based Config** — Configure entirely through environment variables

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/virbicoin/vbc-stats-api.git
cd vbc-stats-api

# Install dependencies
npm install

# Start the agent (configure env vars first — see below)
npm start
```

## 🔧 Configuration

The agent is configured through environment variables:

| Variable          | Description                                              |
| ----------------- | ------------------------------------------------------- |
| `RPC_HOST`        | Node JSON-RPC host (e.g. `localhost`)                    |
| `RPC_PORT`        | Node JSON-RPC port (e.g. `8329`)                         |
| `LISTENING_PORT`  | Node P2P port (display only)                             |
| `INSTANCE_NAME`   | The node name shown on the dashboard                     |
| `CONTACT_DETAILS` | Optional contact info                                   |
| `WS_SERVER`       | VBC Stats server URL (e.g. `wss://stats.virbicoin.com`) |
| `WS_SECRET`       | Shared secret — must match the VBC Stats `WS_SECRET`     |
| `VERBOSITY`       | Log level: `0` silent … `3` all logs                    |

> **Security:** `WS_SECRET` is a credential. Keep it out of version control and
> avoid pasting it into logs or chats. Rotate it if it leaks.

## 🏃 Run

### With pm2

```bash
pm2 start app.json
```

### With systemd

Create `/etc/systemd/system/vbc-stats-api.service`:

```ini
[Unit]
Description=VirBiCoin Netstats Client
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=20

[Service]
Type=simple
User=youruser
WorkingDirectory=/home/youruser/vbc-stats-api
Environment=RPC_HOST=localhost
Environment=RPC_PORT=8329
Environment=LISTENING_PORT=28329
Environment=INSTANCE_NAME=My-Node
Environment=CONTACT_DETAILS=
Environment=WS_SERVER=wss://stats.virbicoin.com
Environment=WS_SECRET=your_shared_secret
Environment=VERBOSITY=2
ExecStart=/usr/bin/node /home/youruser/vbc-stats-api/app.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vbc-stats-api
```

## 🔗 Compatibility

| Component | Version                                        |
| --------- | ---------------------------------------------- |
| Primus    | 8.x (matches the VBC Stats server)             |
| ws        | 8.x                                            |
| web3      | 0.x (legacy JSON-RPC client used by the agent) |
| Node.js   | ≥ 20                                           |

## 🔒 Security

- `WS_SECRET` is a shared credential — never commit it; configure it via env vars.
- `app.json` ships with placeholder values only; keep real secrets out of git.
- Rotate `WS_SECRET` on the server and every reporter if it is ever exposed.

## 📦 Related Repositories

| Repository                     | Role                                     | URL                                                          |
| ------------------------------ | ---------------------------------------- | ------------------------------------------------------------ |
| **virbicoin.com**              | Official website                         | [github.com/virbicoin/virbicoin.com](https://github.com/virbicoin/virbicoin.com) |
| **go-virbicoin**               | Main client (Gvbc, Go)                   | [github.com/virbicoin/go-virbicoin](https://github.com/virbicoin/go-virbicoin) |
| **open-virbicoin**             | Rust client (Ovbc)                       | [github.com/virbicoin/open-virbicoin](https://github.com/virbicoin/open-virbicoin) |
| **vbc-stats**                  | Network statistics dashboard             | [github.com/virbicoin/vbc-stats](https://github.com/virbicoin/vbc-stats) |
| **vbc-stats-api** ← this repo  | Node reporter agent for VBC Stats        | [github.com/virbicoin/vbc-stats-api](https://github.com/virbicoin/vbc-stats-api) |
| **vbc-explorer**               | Blockchain explorer                      | [github.com/virbicoin/vbc-explorer](https://github.com/virbicoin/vbc-explorer) |
| **vbc-pool**        | Mining pool                              | [github.com/virbicoin/vbc-pool](https://github.com/virbicoin/vbc-pool) |
| **vbc-rpc**                    | RPC node status & JSON-RPC proxy         | [github.com/virbicoin/vbc-rpc](https://github.com/virbicoin/vbc-rpc) |

## 💬 Community

<p>
  <a href="https://discord.virbicoin.com">
    <img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord">
  </a>
  <a href="https://x.com/VirBiCoin">
    <img src="https://img.shields.io/badge/X_(Twitter)-000000?style=for-the-badge&logo=x&logoColor=white" alt="X">
  </a>
  <a href="https://bitcointalk.org/index.php?topic=5546988.0">
    <img src="https://img.shields.io/badge/Bitcointalk-F7931A?style=for-the-badge&logo=bitcoin&logoColor=white" alt="Bitcointalk">
  </a>
  <a href="https://coinpaprika.com/coin/vbc-virbicoin/">
    <img src="https://img.shields.io/badge/CoinPaprika-00d4aa?style=for-the-badge" alt="CoinPaprika">
  </a>
</p>

## 📄 License

LGPL-3.0 (inherited from the upstream project) — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with ❤️ by the VirBiCoin Team</sub>
</p>
