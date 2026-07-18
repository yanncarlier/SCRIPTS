

```
sudo apt-get remove -y docker docker-engine docker.io containerd runc
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-images
sudo apt-get autoremove -y --purge


sudo apt-get update
sudo apt-get install -y podman

echo "alias docker=podman" >> ~/.bashrc
source ~/.bashrc

# Start the Podman API service for your user account
systemctl --user enable --now podman.socket

# Export the environment variable telling Docker Compose where to look
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock


docker compose up

```


```

sudo apt-get update
sudo apt-get install -y podman podman-docker podman-compose


# Run your multi-container application
podman-compose up -d


```