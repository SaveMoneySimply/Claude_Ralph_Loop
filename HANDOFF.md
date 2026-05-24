# Session Handoff

**Delete this file after reading.** It exists only to orient the next session.

---

## What the previous session did

The prior session (HANDOFF-1) built the full Ralph Loop infrastructure. The session before yours (HANDOFF-2) did a readiness review and fixed several issues. Your job is a second-look review and Docker smoke test.

### Files changed in HANDOFF-2 review

| File | Change |
|---|---|
| `.gitignore` | Created — adds `STOP` and `.ralph/` |
| `tasks/active/.gitkeep` | Created — tracks directory in git |
| `tasks/done/.gitkeep` | Created — tracks directory in git |
| `loop.sh` | `mkdir -p .ralph` → `mkdir -p .ralph tasks/active tasks/done` at startup; fixed misleading comment on line ~280 (was "unknown result = task mid-progress"; now "any other result = treat as no-op") |
| `README.md` | Step 3 rewritten — `prompt.md` already ships with the repo, not a template to copy; added prerequisite note for plan mode (PLAN.md + plans/ must exist first); added Docker rebuild note |
| `CLAUDE.md` | Fixed circular "Starter template in the README" reference — now says the file ships with the repo |

### What the HANDOFF-2 session verified as correct (no changes needed)

- `loop.sh` escalation for `haiku` declared — skips effort flag, escalates correctly
- `loop.sh` escalation for `opus + max` declared — goes straight to context expansion, no infinite loop
- `load_recovery()` regex — matches both `**Model:** sonnet` and `Model: sonnet` header formats
- Post-split iteration transition — works correctly (one extra navigation iteration, no correctness issue)
- `init-firewall.sh` `getent ahosts` — works on Ubuntu 24.04
- Dockerfile — `loop.sh` correctly accessed from workspace mount, not baked into image

---

## Your job — second-look review and Docker smoke test

Docker is now installed on the host. Use it.

### 1. Re-read every file and verify the HANDOFF-2 changes are correct

Check each changed file against the issue it was supposed to fix. Look for:
- Did the fix actually address the root cause, or just mask it?
- Did any fix introduce a new inconsistency?
- Are there issues the HANDOFF-2 agent missed entirely?

Pay particular attention to:
- `prompt.md` step 6 — "In progress" steps write `pass`. Does `loop.sh` handle this correctly end-to-end? Trace through a 3-step task where step 2 fails.
- `prompt-split.md` step 8 — after a split, `last-task.txt` holds the original task name (now in tasks/done/). Trace exactly what happens on the next loop iteration, including which task model/effort gets used.
- The `--effort` flag for Haiku: `loop.sh` checks `[ "$MODEL" != "haiku" ]` but also has dead code in `get_step_spec` that handles haiku in the `above[]` array for escalation. Is the dead code harmless or does it cause subtle issues?

### 2. Docker smoke test

Run a minimal end-to-end test. Docker is installed. The container runs as a non-root user with a locked-down firewall, so you'll need to be deliberate.

**Suggested test sequence:**

```bash
# Build the image
docker build -t ralph:latest .

# Verify init-firewall.sh runs without errors and drops to claude user
docker run --rm --cap-add=NET_ADMIN --cap-add=NET_RAW ralph:latest echo "started OK" 2>&1 || true
# (this will fail because loop.sh runs immediately, but the firewall setup should not error)

# Verify the firewall actually blocks egress to non-allowlisted IPs
# (run a container that tries to curl a blocked domain and confirm it fails)
docker run --rm --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$(pwd):/workspace" \
  -e ANTHROPIC_API_KEY=dummy \
  ralph:latest 2>&1 | head -30
# Should see: firewall setup lines, "Resolving api.anthropic.com...", etc.
# Should NOT see errors during iptables setup

# Verify the read-only chmod works
docker run --rm --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$(pwd):/workspace" \
  -e ANTHROPIC_API_KEY=dummy \
  ralph:latest 2>&1 | grep -E "chmod|read.only|0444" || echo "(no chmod output — check init-firewall.sh directly)"
```

Check for:
- `iptables` commands succeed without errors
- `CLAUDE.md` and `ARCHITECTURE.md` (if present) get chmod'd to 0444
- `loop.sh` is found and starts executing (even if it fails immediately due to dummy API key)
- No shell errors or missing commands

### 3. Verify `ralph.sh` plan mode mounting

`ralph.sh plan` mounts `prompt-plan.md` over `prompt.md` inside the container using `-v $(pwd)/prompt-plan.md:/workspace/prompt.md:ro`. Verify this works:

```bash
# The bind mount should shadow the workspace prompt.md
docker run --rm \
  -v "$(pwd):/workspace" \
  -v "$(pwd)/prompt-plan.md:/workspace/prompt.md:ro" \
  ubuntu:24.04 cat /workspace/prompt.md | head -3
# Should show the first line of prompt-plan.md, not prompt.md
```

### 4. Gaps not yet addressed

These were noted in the HANDOFF-2 review but not fixed. Decide whether they need attention:

- `PLAN.md`, `CHANGELOG.md`, and `BLOCKED.md` are referenced throughout but no stub/template files exist. `BLOCKED.md` is auto-created by `loop.sh`. `PLAN.md` and `CHANGELOG.md` must be created by the user. README mentions them but doesn't provide templates. Should there be stub files?
- `loop.sh` context expansion greps `PLAN.md` directly for `'\- \[ \]'` (line ~146). PLAN.md is a thin index; unchecked sub-plan names are not the same as unchecked task steps. Is this good enough for context, or misleading?
- The dead haiku branch in `get_step_spec`'s inner for loop (`if [ "$m" = "haiku" ]`) — `above[]` never contains haiku, so this branch never fires. Harmless, but clutters the logic.

---

*Delete this file after reading.*
