# vbc-stats-api

VirBiCoin Network Intelligence API — the reporter agent that runs next to a
VirBiCoin node, reads chain data over JSON-RPC, and feeds it to a
[vbc-stats](https://github.com/virbicoin/vbc-stats) dashboard over WebSockets.

This is a fork of
[eth-net-intelligence-api](https://github.com/cubedro/eth-net-intelligence-api),
updated so its WebSocket client (Primus) matches the version used by the
current vbc-stats server.

> **Why this fork exists:** vbc-stats runs **Primus 8 / ws 8**. The upstream
> agent shipped **Primus 4 / ws 1**, and the two major versions are not
> wire-compatible — most connections were dropped before they could
> authenticate, so reporters kept reconnecting and their node appeared stuck at
> an old block. This fork bumps the client to Primus 8 / ws 8 to fix that.

Use this agent for nodes whose client does **not** have a built-in ethstats
reporter (e.g. OpenVirBiCoin / Ovbc). VirBiCoin's Go client (Gvbc) already
reports directly and does not need this agent.

## Prerequisites

- A running VirBiCoin node (Gvbc or Ovbc) exposing JSON-RPC
- Node.js 20+
- npm

## Installation

```bash
git clone https://github.com/virbicoin/vbc-stats-api.git
cd vbc-stats-api
npm install
```

## Configuration

The agent is configured through environment variables. The important ones:

| Variable          | Description                                              |
| ----------------- | ------------------------------------------------------- |
| `RPC_HOST`        | Node JSON-RPC host (e.g. `localhost`)                    |
| `RPC_PORT`        | Node JSON-RPC port (e.g. `8329`)                         |
| `LISTENING_PORT`  | Node P2P port (display only)                             |
| `INSTANCE_NAME`   | The node name shown on the dashboard                     |
| `CONTACT_DETAILS` | Optional contact info                                   |
| `WS_SERVER`       | vbc-stats server URL (e.g. `wss://stats.virbicoin.com`) |
| `WS_SECRET`       | Shared secret — must match the vbc-stats `WS_SECRET`     |
| `VERBOSITY`       | Log level: `0` silent … `3` all logs                    |

> **Security:** `WS_SECRET` is a credential. Keep it out of version control and
> avoid pasting it into logs or chats. Rotate it if it leaks.

## Run

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
StartLimitIntervalSec=300
StartLimitBurst=20

[Install]
WantedBy=multi-user.target
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vbc-stats-api
```

## Compatibility

| Component | Version                                        |
| --------- | ---------------------------------------------- |
| Primus    | 8.x (matches the vbc-stats server)             |
| ws        | 8.x                                            |
| web3      | 0.x (legacy JSON-RPC client used by the agent) |

## License

LGPL-3.0 (inherited from the upstream project). See [LICENSE](LICENSE).
