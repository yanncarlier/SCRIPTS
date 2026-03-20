#!/usr/bin/env bash
# 
# Clean up:
# Usage: bash UbuntuCleanUp.sh
#

df -h / /var /home   # Human-readable free space
du -sh /var/lib/snapd   # Snap usage
snap list --all   # See revisions taking space

# sudo snap remove --purge <old-snap>   # e.g., deepseek-r1 if still there
sudo snap set system refresh.retain=2   # Limit old revisions
sudo snap refresh --list   # See pending
snap refresh   # General cleanup
# Remove disabled/old revisions (the biggest win for /snaps — often reclaims several GB)
# This script (from Canonical folks and widely recommended) finds and removes all "disabled" (old/unused) revisions:
#
LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
    sudo snap remove "$snapname" --revision="$revision"
done 

# apt
sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean

# cache
sudo rm -rf ~/.cache/*   # Safe to nuke caches
sudo rm -rf /var/lib/snapd/cache/*

