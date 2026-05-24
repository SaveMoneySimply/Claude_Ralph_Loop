# Ralph Loop — Operating Manual

This file lives at the project root and is checked into the repo. Fork this repo for new projects; CLAUDE.md travels with the fork. It is **read-only to the loop agent** — chmodded `0444` at container init. To propose a change, write to `CLAUDE_REVIEW.md` and stop.

## Operating Principles

- **Simple first** — when two approaches exist, take the simpler one
- **One step per iteration** — execute one step from the current task file, write `pass` or `fail` to `.ralph/last-result.txt`, exit; the next iteration continues
- **On failure** — `loop.sh` escalates automatically: same model + max effort → next model → context expansion → task split → BLOCKED (see Recovery and Escalation)

## Workflow Phases

Four phases. Each ends with **→ CLEAR CONTEXT** — the docs are the state, not the conversation.

**Phase 0 — Project Setup (Interactive)**
User + Claude create `ARCHITECTURE.md` (stack, test command, key folders, firewall additions). Sketch `PLAN.md` and `plans/` if the major areas are already clear.
→ **CLEAR CONTEXT**

**Phase 1 — High-Level Planning (Interactive, Plan Mode)**
Read `ARCHITECTURE.md`. Produce `PLAN.md` (index) + `plans/*.md` (one per major work area, rough task list per area).
→ **CLEAR CONTEXT**

**Phase 2 — Task Breakdown (Interactive or Automated)**
For each plan item: create `tasks/active/<name>.md` with explicit, ordered steps.
- **Interactive:** User + Claude create task files together, then clear context
- **Automated:** `bash ralph.sh plan` — runs with `prompt-plan.md`; Claude reads sub-plans, generates task files, writes STOP when done
→ **CLEAR CONTEXT**, then `bash ralph.sh` to start execution

**Phase 3 — Loop (Ralph, Autonomous)**
Each iteration: navigate `PLAN.md` → pick highest-priority unchecked task → read task file → execute next unchecked step → if last step passes the testing gate → commit → close task → exit. Next iteration continues from here.

## Task File Format

Each file in `tasks/active/` is the effective prompt for the loop when that task is active. Keep steps small and acceptance criteria explicit.

```markdown
# Task — <short name>

**Model:** sonnet · **Effort:** high · **Tokens estimated:** 50000 · **Attempts:** 0/3
**Test command:** npm run build && npm test
# Sub-tasks only — omit these lines for top-level tasks:
# **Parent task:** original-name · **Split depth:** 1

## Steps
- [ ] Step 1: <what to do> — done when: <acceptance criterion>
- [ ] Step 2: ...
- [ ] Step N (final): run test command — on pass, commit and close task

## Smoke test
<what to manually verify after the loop completes this task>
```

### Model and effort options

`loop.sh` reads `Model:` and `Effort:` from the task header and builds the CLI invocation. Use short aliases in task headers:

| Task header value | CLI flags |
|---|---|
| `haiku` | `--model haiku` (effort not supported for Haiku — flag omitted) |
| `sonnet` | `--model sonnet --effort <level>` |
| `opus` | `--model opus --effort <level>` |

Effort scales:
- **opus** (4.7): `low` · `medium` · `high` · `xhigh` · `max`
- **sonnet** (4.6): `low` · `medium` · `high` · `max`
- **haiku**: `--effort` omitted

Defaults when header values are missing: `sonnet` + `high`. Unsupported effort levels fall back to the highest supported — no crash.

## Recovery and Escalation

When a step fails, `loop.sh` escalates through this ladder automatically. Each level is tried before moving to the next.

| Step | Action | Attempts |
|---|---|---|
| 0 | Declared model + declared effort | 2 (self-correction chance) |
| 1 | Same model + **max** effort | 1 |
| 2 | Next model + **low** effort | 1 |
| 3 | Next model + **max** effort | 1 |
| … | (repeat up through opus + max) | 1 each |
| N | **Context expansion** — injects last 2 done tasks + next 2 planned tasks into the prompt | 1 |
| N+1 | **Task split** — if autonomy: high and split depth < 2 | — |
| final | → BLOCKED.md | — |

