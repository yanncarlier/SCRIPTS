## 🧠 Memory Management (16GB Swap Setup)

## Recreate Swapfile

```bash
sudo swapoff -a
sudo rm -f /swapfile
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## Enable Persistence

Check current mounts:

```bash
cat /etc/fstab
```

Append this line to `/etc/fstab`:

```text
/swapfile none swap sw 0 0
```

## Optimize Swappiness

Set swappiness to 10 (reduces disk writing):

```bash
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf && sudo sysctl -p
```

------

## ⚙️ System Maintenance & Automation

## Manual Update Command

```bash
sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean && sudo snap refresh
```

## Automated Nightly Cron Job

Check current system cron tasks:

```bash
cat /etc/crontab
```

Add this line to `/etc/crontab` to run updates daily at 3:00 AM:

```text
0 3 * * * root apt update -y && apt upgrade -y && apt autoremove -y && apt clean && snap refresh
```

------

## 🟢 Node.js Management via 'n'

## Installation Steps

```bash
# 1. Install bootstrap Node/NPM
sudo apt update && sudo apt install -y nodejs npm

# 2. Install 'n' manager globally
sudo npm install -g n

# 3. Install latest LTS Node release
sudo n lts

# 4. Purge bootstrap packages to prevent conflicts
sudo apt remove -y nodejs npm && sudo apt autoremove -y

# 5. Relaunch shell and verify
exec bash
node -v
```

## Future Upgrades

To upgrade Node in the future, simply run:

```bash
sudo n lts
```

------

## 🧹 Project Cleanup (Remove Virtual Envs & Node Modules)

## Dry Run (List Targets)

```bash
find . \( -name ".venv" -o -name "node_modules" \) -type d -prune -print
```

## Delete Targets

```bash
find . \( -name ".venv" -o -name "node_modules" \) -type d -prune -exec rm -rf {} +
```

------

## 🎞️ Duplicate Video Finder (`fdupes`)

## Scan and List Duplicates

```bash
fdupes -r Videos/
```

## Delete Duplicates Automatically

*Keeps the first file, deletes the rest without prompting:*

```bash
fdupes -rdN Videos/
```

------

