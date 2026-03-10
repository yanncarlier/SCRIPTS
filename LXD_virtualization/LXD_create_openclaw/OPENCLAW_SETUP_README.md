# OpenClaw — LXD VM + SPICE + Full Computer-Use Setup

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   YOUR UBUNTU HOST                       │
│                                                          │
│   ┌─────────────────────────────────────────────────┐   │
│   │          LXD VM  "openclaw"                      │   │
│   │          Ubuntu 25.10 Desktop (questing)         │   │
│   │                                                  │   │
│   │  ┌──────────────┐   ┌─────────────────────────┐ │   │
│   │  │  XFCE Desktop│   │  OpenClaw (Node.js CLI) │ │   │
│   │  │  auto-login  │   │  runs as systemd service │ │   │
│   │  └──────┬───────┘   └────────────┬────────────┘ │   │
│   │         │                        │               │   │
│   │  ┌──────▼───────────────────────▼────────────┐  │   │
│   │  │           Input/Vision Layer               │  │   │
│   │  │  xdotool  │  scrot  │  wmctrl  │ Playwright│  │   │
│   │  └───────────────────────────────────────────┘  │   │
│   │                                                  │   │
│   │  ┌───────────────────────────────────────────┐  │   │
│   │  │  Google Chrome + Chromium (headful)        │  │   │
│   │  │  remote-debugging-port=9222                │  │   │
│   │  └───────────────────────────────────────────┘  │   │
│   │                                                  │   │
│   │  ┌───────────────────────────────────────────┐  │   │
│   │  │  SPICE Server  (port 5900, localhost only) │  │   │
│   │  │  QXL video + spice-vdagent                │  │   │
│   │  └───────────────────────────────────────────┘  │   │
│   └─────────────────────────────────────────────────┘   │
│                        │ SPICE                           │
│              ┌──────────▼──────────┐                     │
│              │  remote-viewer /    │                     │
│              │  virt-viewer        │                     │
│              │  (you watch here)   │                     │
│              └─────────────────────┘                     │
└─────────────────────────────────────────────────────────┘
                          │ Internet
                   WhatsApp / Telegram
                   Claude API / OpenAI
```

---

## Prerequisites (Host)

```bash
sudo apt install lxd virt-viewer
sudo lxd init --auto   # if not already done
```

---

## Step-by-Step

### Step 1 — Run on HOST
```bash
chmod +x 01_host_create_vm.sh
./01_host_create_vm.sh
```
Creates the VM, configures SPICE on port 5900, pushes the next script into the VM.

---

### Step 2 — Run INSIDE the VM
```bash
# Option A: exec directly from host
lxc exec openclaw -- bash /root/02_vm_setup.sh

# Option B: connect via SPICE first, open terminal, then run
bash /root/02_vm_setup.sh
```

Installs: XFCE + LightDM auto-login, SPICE guest agent, xdotool/wmctrl/scrot,
Google Chrome, Node.js LTS, pnpm, and OpenClaw. VM reboots automatically.

---

### Step 3 — Connect via SPICE (from host)
```bash
remote-viewer spice://127.0.0.1:5900
```
You will see the XFCE desktop auto-logged in as the `openclaw` user.

---

### Step 4 — Configure OpenClaw (inside VM)
```bash
# Option A: exec directly from host
lxc exec openclaw -- bash /root/03_openclaw_configure.sh

# Option B: connect via SPICE first, open terminal, then run
bash /root/03_openclaw_configure.sh
```
Installs computer-use skill, Playwright browser skill, and the systemd user service.

---

### Step 5 — Onboard OpenClaw
```bash
openclaw onboard
```
Set your API key, connect your chat app, name your assistant.

---

## How OpenClaw Controls the Desktop

### Screenshot
```bash
~/computer_use_helper.sh screenshot /tmp/screen.png
```

### Click at coordinates
```bash
~/computer_use_helper.sh click 640 400
```

### Type text
```bash
~/computer_use_helper.sh type "Hello from OpenClaw"
```

### Open Chrome to a URL
```bash
DISPLAY=:0 google-chrome "https://example.com" &
```

### Playwright browser control
```javascript
// /tmp/task.mjs
import { chromium } from '/home/openclaw/node_modules/playwright/index.mjs';
const browser = await chromium.launch({ headless: false });
const page = await browser.newPage();
await page.goto('https://gmail.com');
await page.screenshot({ path: '/tmp/gmail.png' });
await browser.close();
```

---

## Anthropic Computer-Use Style Loop

1. **See** — `scrot /tmp/screen.png` → pass to Claude vision
2. **Think** — Claude identifies what to click/type next
3. **Act** — `xdotool` executes the action
4. **Repeat** — loop until task is complete

Works for ANY desktop app visible in the SPICE window.

---

## Useful Commands

```bash
# Watch OpenClaw logs live
lxc exec openclaw -- journalctl -u openclaw -f

# Shell as openclaw user
lxc exec openclaw -- sudo -u openclaw bash

# Restart OpenClaw
lxc exec openclaw -- systemctl --user restart openclaw

# Pause/resume VM
lxc pause openclaw && lxc start openclaw
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| SPICE black screen | Wait 30s; check `systemctl status lightdm` inside VM |
| xdotool not found | `apt install xdotool` inside VM |
| Chrome won't open | Try `DISPLAY=:0 google-chrome --no-sandbox` |
| OpenClaw not receiving messages | Check API key with `openclaw config` |
| VM too slow | Increase CPUs/RAM in `01_host_create_vm.sh` |