**Autonomy setting** (in `ARCHITECTURE.md` under `## Ralph settings`):
- `autonomy: high` — full escalation ladder + recursive splitting up to depth 2
- `autonomy: low` (default) — escalation ladder only; no splitting; any ladder exhaustion → STOP

**Budget exceeded** (2× token estimate):
- `autonomy: high` → schedule a task split next iteration
- `autonomy: low` → STOP immediately for human review

**Task splitting**: the original task moves to `tasks/done/` marked `**Split into:** part-1, part-2`. Sub-tasks are created in `tasks/active/` with `**Parent task:**` and `**Split depth:**` headers. Sub-tasks at depth 2 cannot be split further — they go straight to BLOCKED if exhausted.

**Recovery log**: every attempt is appended to `.ralph/recovery-log.jsonl` for future analysis and tuning.

## Stop Conditions

The loop exits when any of:

1. **All tasks complete** — `echo "All tasks complete" > STOP`
2. **Token budget exceeded** — actual output tokens > 2× `Tokens estimated` for the current task → STOP with reason
3. **Test gate failed 3× on same task** — move to `BLOCKED.md`; STOP if no unblocked tasks remain
4. **Architecture change needed** — write proposal to `ARCHITECTURE_REVIEW.md` → STOP
5. **Manual** — `touch STOP` from any terminal; file contents become the notification body

## Git

Branch per task, merge when done, delete the branch:

```bash
git checkout -b task/<name>
# ... work through steps ...
git checkout main && git merge --ff-only task/<name> && git branch -d task/<name>
```

State files (`PLAN.md`, `CHANGELOG.md`, `BLOCKED.md`) commit to main directly. One agent, one task — no branch conflicts possible.

## .md File Architecture

Consistent doc structure so the loop orients quickly each iteration.

### Folder structure

- **Project root** holds index files and orientation docs only:
  - `README.md` — what it is, how to run it
  - `ARCHITECTURE.md` — stack, runtime, key folders, deploy topology, test command (**read-only to the agent**)
  - `CHANGELOG.md` — append-only log of completed tasks (date, name, one-line description, links)
  - `PLAN.md` — thin index pointing at sub-plans in `plans/`
  - `ROUTINES.md` — thin index pointing at routines in `routines/`
  - `TEST.md` — post-deploy and recurring verifications
  - `BLOCKED.md` — tasks the loop couldn't progress, with captured evidence
  - `ARCHITECTURE_REVIEW.md` — proposed changes to ARCHITECTURE.md, awaiting human review
  - `prompt.md` — navigation wrapper; tells the loop how to read state and pick the next step
  - `prompt-plan.md` — breakdown mode; generates task files from sub-plans
  - `loop.sh` — the loop runner (inside container)
  - `ralph.sh` — host CLI wrapper

- **`plans/`** — one .md per major work area. `PLAN.md` at root just lists them with status.
- **`routines/`** — recurring operational processes (e.g. data syncs, release steps).
- **`reference/`** — background research and external context.
- **`tasks/active/`** — task files currently being worked
- **`tasks/done/`** — archived completed tasks
- **`_archive/`** — superseded docs kept for reference

### How plans and tasks connect

- A **plan** (`plans/*.md`) holds a checklist of tasks for that work area
- A **task** (`tasks/active/*.md`) is one of those items being actively worked
- Each plan checkbox links to its task file:

```
- [ ] Fix auth middleware — [task](../tasks/active/fix-auth-middleware.md)
- [x] Add email validation — [done](../tasks/done/add-email-validation.md)
```

When a task is complete and archived, update the link (`active/` → `done/`) and check the box.

### Per-task workflow

1. **Create** `tasks/active/<name>.md` — model, effort, token estimate, steps, smoke test
2. **Link from the plan** — update the matching checkbox in `plans/<plan>.md` to point at the task file
3. **Loop executes** steps one at a time, marking each complete
4. **Testing gate passes** (see Testing Gate):
   - Move file from `tasks/active/` to `tasks/done/`
   - Update the plan link and check the box
   - Append entry to `CHANGELOG.md`
   - Sweep related docs:
     - `ARCHITECTURE.md` — **never edit directly**; write proposed changes to `ARCHITECTURE_REVIEW.md` and STOP
     - `PLAN.md` — if a sub-plan is now fully complete
     - `routines/` — if operational behavior changed

