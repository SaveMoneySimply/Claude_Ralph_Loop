#!/usr/bin/env bash
# Runs inside the container as the claude user.
# Iterates: read prompt.md → run claude → check budget → repeat until STOP.
set -uo pipefail

WORKDIR=/workspace
cd "$WORKDIR"
mkdir -p .ralph

i=0

while [ ! -f STOP ]; do
    i=$((i + 1))
    echo ""
    echo "── iteration $i  $(date '+%Y-%m-%d %H:%M:%S') ──"

    ITER_JSON=".ralph/iter-${i}.json"
    ITER_TASK=".ralph/iter-${i}-task.txt"
    ITER_ERR=".ralph/iter-${i}-stderr.log"

    # Run claude. Agent is expected to write .ralph/last-task.txt with the
    # short name of the task it worked on (e.g. "fix-cashback-cpp").
    if ! cat prompt.md \
            | claude -p --output-format json --dangerously-skip-permissions \
            > "$ITER_JSON" 2>"$ITER_ERR"; then
        echo "WARNING: claude exited non-zero on iteration $i — see $ITER_ERR"
        cat "$ITER_ERR" || true
        sleep 5
        continue
    fi

    # Print what claude said so the log is readable
    jq -r '.result // empty' "$ITER_JSON" 2>/dev/null || true

    # Record which task this iteration worked on
    if [ -f .ralph/last-task.txt ]; then
        cp .ralph/last-task.txt "$ITER_TASK"
    else
        echo "unknown" > "$ITER_TASK"
    fi

    CURRENT_TASK=$(cat "$ITER_TASK")

    # --- BUDGET CHECK ---

    # Look up the token estimate from the task's .md header.
    # Expected header line: **Tokens estimated:** 50000
    TASK_MD="tasks/active/${CURRENT_TASK}.md"
    ESTIMATE=0
    if [ -f "$TASK_MD" ]; then
        ESTIMATE=$(grep 'Tokens estimated' "$TASK_MD" | grep -oP '\d+' | head -1 || echo 0)
    fi

    # Sum output_tokens across every iteration that touched this task
    TOTAL_TOKENS=0
    for task_file in .ralph/iter-*-task.txt; do
        [ -f "$task_file" ] || continue
        if [ "$(cat "$task_file")" = "$CURRENT_TASK" ]; then
            ITER_N=$(echo "$task_file" | grep -oP '(?<=iter-)\d+(?=-task)')
            TOKENS=$(jq -r '.usage.output_tokens // 0' ".ralph/iter-${ITER_N}.json" 2>/dev/null || echo 0)
            TOTAL_TOKENS=$((TOTAL_TOKENS + TOKENS))
        fi
    done

    echo "Task: ${CURRENT_TASK} | Tokens this task: ${TOTAL_TOKENS} | Estimate: ${ESTIMATE}"

    if [ "$ESTIMATE" -gt 0 ] && [ "$TOTAL_TOKENS" -gt $((ESTIMATE * 2)) ]; then
        echo "Budget exceeded on '${CURRENT_TASK}': used ${TOTAL_TOKENS}, estimate was ${ESTIMATE} (2× = $((ESTIMATE * 2)))" \
            > STOP
    fi

    [ -f STOP ] || sleep 2
done

REASON=$(cat STOP 2>/dev/null || echo "Loop stopped")
echo ""
echo "STOPPED: $REASON"
echo "Exited after $i iterations."

if [ -n "${NTFY_TOPIC:-}" ]; then
    curl -fsS \
        -H "Title: Ralph stopped" \
        -d "$REASON ($i iterations)" \
        "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null || true
fi
