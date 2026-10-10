


Run it with 
```
chmod +x run-pi.sh

export OPENROUTER_API_KEY="sk-or-your-key-here"

./run-pi.sh

```

Your docker command is actually Podman. docker version says “Podman Engine”, and Ubuntu’s podman-docker package installs that shim. The image was built by a different engine.

Without sudo, docker is rootless Podman, which has its own image storage, and that storage is empty. That’s why docker images showed nothing.

```which docker
docker context ls
docker version
sudo docker images

docker ps
sudo docker rmi pi-agent
```



Podman’s detach keys. 
While Pi is running, press Ctrl+p then Ctrl+q to detach and leave the container running. 
Reattach with:

```
docker attach pi-agent-session
```