### How TEST.md works

Two checklists in one file:

- **One-time tests** — verifications that need a deploy or real traffic; grouped by task with a link back to the task .md
- **Routine tests** — recurring checks; uncheck after each run so the cadence stays visible

If a task can be verified inline (unit test, curl), do it before moving to done — don't add to TEST.md. TEST.md is for post-deploy verifications and cross-cutting recurring checks.

## Autonomous Loop (Ralph)

Ralph is a `while` loop that runs Claude Code headless against a prompt file, one iteration at a time, until a STOP file appears. The agent is stateful via .md files; the loop is intentionally dumb.

### loop.sh sketch

```bash
while [ ! -f STOP ]; do
  # Read model and effort from the current task header
  TASK=$(cat .ralph/last-task.txt 2>/dev/null || echo "")
  MODEL=sonnet; EFFORT=high
  if [ -f "tasks/active/${TASK}.md" ]; then
    MODEL=$(grep -oiP '(?<=Model:\s{0,5}|\*\*Model:\*\*\s{0,5})\w+' \
      "tasks/active/${TASK}.md" | head -1 | tr '[:upper:]' '[:lower:]')
    EFFORT=$(grep -oiP '(?<=Effort:\s{0,5}|\*\*Effort:\*\*\s{0,5})\w+' \
      "tasks/active/${TASK}.md" | head -1 | tr '[:upper:]' '[:lower:]')
  fi

  # Build invocation — haiku doesn't support --effort
  CMD="claude --model ${MODEL:-sonnet}"
  [ "${MODEL:-sonnet}" != "haiku" ] && CMD="$CMD --effort ${EFFORT:-high}"
  CMD="$CMD --bare -p --output-format json --dangerously-skip-permissions"

  cat prompt.md | $CMD > ".ralph/iter-${i}.json" 2>".ralph/iter-${i}-stderr.log"

  # Budget check and STOP logic — see loop.sh source
done
```

### prompt.md — navigation wrapper

Lives at project root. Under ~30 lines — re-read every iteration. Tells Claude: read state files, find the next unchecked step in the highest-priority task, execute it, write `.ralph/last-task.txt`. Starter template in the README.

### State files

| File | Purpose | Owner |
|---|---|---|
| `CLAUDE.md` | Loop operating manual (chmod 0444) | human — agent reads |
| `ARCHITECTURE.md` | Project facts (chmod 0444) | human — agent reads, proposes changes via review |
| `PLAN.md` | Sub-plan index + priority order | shared |
| `plans/*.md` | Each area's task checklist | shared |
| `tasks/active/*.md` | Task files with steps, model, effort, estimates | agent |
| `tasks/done/*.md` | Archived completed tasks | agent |
| `CHANGELOG.md` | Append-only log | agent |
| `BLOCKED.md` | Tasks the agent couldn't progress | agent |
| `ARCHITECTURE_REVIEW.md` | Proposed ARCHITECTURE.md changes | agent writes, human reviews |
| `TEST.md` | Post-deploy + recurring verifications | shared |
| `STOP` | Loop exit sentinel; contents = notification body | either |
| `.ralph/last-task.txt` | Current task short name (written by agent each iteration) | agent |
| `.ralph/iter-N.json` | Per-iteration JSON output | agent |

### Usage budget

Each task declares `Tokens estimated: N`. `loop.sh` sums `output_tokens` across all iterations that worked on that task. When the total exceeds 2× the estimate, it writes STOP — something is off and human review is cheaper than letting it spiral.

### Phone notifications

Set `NTFY_TOPIC` in your shell profile (e.g. `ralph-matt-7a3k`). The loop hits `ntfy.sh` on exit with the STOP contents as the body. Install the ntfy app and subscribe to your topic.

### When not to use Ralph

- Live deploys, production credentials, or paid third-party APIs at scale
- Greenfield architecture decisions — do Phases 0 and 1 interactively first
- UI work where human taste is the spec — confirm the look interactively, let Ralph do the mechanical follow-through

## Testing Gate

No task moves to `tasks/done/` until the gate passes.

### What "pass" means

