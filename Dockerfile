FROM mcr.microsoft.com/dotnet/sdk:10.0

ENV DEBIAN_FRONTEND=noninteractive

# git, gh CLI (apt repo) and azure-cli (MS install script) prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget git ca-certificates gnupg lsb-release sudo tmux vim iputils-ping \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update && apt-get install -y --no-install-recommends powershell \
    && rm -rf /var/lib/apt/lists/*
# az bicep is intentionally not pre-baked: `az bicep install` puts its copy under
# ~/.azure/bin, which is part of the persisted $HOME mount - az auto-installs it
# there on first use (e.g. `az bicep version`) and it's cached for good after that.

# Docker CLI only - no dockerd. This container talks to the NAS's own Docker Engine
# over /var/run/docker.sock (bind-mounted in docker-compose.yml), the same
# Docker-outside-of-Docker pattern portainer/homepage/glances-nas already use in this
# repo - not a nested daemon ("docker inception"), just a client to the one that's
# already running every other container here. `docker build`/`push`/`compose` all
# work through it once the socket is mounted.
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Non-root user matching this NAS's host uid/gid (1000:100 -> rlucassen:everyone),
# so files written back through bind mounts stay owned by rlucassen, not root/admin.
# The base image already ships a uid-1000 user ("ubuntu"); repoint it rather than
# colliding with it. gid 100 already exists in the image too, as "users".
RUN usermod -l dev -d /home/dev -m -g 100 -s /bin/bash ubuntu \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/dev \
    && mkdir -p /opt/nvm /workspace \
    && chown -R dev:100 /home/dev /opt/nvm /workspace

USER dev
WORKDIR /workspace
ENV HOME=/home/dev
# nvm/node live outside $HOME on purpose: the whole $HOME is bind-mounted for
# persistence (settings/logins for whatever tool, without needing a mount line
# per tool), and a host-side mount there would otherwise shadow an in-image install.
ENV NVM_DIR=/opt/nvm

# nvm + latest LTS node, then Claude Code CLI via npm. Binaries get symlinked into
# /usr/local/bin (already on PATH everywhere, incl. non-interactive `docker exec`,
# and untouched by the $HOME mount) since npm's own bin dir lives under $NVM_DIR.
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install --lts \
    && nvm alias default 'lts/*' \
    && npm install -g @anthropic-ai/claude-code azure-functions-core-tools@4 @openai/codex --unsafe-perm true \
    && NODE_BIN_DIR="$(dirname "$(nvm which default)")" \
    && for bin in node npm npx claude func codex; do sudo ln -sf "$NODE_BIN_DIR/$bin" /usr/local/bin/"$bin"; done

# Make the `nvm` shell function itself available in interactive shells regardless
# of what's bind-mounted over $HOME (system-wide bashrc, not ~/.bashrc).
RUN echo '\nexport NVM_DIR=/opt/nvm\n[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' | sudo tee -a /etc/bash.bashrc >/dev/null

CMD ["sleep", "infinity"]
