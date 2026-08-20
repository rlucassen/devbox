# devbox

Source for the `devbox` image: a personal dev container for this NAS —
.NET SDK, git, GitHub CLI, Azure CLI, Docker CLI (docker-outside-of-docker,
talking to the NAS's own Docker Engine over a bind-mounted socket), Claude
Code, Codex CLI, PowerShell, tmux, vim. Runtime config (`docker-compose.yml`)
lives in the deploy repo, not here — see the `devbox/` folder in
[`rlucassen/docker-containers`](https://github.com/rlucassen/docker-containers).

## What's here

- `Dockerfile` only — installs the tooling above, creates a `dev` user
  matching the NAS's host uid/gid (1000:100) so files written back through
  bind mounts stay owned by the real user, and installs Node via nvm plus
  the Claude Code / Codex CLIs.

## Building & deploying

```bash
docker build -t registry.internal/devbox:latest .
docker push registry.internal/devbox:latest
```

Then on the host running it:

```bash
docker pull registry.internal/devbox:latest
docker compose up -d   # from the docker-containers devbox/ folder
```
