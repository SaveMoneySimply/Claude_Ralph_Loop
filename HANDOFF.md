# Session Handoff

**Delete this file after reading.** It exists only to orient the next session.

---

## What was built

This repo (`Claude_Ralph_Loop`) is a base template to fork for new projects. The session built the complete Ralph Loop infrastructure — an autonomous coding system where Claude Code runs headless in a Docker container, working through a task list until done.

### Files created or significantly changed

- `CLAUDE.md` — rewritten as a loop-first operating manual (per-project, not global). Covers 4-phase workflow, task file format, model/effort per task, stop conditions, git rules, recovery/escalation system, containment, and read-only file review pattern.
- `Dockerfile` — ubuntu:24.04, Node 20, `@anthropic-ai/claude-code` global, non-root user `claude`
- `init-firewall.sh` — runs as root at container start; sets iptables egress allowlist (api.anthropic.com, github, npm, ntfy.sh etc.); chmodds CLAUDE.md and ARCHITECTURE.md to 0444; drops to claude user
- `ralph.sh` — host-side wrapper; builds Docker image if missing; runs container with `/workspace` mount, `ANTHROPIC_API_KEY`, `NTFY_TOPIC`; supports `bash ralph.sh plan` (breakdown mode) and `bash ralph.sh` (execution mode)
- `loop.sh` — the core while loop inside the container; reads model/effort from task header; runs `claude --model <m> --effort <e> --bare -p --output-format json --dangerously-skip-permissions`; implements full recovery/escalation ladder on failure; checks token budget
- `prompt.md` — thin navigation wrapper (~30 lines); Claude reads state files, picks next step, executes it, writes `pass` or `fail` to `.ralph/last-result.txt`
- `prompt-plan.md` — breakdown mode; Claude reads sub-plans and generates task files in `tasks/active/`
- `prompt-split.md` — split mode; Claude breaks a failing task into 2-3 smaller sub-tasks
- `README.md` — how to fork the repo and set up a new project

### Key design decisions

- **CLAUDE.md is per-project** (checked into the repo, not global). Both CLAUDE.md and ARCHITECTURE.md are chmod 0444 at container init.
- **Task files are the prompt.** `tasks/active/*.md` is the effective instruction set for each loop iteration. They include `Model:`, `Effort:`, `Tokens estimated:`, `Steps:` (checkboxes), and a `## Smoke test` section.
- **Model/effort per task.** `loop.sh` reads `Model:` and `Effort:` from the current task header and passes `--model` and `--effort` to each `claude` invocation. Haiku doesn't support `--effort` — the flag is omitted.
- **`bash ralph.sh plan`** swaps `prompt-plan.md` in as the prompt so Claude generates task files from sub-plans before execution starts.
- **Recovery/escalation on test gate failure:** declared model+effort (2 attempts) → same model+max → next model+low → next model+max → (up through opus+max) → context expansion (injects last 2 done tasks + next 2 planned tasks) → task split → BLOCKED
- **Budget exceeded** (2× token estimate): `autonomy: high` → schedule task split; `autonomy: low` → STOP
- **Task splitting** creates sub-tasks with `**Parent task:**` and `**Split depth:**` headers. Max split depth = 2. Autonomy setting lives in `ARCHITECTURE.md` under `## Ralph settings`.
- **Recovery log** — every attempt appended to `.ralph/recovery-log.jsonl` for future analysis.
- **Phone notifications** via ntfy.sh — set `NTFY_TOPIC` env var, loop fires on exit.

### What does NOT exist yet

- `ARCHITECTURE.md` — per-project, must be created when forking. No stub exists.
- `PLAN.md`, `plans/`, `tasks/` folders — also per-project.
- `.gitignore` — discussed but not created. Needs `STOP` and `.ralph/` at minimum.
- Docker has not been tested (not installed on the host). All shell scripts pass `bash -n` syntax check.
- The loop has not been run end-to-end.

---

## Your job — review for readiness

Read every file in the repo and verify the infrastructure is coherent and ready to use on a real project. Then fix anything that's wrong or missing.

1. **Consistency check** — do references between files line up? Does what `loop.sh` parses from task headers match what CLAUDE.md says the format is? Does `prompt.md` instruct Claude to write `last-result.txt` in the same format `loop.sh` expects to read it?

2. **Gaps** — what's missing before someone could fork this and run it? `.gitignore` is one known gap. An `ARCHITECTURE.md` stub or template might help. Anything else?

3. **Prompt completeness** — are `prompt.md`, `prompt-plan.md`, and `prompt-split.md` clear enough that an agent receiving them cold would know exactly what to do?

4. **Edge cases in loop.sh** — trace through the escalation logic for a task declared `haiku` (no effort support) and one declared `opus + max` (already at ceiling). Does the ladder behave correctly?

5. **README accuracy** — does the README correctly describe how to fork and start?

Report what you find. Fix anything broken or missing. If everything looks good, say so and suggest a simple first project to test the infrastructure end-to-end.

---

*Delete this file after reading.*
