# Ralph Loop — Session Handoff

Paste this into a fresh Claude session to pick up where the last one stopped.

## Context

I'm setting up a "Ralph Loop" for autonomous coding — a simple `while` loop that runs Claude Code headless against a `prompt.md`, looping until a `STOP` file appears. The full design lives in my global `~/.claude/CLAUDE.md` (recently updated). This session's job is to produce the four supporting files that go in a project's root to actually run the loop.

## Files to produce

### 1. `Dockerfile`

- Base: `ubuntu:24.04` (or `node:20-bookworm-slim` if simpler)
- Install: Node 20, `@anthropic-ai/claude-code` via npm (global), `git`, `jq`, `ripgrep`, `curl`, `iptables`, `ca-certificates`
- Non-root user `claude` with home `/home/claude`
- Workdir `/workspace`
- Entrypoint runs `init-firewall.sh`

### 2. `init-firewall.sh`

Runs as root at container start, then drops to user `claude` and execs `loop.sh`.

- Uses `iptables` to DROP all egress by default
- Allowlists (ACCEPT) these domains:
  - `api.anthropic.com`
  - `github.com`, `objects.githubusercontent.com`, `codeload.github.com`
  - `registry.npmjs.org`, `registry.yarnpkg.com`
  - `pypi.org`, `files.pythonhosted.org`
  - `ntfy.sh`
- Also ACCEPT loopback and DNS (port 53) to allowed resolvers
- `chmod 0444 /workspace/ARCHITECTURE.md` (silent if file doesn't exist yet)
- `exec su claude -c "bash /workspace/loop.sh"` to drop privileges

### 3. `ralph.sh`

Host-side wrapper. Single command users run to start the loop.

- Build the Docker image if missing (tag e.g. `ralph:latest`)
- Run container with:
  - `-v "$(pwd):/workspace"` (project, read-write)
  - `-v "$HOME/.claude/CLAUDE.md:/home/claude/.claude/CLAUDE.md:ro"` (global rules, read-only)
  - `-e NTFY_TOPIC="$NTFY_TOPIC"` (passthrough for notifications)
  - `--cap-add=NET_ADMIN --cap-add=NET_RAW` (so iptables works)
  - `--rm` (ephemeral container)
- Stream output to host stdout AND to `.ralph/loop.log` (use `tee`)
- Exit code matches container exit code

### 4. `loop.sh`

Runs inside the container. The core loop.

```bash
while [ ! -f STOP ]; do
  iteration++
  cat prompt.md | claude -p --output-format json --dangerously-skip-permissions \
    > .ralph/iter-$N.json
  # parse usage with jq:
  #   .usage.output_tokens  → tokens this iteration
  #   .result               → what Claude said
  # determine which task .md was being worked on (Claude should write
  #   .ralph/last-task.txt as part of its iteration)
  # sum tokens for that task across .ralph/iter-*.json
  # if sum > 2 × (Tokens estimated from task header):
  #   echo "Budget exceeded on <task>" > STOP
  sleep 2
done

# on exit:
REASON=$(cat STOP 2>/dev/null || echo "Loop stopped")
echo "$REASON — exited after $N iterations."
if [ -n "$NTFY_TOPIC" ]; then
  curl -fsS -d "$REASON ($N iterations)" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null || true
fi
```

The agent's `prompt.md` instructs it to write `.ralph/last-task.txt` with the current task's short name each iteration so `loop.sh` knows which task to budget against.

## Design constraints already decided — don't relitigate

- **Plain Docker**, not VS Code devcontainer (CLI-first for automation)
- **CLAUDE.md global, read-only** — mounted `:ro` from host `~/.claude/CLAUDE.md`
- **ARCHITECTURE.md per-project, read-only** — chmod `0444` at container init
- **Agent never edits read-only files** — writes proposals to `ARCHITECTURE_REVIEW.md`, touches STOP, exits (review pattern)
- **ntfy.sh** for phone notifications (free, no signup)
- **Usage budget**: each task declares `Tokens estimated: <n>` in its header; 2× triggers STOP
- **STOP carries its reason** as file contents → becomes the notification body
- **Non-root user** inside container
- **Headless Claude Code** invoked with `claude -p --output-format json --dangerously-skip-permissions`

## Reference

Full design is in `~/.claude/CLAUDE.md`. Key sections:

- **Containment → Recommended setup: CLI wrapper with plain Docker** — the full contract these scripts honor
- **Autonomous Loop (Ralph)** — the loop itself, prompt.md template, state files, stop conditions
- **Read-only files and the review pattern** — why ARCHITECTURE.md isn't agent-writable

## What I want from this session

Produce all four files as artifacts I can drop into a project root. Recommended order:

1. `Dockerfile` first (defines the environment)
2. `init-firewall.sh` next (runs inside that environment)
3. `loop.sh` next (the actual loop logic, most involved)
4. `ralph.sh` last (host wrapper that ties it together)

Test the firewall rules and the usage-budget jq parsing carefully — those are the easiest places to introduce subtle bugs. Keep each script short and well-commented; I'd rather have 80 readable lines than 30 clever ones.
