#!/usr/bin/env bash
# Host-side wrapper. Run from project root:
#   bash ralph.sh        — execution mode (default): works through tasks
#   bash ralph.sh plan   — breakdown mode: generates task files from plans
# Requires: docker, ANTHROPIC_API_KEY set in environment
set -euo pipefail

MODE="${1:-execute}"
IMAGE="ralph:latest"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Preflight checks
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found. Install Docker and try again."
    exit 1
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "ERROR: ANTHROPIC_API_KEY is not set."
    echo "  export ANTHROPIC_API_KEY=sk-ant-..."
    exit 1
fi

# In plan mode, prompt-plan.md must exist
if [ "$MODE" = "plan" ] && [ ! -f prompt-plan.md ]; then
    echo "ERROR: prompt-plan.md not found. Cannot run breakdown mode."
    exit 1
fi

# Build image if it doesn't exist yet
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Building $IMAGE (first run)..."
    docker build -t "$IMAGE" "$SCRIPT_DIR"
fi

mkdir -p .ralph

# In plan mode, swap prompt.md for prompt-plan.md inside the container
PROMPT_MOUNT=""
if [ "$MODE" = "plan" ]; then
    echo "Starting Ralph in breakdown mode (prompt-plan.md). Logs → .ralph/loop.log"
    PROMPT_MOUNT="-v $(pwd)/prompt-plan.md:/workspace/prompt.md:ro"
else
    echo "Starting Ralph in execution mode (prompt.md). Logs → .ralph/loop.log"
fi
echo "To stop: touch STOP"
echo ""

# shellcheck disable=SC2086
docker run --rm \
    -v "$(pwd):/workspace" \
    ${PROMPT_MOUNT} \
    -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" \
    -e "NTFY_TOPIC=${NTFY_TOPIC:-}" \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    "$IMAGE" \
    | tee -a .ralph/loop.log

# Preserve docker's exit code, not tee's
exit "${PIPESTATUS[0]}"
