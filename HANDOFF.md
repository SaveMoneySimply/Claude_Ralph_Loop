# Session Handoff

**Delete this file after reading.** It exists only to orient the next session.

---

## What this session did

This was a second-look review + Docker smoke test session (HANDOFF-3). It found and fixed three real bugs that previous review sessions missed, then ran the Docker smoke tests to verify.

### Files changed this session

| File | Change |
|---|---|
| `Dockerfile` | `ENV PATH` expanded to include `/usr/sbin` — without it, `useradd` (at `/usr/sbin/useradd` on Ubuntu 24.04) was not found, crashing the build at layer 5 |
| `loop.sh` | Five variable-length lookbehind regex patterns replaced with `\K` (match reset) — see Regex section below |
| `loop.sh` | Removed dead `if [ "$m" = "haiku" ]` branch in `get_step_spec` for-loop (`above[]` never contains haiku) |
| `init-firewall.sh` | Added `usermod -u $(stat -c %u /workspace) -o claude` block before `exec su` — fixes write permission for claude user in bind-mounted workspace; also updated PATH in `exec su` to match Dockerfile |
| `PLAN.md` | Created stub (didn't exist; loop's `prompt.md` reads it on every iteration) |
| `CHANGELOG.md` | Created stub (didn't exist; append-only log expected by loop) |

### Bugs found and fixed

**Bug 1 — Dockerfile PATH missing `/usr/sbin`**

`ENV PATH="/usr/local/bin:/usr/bin:/bin"` excluded `/usr/sbin`. On Ubuntu 24.04, `useradd` lives at `/usr/sbin/useradd` (usrmerge is NOT fully complete — `/usr/sbin` is not yet an alias for `/usr/bin`). The build failed at `RUN useradd -m -s /bin/bash claude` with exit code 127 (command not found).

Fixed by changing to: `ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"`

**Bug 2 — Five variable-length lookbehind regexes in loop.sh**

GNU grep on Ubuntu 24.04 does not support variable-length lookbehinds (`\s{0,5}` makes a lookbehind variable-length). All five patterns silently failed with `grep: lookbehind assertion is not fixed length`, causing:
- `read_autonomy()` → always returned default `"low"`
- `load_recovery()` → always returned default model `"sonnet"` and effort `"high"`, regardless of task file headers; split depth and parent task always defaulted to 0/""

All five fixed by replacing `(?<=...\s{0,5})` lookbehinds with `\K` (match reset), which is supported:

| Function | Old | New |
|---|---|---|
| `read_autonomy` | `(?<=autonomy:\s{0,5})\w+` | `autonomy:\s*\K\w+` |
| `load_recovery` | `(?<=Split depth:\s{0,5})\d+` | `Split depth:\s*\K\d+` |
| `load_recovery` | `(?<=Parent task:\s{0,5})\S+` | `Parent task:\s*\K\S+` |
| `load_recovery` | `(?<=\bModel:\*\*\s{0,5}\|\bModel:\s{0,5})\w+` | `\bModel:(?:\*\*\s*\|\s+)\K\w+` |
| `load_recovery` | `(?<=\bEffort:\*\*\s{0,5}\|\bEffort:\s{0,5})\w+` | `\bEffort:(?:\*\*\s*\|\s+)\K\w+` |

**Bug 3 — claude user UID mismatch (workspace not writable)**

Ubuntu 24.04 base image ships with an `ubuntu` user at UID 1000. `useradd -m -s /bin/bash claude` therefore gets UID 1001. The bind-mounted `/workspace` is owned by the host user (typically UID 1000). The `claude` user (UID 1001) has only "other" permissions on the workspace (r-x) — no writes. `mkdir -p .ralph` failed with "Permission denied" every iteration. The loop ran but could write nothing.

Fixed in `init-firewall.sh`: before dropping to claude, detect the workspace owner's UID and update claude to match:
```bash
WORKSPACE_UID=$(stat -c %u /workspace)
if [ "$WORKSPACE_UID" -gt 0 ] && [ "$(id -u claude)" != "$WORKSPACE_UID" ]; then
    usermod -u "$WORKSPACE_UID" -o claude
    chown -R claude /home/claude
fi
```
The `-o` flag allows a duplicate UID (shared with the ubuntu user that already owns 1000). Harmless since the ubuntu user isn't used inside the running container.

**Read-only protection implication:** After `usermod`, claude now owns CLAUDE.md (host file owned by host user, same UID as claude in container). claude COULD `chmod u+w CLAUDE.md` to undo the 0444 protection, since file owners control their own file permissions. This is an acceptable tradeoff — the agent is instructed not to modify CLAUDE.md; the 0444 is a safety net, not a hard security boundary. The real containment is the container isolation and firewall.

### Docker smoke tests run and passed

All tests from the HANDOFF instructions ran successfully:

1. **Build** — `docker build -t ralph:latest .` — succeeds after Dockerfile PATH fix
2. **Firewall** — all 9 domains resolve and receive ACCEPT rules; no iptables errors; ends with "Firewall configured. All other egress blocked."
3. **chmod** — `CLAUDE.md` is 0444 after container start
4. **Workspace writes** — `.ralph/` directory created and owned by host user UID (usermod fix working)
5. **Loop startup** — exits cleanly on pre-created STOP file; "Exited after 0 iterations."
6. **Plan mode bind mount** — `prompt-plan.md` correctly shadows `prompt.md` in the container

### What the HANDOFF-2 session verified as correct (still holds)

- `loop.sh` escalation for `haiku` declared — skips effort flag, escalates correctly
- `loop.sh` escalation for `opus + max` declared — goes straight to context expansion, no infinite loop
- Post-split iteration transition — one extra navigation+execution iteration with defaults, not a bug
- `init-firewall.sh` `getent ahosts` — works on Ubuntu 24.04
- `loop.sh` mkdir at startup — now confirmed working after Bug 3 fix

---

## Your job — README review and final sign-off

Docker is working. The code is fixed. Your job is to verify the README is accurate and complete for someone forking this template for the first time.

### 1. Re-read all changed files

Read `Dockerfile`, `loop.sh`, `init-firewall.sh`, `PLAN.md`, `CHANGELOG.md` and verify:
- The fixes described above are actually present in the files
- No typos, logic errors, or new inconsistencies introduced

Pay particular attention to:
- `init-firewall.sh` — does the `usermod` block appear in the right place (before `exec su`, after chmod)? Is the PATH in `exec su` consistent with the Dockerfile PATH?
- `loop.sh` `load_recovery` — does the `\bModel:(?:\*\*\s*|\s+)\K\w+` pattern correctly match both `**Model:** sonnet` (bold) and `Model: sonnet` (plain)?
- `PLAN.md` stub — it references `plans/example.md` which doesn't exist. Is this confusing for a new user? Should the reference be removed or the file created?

### 2. README.md audit

Read `README.md` fully and check every claim against the current state of the repo. Specific things to verify:

**Docker setup section:**
- Does README mention that the user must be in the docker group? It currently says "Install Docker" and links to the official docs. Is that enough, or should it mention `sudo usermod -aG docker $USER` and re-login?
- Does README mention that if `Dockerfile` or `init-firewall.sh` change, the user must `docker rmi ralph:latest` to force a rebuild? (HANDOFF-2 added this; confirm it's still there.)

**PLAN.md / CHANGELOG.md:**
- `PLAN.md` and `CHANGELOG.md` now ship as stubs in the repo. Does README still describe them as files the user must create? If so, update that language to reflect that stubs exist and just need editing.
- The stub `PLAN.md` contains a reference to `plans/example.md` (a file that doesn't exist). A new user following the README step-by-step will see this stub and might be confused. Consider: (a) removing the example line from the stub, (b) creating a `plans/example.md` stub, or (c) adding a README note explaining the stub is a placeholder.

**Step ordering:**
- README steps are: fork → create ARCHITECTURE.md → prompt.md already exists → add tasks → set env vars → install Docker → start Ralph. This ordering puts Docker installation at step 6 but ralph.sh checks for docker at runtime. Is the ordering sensible? Should Docker setup (and group membership) come earlier?

**Watching progress / stopping:**
- Are the `tail -f .ralph/loop.log` and `ls .ralph/iter-*.json` commands still accurate? These require `.ralph/` to exist, which only happens after the first container run.

### 3. Run a quick Docker sanity check

After the README is updated, run the same smoke test sequence to confirm nothing broke:

```bash
# Rebuild after any changes
docker rmi ralph:latest 2>/dev/null || true
docker build -t ralph:latest .

# Smoke test: firewall + loop exit on STOP
echo "smoke-test" > STOP
docker run --rm --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -v "$(pwd):/workspace" \
  -e ANTHROPIC_API_KEY=dummy \
  ralph:latest 2>&1 | grep -v "Resolving\|ACCEPT"
rm -f STOP

# Verify .ralph was created and owned by host user
ls -la .ralph/
stat -c "%U %G %a" .ralph

# Cleanup
rm -rf .ralph
git checkout CLAUDE.md  # reset any chmod from the container run

# Plan mode bind mount
docker run --rm \
  -v "$(pwd):/workspace" \
  -v "$(pwd)/prompt-plan.md:/workspace/prompt.md:ro" \
  ubuntu:24.04 bash -c 'head -1 /workspace/prompt.md'
# Should print: "You are running in Ralph breakdown mode inside a sandboxed container."
```

### 4. Gaps not yet addressed

These were noted in earlier sessions but not fixed. Decide whether they need attention:

- `build_context_prompt` in `loop.sh` greps PLAN.md for `'\- \[ \]'` and labels the results "upcoming tasks." PLAN.md is a thin index of sub-plans, so the "upcoming tasks" label is misleading (they're sub-plan entries, not task steps). Harmless but potentially confusing in the context expansion prompt. Low priority.

- Docker group membership is required but not mentioned in README. A new user following the README on a fresh Docker install will hit "permission denied" on the socket. Worth a one-liner note.

- `PLAN.md` stub references `plans/example.md` which doesn't exist. No `plans/` directory exists in the template repo. This needs resolution.

---

*Delete this file after reading.*
