# BTCPayServer — LXD VM Setup on Ubuntu (Canonical LXD + Docker)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      YOUR UBUNTU HOST                            │
│                                                                  │
│  Port :80  ──┐                                                   │
│  Port :443 ──┤ LXD NAT proxy devices                            │
│  Port :8333──┘                                                   │
│        │                                                         │
│   ┌────▼────────────────────────────────────────────────────┐   │
│   │             LXD VM  "btcpayserver"                       │   │
│   │             Ubuntu 25.10 (questing) — server             │   │
│   │                                                          │   │
│   │  ┌───────────────────────────────────────────────────┐  │   │
│   │  │  nginx container  (:80 / :443)  TLS + proxy        │  │   │
│   │  └───────────────────────┬───────────────────────────┘  │   │
│   │                          │ Docker network                │   │
│   │  ┌───────────────────────▼───────────────────────────┐  │   │
│   │  │  BTCPayServer container                            │  │   │
│   │  └───────────────────────┬───────────────────────────┘  │   │
│   │                          │                               │   │
│   │  ┌───────────────────────▼───────────────────────────┐  │   │
│   │  │  NBXplorer container  (Bitcoin indexer)            │  │   │
│   │  └───────────────────────┬───────────────────────────┘  │   │
│   │                          │                               │   │
│   │  ┌───────────────────────▼───────────────────────────┐  │   │
│   │  │  Bitcoin Core container  (pruned ~25 GB)           │  │   │
│   │  └───────────────────────────────────────────────────┘  │   │
│   │                                                          │   │
│   │  All managed by: btcpayserver-docker (official)          │   │
│   │  UFW firewall: allow 22, 80, 443, 8333 only              │   │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites (Host)

```bash
sudo apt install lxd
sudo lxd init --auto   # if not already done
```

---

## Fresh Install — Step by Step

### Step 0 — Destroy old VM (if starting fresh)

```bash
lxc stop btcpayserver --force 2>/dev/null || true
lxc delete btcpayserver 2>/dev/null || true
```

---

### Step 1 — Run on HOST
```bash
chmod +x 01_host_create_vm.sh
sudo ./01_host_create_vm.sh
```

Creates the VM with:
- 60 GB disk, 4 CPU, 8 GB RAM
- LXD NAT proxy forwarding ports 80, 443, 8333
- UFW bridge rules so the VM gets DHCP and internet

---

### Step 2 — Run INSIDE the VM
```bash
# From host:
lxc exec btcpayserver -- bash /root/02_vm_setup.sh
```

Installs: git, curl, unzip, nginx, certbot, UFW and all system dependencies.

---

### Step 3 — Configure and deploy (inside VM)

**Before running**, edit the top variables in `03_btcpayserver_configure.sh`:

| Variable | Default | Notes |
|---|---|---|
| `BTCPAY_HOST` | `""` | Your domain for TLS e.g. `pay.example.com`. Leave blank to use IP + HTTP only. |
| `NBITCOIN_NETWORK` | `mainnet` | Use `testnet` to test without real Bitcoin |
| `LIGHTNING` | `""` | Set `lnd` or `clightning` to add Lightning. Leave blank to skip. |
| `STORAGE_FRAGMENT` | `opt-save-storage` | Pruned node (~25 GB chain). Safe for 60 GB disk. |

```bash
# Push from host and run:
lxc file push 03_btcpayserver_configure.sh btcpayserver/root/03_btcpayserver_configure.sh
lxc exec btcpayserver -- bash /root/03_btcpayserver_configure.sh
```

This will:
1. Install Docker (official Docker CE, not snap)
2. Clone the official `btcpayserver-docker` repo
3. Run `btcpay-setup.sh -i` — pulls all images, wires everything up, installs systemd services
4. Configure UFW firewall
5. Install disk watchdog cron (alerts if < 8 GB free)

Image pulling takes **5–15 minutes** depending on connection speed.

---

### Step 4 — Create your admin account

Get the VM's IP:
```bash
lxc exec btcpayserver -- hostname -I
```

Open in browser:
```
http://<VM-IP>               # if BTCPAY_HOST was left blank
https://pay.yourdomain.com   # if BTCPAY_HOST was set
```

**Create your admin account immediately.** The registration page is only open until the first account is created — it closes permanently after that.

---

## Day-to-Day Management

```bash
# Shell into VM
lxc exec btcpayserver -- bash

# Container status
docker ps

# Live BTCPayServer logs
docker logs generated_btcpayserver_1 -f

# Bitcoin sync progress
docker exec generated_bitcoind_1 bitcoin-cli getblockchaininfo

# Stop / start / restart all containers
btcpay-stop.sh
btcpay-start.sh
btcpay-restart.sh

# Update to latest BTCPayServer version
btcpay-update.sh

# Backup
btcpay-backup.sh
```

---

## Enable TLS Later (when you have a domain)

DNS A record must point to your server's public IP first. Then inside the VM:

```bash
export BTCPAY_HOST="pay.yourdomain.com"
cd /opt/btcpayserver/btcpayserver-docker
. ./btcpay-setup.sh -i
```

The nginx container handles Let's Encrypt automatically — no certbot needed separately.

---

## Add Lightning Network Later

```bash
# Inside VM
export BTCPAYGEN_LIGHTNING="lnd"
cd /opt/btcpayserver/btcpayserver-docker
. ./btcpay-setup.sh -i

# Open Lightning port
ufw allow 9735/tcp comment 'Lightning P2P'
```

From the host, add LXD proxy:
```bash
lxc config device add btcpayserver lightning proxy \
  listen=tcp:0.0.0.0:9735 connect=tcp:127.0.0.1:9735 nat=true
```

---

## Disk Space

| Component | Size |
|---|---|
| Ubuntu OS | ~5 GB |
| Docker + images | ~8 GB |
| Bitcoin pruned chain (`opt-save-storage`) | ~25 GB |
| NBXplorer index | ~5–8 GB |
| BTCPayServer data | ~2 GB |
| **Total** | **~45–48 GB** |
| **Headroom on 60 GB VM** | **~12–15 GB** |

Monitor:
```bash
lxc exec btcpayserver -- df -h /
lxc exec btcpayserver -- docker system df
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| VM has no IP after boot | `lxc exec btcpayserver -- networkctl renew enp5s0` |
| No internet inside VM | On host: `ufw allow in on lxdbr0 && ufw route allow in on lxdbr0 && ufw route allow out on lxdbr0` |
| `docker ps` shows no containers | Run `btcpay-start.sh` inside VM |
| nginx 502 Bad Gateway | Containers still starting — wait 2 min, check `docker ps` |
| Bitcoin stuck at 0% | Normal — initial sync takes hours/days on mainnet |
| Disk full warning | `docker system prune` to remove old images |
| Port 80/443 unreachable from host | Check: `lxc config device show btcpayserver` |

---

## Useful One-Liners

```bash
# Snapshot VM before updates (from host)
lxc snapshot btcpayserver pre-update-$(date +%Y%m%d)
lxc restore  btcpayserver pre-update-<date>   # rollback

# Pause VM to free host RAM
lxc pause btcpayserver
lxc start btcpayserver

# VM resource usage
lxc info btcpayserver

# See all running containers inside VM
lxc exec btcpayserver -- docker ps

# Hard reset — nuke and start over
lxc stop btcpayserver --force && lxc delete btcpayserver
sudo ./01_host_create_vm.sh
```