Every project's `ARCHITECTURE.md` declares its test command. Default chain:

1. **Build** — `npm run build` (or project equivalent). Zero errors.
2. **Type check** — `npm run typecheck` if the script exists. Clean.
3. **Lint** — `npm run lint` if the script exists. Errors not ok, warnings ok.
4. **Unit tests** — `npm test` if the script exists. All pass.
5. **Smoke test** — focused check defined in the task's `## Smoke test` section.

### In loop mode

Gate runs automatically before move-to-done:

1. First failure → try one targeted fix, re-run
2. Second failure → try a different fix, re-run
3. Third failure → move to `BLOCKED.md` (link to task .md + full failing output + what was tried). End the iteration.

`Attempts:` in the task header tracks this across iterations.

## Containment

Loop mode runs with `--dangerously-skip-permissions`. This is safe because Claude runs inside a container isolated from the host — and even inside it, can't write to files marked read-only.

### Docker setup

`ralph.sh` builds and runs the container. Contract:

- **Base image** — Ubuntu + Node + `@anthropic-ai/claude-code` + git, jq, ripgrep, curl. Non-root user `claude`.
- **Workspace mount** — `$(pwd):/workspace` (read-write). CLAUDE.md and ARCHITECTURE.md live here; `init-firewall.sh` chmodds both to `0444` at startup.
- **Firewall** — iptables drops all egress by default; `init-firewall.sh` allowlists only what's needed.
- **NTFY_TOPIC** — passed as env var.
- **Caps** — `--cap-add=NET_ADMIN --cap-add=NET_RAW` for iptables.

```bash
export NTFY_TOPIC=ralph-<name>-<random>   # add to shell profile
bash ralph.sh          # execution mode (default)
bash ralph.sh plan     # breakdown mode — generates task files from plans
touch STOP             # stop from any terminal
tail -f .ralph/loop.log
```

### Firewall allowlist

Minimum egress domains:

- `api.anthropic.com` — Claude API
- `github.com`, `objects.githubusercontent.com`, `codeload.github.com` — git
- `registry.npmjs.org`, `registry.yarnpkg.com` — node packages
- `pypi.org`, `files.pythonhosted.org` — python packages
- `ntfy.sh` — phone notifications

Extra domains go in `ARCHITECTURE.md` under a `## Firewall additions` section and get passed to `init-firewall.sh`. Never add globally.

### Why this is safe

The two failure modes for an unsupervised agent:
1. Destroying files outside the project — the container can't reach them
2. Hitting the wrong endpoint — the firewall blocks everything not on the allowlist

Worst case: messes up files inside the project — git makes that recoverable.

### .gitignore additions

```
STOP
.ralph/
```

Commit `BLOCKED.md` and `ARCHITECTURE_REVIEW.md` — they're useful history and need to be visible for human review.

## Read-only Files and the Review Pattern

Two files are inputs to the agent, never outputs:

- **CLAUDE.md** — loop operating manual. Chmodded `0444` inside the container.
- **ARCHITECTURE.md** — project description. Chmodded `0444` inside the container.

If the agent believes a read-only file needs to change, something more fundamental is happening. That decision belongs to a human.

### The review pattern

When the agent thinks `ARCHITECTURE.md` needs an update:

1. Don't try to edit it — the OS will reject the write
2. Write the proposed change to `ARCHITECTURE_REVIEW.md`. Include: what part changes, why (link the triggering task), the exact proposed new text
3. Note the proposal in the current task .md
4. `echo "ARCHITECTURE review requested — see ARCHITECTURE_REVIEW.md" > STOP` and exit

Human reviews, edits ARCHITECTURE.md manually, deletes ARCHITECTURE_REVIEW.md, resumes the loop. If rejected, update the task to work within the existing architecture.

Same pattern applies for CLAUDE.md → `CLAUDE_REVIEW.md`. Should be rare — CLAUDE.md is working standards, not something that should emerge from a single task.

### Why not let the agent edit it?

1. **ARCHITECTURE.md is the spec.** The agent works from the spec; the human owns the spec. Letting the agent edit its own spec breaks the chain.
2. **Drift.** If the agent quietly evolves the spec to match what it's doing, the doc stops being a check on the agent and becomes a record of what it already did.
