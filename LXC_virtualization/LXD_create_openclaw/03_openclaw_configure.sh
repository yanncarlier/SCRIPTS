#!/bin/bash
# =============================================================================
# 03_openclaw_configure.sh
# Run INSIDE the VM as the 'openclaw' user (after 02_vm_setup.sh + reboot)
# Configures OpenClaw with computer-use capabilities
# =============================================================================

set -euo pipefail

USER_HOME="/home/openclaw"
OPENCLAW_DIR="${USER_HOME}/.openclaw"
SKILLS_DIR="${OPENCLAW_DIR}/skills"

echo "============================================="
echo " OpenClaw — Computer-Use Configuration"
echo "============================================="

# ── 1. Create OpenClaw skills directory ───────────────────────────────────────
mkdir -p "${SKILLS_DIR}"
mkdir -p "${OPENCLAW_DIR}/memory"

# ── 2. Install the computer-use skill ─────────────────────────────────────────
echo "[*] Installing computer-use skill..."

cat > "${SKILLS_DIR}/computer_use.md" <<'SKILL_EOF'
# Skill: Computer Use (Human-like Mouse & Keyboard Control)

## Description
Allows OpenClaw to control the desktop like a human — move the mouse, click,
type, take screenshots, open applications, and interact with any GUI element.

## Tools Available

### Screenshot
```bash
# Take a full screenshot and save it
scrot /tmp/screenshot.png

# Take screenshot and display info
scrot -v /tmp/screenshot.png && echo "Screenshot saved"

# Screenshot of a specific window
scrot -u /tmp/active_window.png
```

### Mouse Control (xdotool)
```bash
# Move mouse to coordinates
xdotool mousemove 500 400

# Left click
xdotool click 1

# Right click
xdotool click 3

# Double click
xdotool click --repeat 2 1

# Click at specific coordinates
xdotool mousemove 500 400 click 1

# Drag from one point to another
xdotool mousemove 100 100 mousedown 1 mousemove 500 400 mouseup 1
```

### Keyboard Control (xdotool)
```bash
# Type text
xdotool type "Hello World"

# Type with delay between keystrokes (more human-like)
xdotool type --delay 50 "Hello World"

# Press a key
xdotool key Return
xdotool key ctrl+c
xdotool key ctrl+v
xdotool key alt+Tab
xdotool key super   # Windows/Super key

# Key combinations
xdotool key ctrl+shift+t  # new terminal tab
```

### Window Management (wmctrl + xdotool)
```bash
# List all open windows
wmctrl -l

# Focus a window by name
wmctrl -a "Firefox"
wmctrl -a "Google Chrome"

# Get active window title
xdotool getactivewindow getwindowname

# Move window to position
wmctrl -r "Firefox" -e 0,0,0,1280,800

# Get mouse position
xdotool getmouselocation
```

### Open Applications
```bash
# Open Chrome in a normal session
DISPLAY=:0 google-chrome &

# Open Chrome with a specific URL
DISPLAY=:0 google-chrome "https://example.com" &

# Open Chrome in remote debugging mode (for Playwright)
DISPLAY=:0 google-chrome \
  --remote-debugging-port=9222 \
  --no-first-run \
  --no-default-browser-check \
  "https://example.com" &

# Open file manager
DISPLAY=:0 thunar &

# Open terminal
DISPLAY=:0 xfce4-terminal &
```

### Find UI Elements by Screenshot Analysis
```bash
# Take screenshot, then analyze with Claude vision
scrot /tmp/screen.png
# (pass /tmp/screen.png to Claude for element identification)
# Then use the returned coordinates with xdotool
```

## Workflow: Click on a UI Element

1. Take screenshot: `scrot /tmp/screen.png`
2. Analyze screenshot to find element coordinates (use Claude vision)
3. Move and click: `xdotool mousemove X Y click 1`
4. Take another screenshot to verify result

## Workflow: Fill a Form

```bash
# 1. Click the input field
xdotool mousemove 640 400 click 1

# 2. Clear existing content
xdotool key ctrl+a
xdotool key Delete

# 3. Type the value
xdotool type --delay 30 "value to enter"

# 4. Tab to next field
xdotool key Tab
```

## Workflow: Open URL in Chrome

```bash
# If Chrome is already open, focus it and navigate
wmctrl -a "Google Chrome"
xdotool key ctrl+l
sleep 0.3
xdotool type "https://target-url.com"
xdotool key Return
sleep 2
scrot /tmp/after_navigation.png
```

## Environment Variables Required
Always set DISPLAY=:0 when launching GUI apps from scripts/cron:
```bash
export DISPLAY=:0
export XAUTHORITY=/home/openclaw/.Xauthority
```
SKILL_EOF

echo "[*] Computer-use skill installed."

# ── 3. Install the browser automation skill ───────────────────────────────────
echo "[*] Installing browser automation skill (Playwright)..."

# Install Playwright in the openclaw user space
cd "${USER_HOME}"
npm init -y 2>/dev/null || true
npm install playwright

# Install browser binaries (Chromium, Firefox, WebKit)
npx playwright install chromium firefox
npx playwright install-deps chromium firefox

