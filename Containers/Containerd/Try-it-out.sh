#!/usr/bin/env bash
# Basic nerdctl usage demo. Run from the folder containing the Dockerfile.
set -euo pipefail

# Run a throwaway container (pulls the image automatically)
sudo nerdctl run --rm hello-world

# Run nginx in the background, mapping host port 8080 -> container port 80
sudo nerdctl run -d --name web -p 8080:80 nginx:alpine
curl -s http://localhost:8080 | head -n 5

# List running containers, view logs, open a shell inside
sudo nerdctl ps
sudo nerdctl logs web
sudo nerdctl exec web echo "hello from inside the container"

# Stop and remove it
sudo nerdctl stop web
sudo nerdctl rm web

# Build your own image from the Dockerfile below, then run it
sudo nerdctl build -t my-app:1.0 .
sudo nerdctl run --rm my-app:1.0

# Compose works too (uses compose.yaml below)
sudo nerdctl compose up -d
sudo nerdctl compose ps
sudo nerdctl compose down

# Images and cleanup
sudo nerdctl images
sudo nerdctl system prune -f