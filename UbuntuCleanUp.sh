#!/usr/bin/env bash
# 
# Clean up:
# Usage: bash UbuntuCleanUp.sh
#

# All directories (hidden + normal) — most useful
du -sh .[^.]* * | sort -h
# Quick one-liner (very popular)
du -ahd1 | sort -h


df -h / /var /home   # Human-readable free space
du -sh /var/lib/snapd   # Snap usage
snap list --all   # See revisions taking space

# apt
sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt clean

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

# cache
sudo rm -rf ~/.cache/*   # Safe to nuke caches
sudo rm -rf /var/lib/snapd/cache/*




# Quick & Safe Clean (Recommended first step)
# cd ~
# ./gradlew --stop          # Stop any running Gradle daemon
rm -rf ~/.gradle/caches/  # This removes the biggest part


#Even more aggressive clean
rm -rf ~/.gradle/caches/
rm -rf ~/.gradle/wrapper/dists/   # Old Gradle versions

#Nuclear option (if you don't mind redownloading everything)
rm -rf ~/.gradle


find ~/.gradle/caches -type f -atime +30 -delete   # Delete files not accessed in 30 days

du -sh ~/.config/* | sort -hr | head -n 20

# VS Code
rm -rf ~/.config/Code/CachedData/
rm -rf ~/.config/Code/Cache/
rm -rf ~/.config/Code/Service Worker/

# Discord
rm -rf ~/.config/discord/Cache/
rm -rf ~/.config/discord/Code Cache/


rm -rf ~/.local/share/Trash/*





du -sh ~/.cache/* | sort -hr | head -15




rm -rf ~/.cache/thumbnails/*
rm -rf ~/.cache/mozilla/firefox/*/cache2/
rm -rf ~/.cache/google-chrome/Default/Cache/
rm -rf ~/.cache/Code/Cache/



cd ~/android-sdk
du -sh * | sort -hr
du -sh system-images/*/*/* | sort -hr   # This will show the real space hogs


cd ~/android-sdk

# 1. Remove old NDK versions (keep only the newest)
du -sh ndk/*
rm -rf ndk/27.0.12077973/
rm -rf ndk/28.2.13676358/
# Keep ndk/29.0.13113456 (or the newest one)

# 2. Remove old platforms (you only need recent ones)
du -sh platforms/*
rm -rf platforms/android-34/
rm -rf platforms/android-35/
# Keep platforms/android-36 if you're using it

# 3. Remove old build-tools
rm -rf build-tools/34.0.0/
rm -rf build-tools/35.0.0/


~/android-sdk/cmdline-tools/latest/bin/sdkmanager --update







du -sh ~/.local/share/* | sort -hr | head -20


# 1. Empty the Trash (often several GB)
rm -rf ~/.local/share/Trash/*

# 2. Clean JetBrains IDE caches (very common)
rm -rf ~/.local/share/JetBrains/*/caches/
rm -rf ~/.local/share/JetBrains/*/log/
rm -rf ~/.local/share/JetBrains/*/tmp/

# 3. General safe cleanup
rm -rf ~/.local/share/*.old
rm -rf ~/.local/share/Trash/files/*






# 1. Remove the broken installation
rm -rf ~/.local/share/pnpm

# 2. Reinstall pnpm (official way)
curl -fsSL https://get.pnpm.io/install.sh | sh -

# 3. Restart your terminal or run:
source ~/.bashrc   # or ~/.zshrc if you use zsh


pnpm store prune


du -sh ~/.local/share/* | sort -hr | head -12



















