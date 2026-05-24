#!/usr/bin/env bash
# Host-side wrapper. Run from project root: bash ralph.sh
# Requires: docker, ANTHROPIC_API_KEY set in environment
set -euo pipefail

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

# Build image if it doesn't exist yet (or if Dockerfile changed)
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Building $IMAGE (first run)..."
    docker build -t "$IMAGE" "$SCRIPT_DIR"
fi

mkdir -p .ralph

echo "Starting Ralph loop. Logs → .ralph/loop.log"
echo "To stop: touch STOP"
echo ""

docker run --rm \
    -v "$(pwd):/workspace" \
    -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" \
    -e "NTFY_TOPIC=${NTFY_TOPIC:-}" \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    "$IMAGE" \
    | tee -a .ralph/loop.log

# Preserve docker's exit code, not tee's
exit "${PIPESTATUS[0]}"
