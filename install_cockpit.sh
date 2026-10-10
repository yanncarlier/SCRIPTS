#!/bin/bash


# Man
# https://github.com/copilot
# https://github.com/features/copilot/cli
# https://cockpit-project.org/running.html#ubuntu  
# . /etc/os-release
# sudo apt install -t ${VERSION_CODENAME}-backports cockpit
# or
# curl -fsSL https://gh.io/copilot-install | bash
# sudo apt install pcp python3-pcp
# sudo ufw allow from xx.xx.xx.xx/xx to any port 9090


# Auto
# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Updating package lists ==="
sudo apt-get update

echo "=== Installing Cockpit ==="
sudo apt-get install -y cockpit

echo "=== Starting and enabling Cockpit service ==="
sudo systemctl enable --now cockpit.socket

echo "=== Opening firewall port 9090 (if ufw is active) ==="
if sudo ufw status | grep -q "Status: active"; then
    sudo ufw allow 9090/tcp
    sudo ufw reload
fi

# Get the server's primary IP address
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "=== Installation Complete! ==="
echo "You can access the Cockpit dashboard by visiting:"
echo "https://${SERVER_IP}:9090"
echo "Log in using your standard Ubuntu system username and password."
