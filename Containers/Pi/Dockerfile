# Dockerfile: minimal sandboxed container for the Pi coding agent
FROM node:22-slim

# Install Pi globally (package name has moved to @earendil-works/pi-coding-agent;
# the older @mariozechner/pi-coding-agent name may also still work)
RUN npm install -g @earendil-works/pi-coding-agent

# Create the Pi config directory for the non-root "node" user
RUN mkdir -p /home/node/.pi/agent/extensions \
    && chown -R node:node /home/node/.pi

# Run as non-root
USER node

# Your project gets mounted here at runtime
WORKDIR /workspace

ENTRYPOINT ["pi"]