cat > "${SKILLS_DIR}/browser_playwright.md" <<'SKILL_EOF'
# Skill: Browser Control via Playwright

## Description
Programmatic browser control for scraping, form filling, testing, and any
web interaction. More reliable than xdotool for web-specific tasks.

## Quick Scripts

### Open page and take screenshot
```javascript
// save as /tmp/browse.mjs and run with: node /tmp/browse.mjs
import { chromium } from '/home/openclaw/node_modules/playwright/index.mjs';

const browser = await chromium.launch({ headless: false });  // headless:false shows in SPICE
const page = await browser.newPage();
await page.goto('https://example.com');
await page.screenshot({ path: '/tmp/page.png' });
await browser.close();
```

### Fill a form and submit
```javascript
import { chromium } from '/home/openclaw/node_modules/playwright/index.mjs';

const browser = await chromium.launch({ headless: false });
const page = await browser.newPage();

await page.goto('https://target-site.com/login');
await page.fill('#username', 'myuser');
await page.fill('#password', 'mypass');
await page.click('button[type=submit]');
await page.waitForNavigation();
await page.screenshot({ path: '/tmp/after_login.png' });
await browser.close();
```

### Connect to already-open Chrome (remote debugging)
```javascript
import { chromium } from '/home/openclaw/node_modules/playwright/index.mjs';

// Requires Chrome started with --remote-debugging-port=9222
const browser = await chromium.connectOverCDP('http://localhost:9222');
const page = browser.contexts()[0].pages()[0];

// Now control the existing Chrome window
await page.goto('https://new-url.com');
```

## When to Use vs xdotool
- Use Playwright for: web-only tasks, reliable element finding, JS execution, file downloads
- Use xdotool for: desktop apps, non-web GUIs, clicking on anything visible on screen
SKILL_EOF

echo "[*] Playwright skill installed."

# ── 4. Create OpenClaw startup service ────────────────────────────────────────
echo "[*] Creating OpenClaw systemd user service..."

mkdir -p "${USER_HOME}/.config/systemd/user"

cat > "${USER_HOME}/.config/systemd/user/openclaw.service" <<EOF
[Unit]
Description=OpenClaw Personal AI Assistant
After=graphical-session.target network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=DISPLAY=:0
Environment=XAUTHORITY=${USER_HOME}/.Xauthority
Environment=HOME=${USER_HOME}
WorkingDirectory=${USER_HOME}
ExecStart=/usr/bin/openclaw start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

# Enable the service
loginctl enable-linger openclaw 2>/dev/null || true
systemctl --user enable openclaw 2>/dev/null || true

echo "[*] OpenClaw service created."

# ── 5. Create a helper script for manual screenshot+click workflow ─────────────
cat > "${USER_HOME}/computer_use_helper.sh" <<'HELPER_EOF'
#!/bin/bash
# Helper: Take screenshot and print mouse position
# Usage: ./computer_use_helper.sh [screenshot|position|click X Y|type TEXT]

export DISPLAY=:0
export XAUTHORITY=/home/openclaw/.Xauthority

case "$1" in
  screenshot)
    OUTFILE="${2:-/tmp/screenshot_$(date +%s).png}"
    scrot "$OUTFILE"
    echo "Screenshot saved: $OUTFILE"
    ;;
  position)
    xdotool getmouselocation --shell
    ;;
  click)
    xdotool mousemove "$2" "$3" click 1
    echo "Clicked at $2,$3"
    ;;
  rclick)
    xdotool mousemove "$2" "$3" click 3
    echo "Right-clicked at $2,$3"
    ;;
  dclick)
    xdotool mousemove "$2" "$3" click --repeat 2 1
    echo "Double-clicked at $2,$3"
    ;;
  type)
    xdotool type --delay 40 "${2}"
    echo "Typed: ${2}"
    ;;
  key)
    xdotool key "${2}"
    echo "Pressed key: ${2}"
    ;;
  windows)
    wmctrl -l
    ;;
  focus)
    wmctrl -a "${2}"
    echo "Focused: ${2}"
    ;;
  open)
    DISPLAY=:0 "${@:2}" &
    echo "Opened: ${*:2}"
    ;;
  *)
    echo "Usage: $0 {screenshot|position|click X Y|rclick X Y|dclick X Y|type TEXT|key KEY|windows|focus NAME|open APP}"
    ;;
esac
HELPER_EOF

chmod +x "${USER_HOME}/computer_use_helper.sh"

# ── 6. Fix ownership ──────────────────────────────────────────────────────────
chown -R openclaw:openclaw "${USER_HOME}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "============================================="
echo " Configuration complete!"
echo "============================================="
echo ""
echo " Now run OpenClaw onboarding:"
echo "   openclaw onboard"
echo ""
echo " Or start it directly:"
echo "   openclaw start"
echo ""
echo " Computer-use helper:"
echo "   ~/computer_use_helper.sh screenshot"
echo "   ~/computer_use_helper.sh click 500 400"
echo "   ~/computer_use_helper.sh type 'Hello World'"
echo ""
echo " SPICE connection from host:"
echo "   remote-viewer spice://127.0.0.1:5900"
echo ""
