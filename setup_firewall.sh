#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Resetting UFW to default settings ==="
sudo ufw --force reset

echo "=== Setting default policies ==="
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "=== Applying custom IPv4 rules ==="
# Allow Cockpit (9090) only from the 192.168.3.0/24 subnet (I know I shuld not expose this yet I have nothing of value, don't waste your time.
sudo ufw allow from 192.168.3.0/24 to any port 9090 proto tcp

# Allow SSH (22) only from the 192.168.3.0/24 subnet
sudo ufw allow from 192.168.3.0/24 to any port 22 proto tcp

echo "=== Applying custom IPv6 blocking rules ==="
# Block all incoming IPv6 traffic
sudo ufw deny proto ipv6 from any to any

# Block all outgoing IPv6 traffic
sudo ufw deny out proto ipv6 from any to any

echo "=== Enabling UFW ==="
sudo ufw --force enable

echo "=== Final Firewall Status ==="
sudo ufw status verbose
