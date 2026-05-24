# Working Standards — Matt & Claude

These preferences apply across all projects.

## File scope

This file (`CLAUDE.md`) lives at the **project root** and is checked into the repo. This repo is a base template — fork it for new projects. CLAUDE.md travels with the fork and applies working standards for that project. Working standards only — no project-specific facts.

Each project has its own **`ARCHITECTURE.md`** at its root. That's where project facts live: stack, runtime, key folders, page map, deploy topology, test command. The agent reads both each session — working standards from this file plus project facts from ARCHITECTURE.md.

**Both files are read-only to the agent.** In loop mode, `init-firewall.sh` chmodds both `CLAUDE.md` and `ARCHITECTURE.md` to `0444` at container init. If the agent thinks either needs to change, it writes a proposal and stops for human review — see "Read-only files and the review pattern" at the end.

## Two modes: interactive vs loop

Claude runs in one of two modes. Several rules flip depending on which is active.

- **Interactive mode** — Matt is in the conversation. Default. All rules below apply as written.
- **Loop mode (Ralph)** — Claude is running autonomously inside a sandboxed container, picking work from `PLAN.md` and `tasks/active/` and looping until done. Rules marked *Loop mode:* override the interactive default when this mode is active.

The mode is declared in the loop's `prompt.md` (e.g. "You are running in Ralph loop mode."). If the prompt doesn't say so, assume interactive.

## Communication

- **Confirm before building** — For any UI or feature change, confirm understanding of exactly what's wanted before writing code. Use "let me make sure I understand..." for anything with visual or behavioral nuance. Simple unambiguous changes (fix a typo, change one class) can go straight to implementation.
  - *Loop mode:* Don't confirm — act, test, self-correct. If the task .md is ambiguous, pick the most plausible reading, note the assumption in the task file, and proceed. Genuine blockers go to `BLOCKED.md` and the loop moves to the next task.
- **Plain language** — No jargon. Warm, honest, accessible tone in all responses and UI copy.
- **Short answers** — Match the complexity of the question. A simple question gets a direct answer, not headers and paragraphs.

## Building

- **Simple first, always** — Default to the simplest solution. When two approaches exist, pick the simpler one. If something is getting complicated, stop and ask if there's a simpler way.
  - *Loop mode:* If something is getting complicated, write the simpler alternative as a note in the task .md and try it. Don't ask.
- **One change at a time** — Make a change, let it be tested before moving on. Don't stack multiple changes before getting feedback.
  - *Loop mode:* Same rule — one task per iteration, tests run, then exit. The next iteration picks up the next change.
- **Plan before significant work** — Document plans in .md files and get alignment before building. Plans are living documents, not one-time artifacts.
  - *Loop mode:* Plans still get written, but alignment is implicit — the loop picks up planned items in priority order.

## Debugging

- **Ask before iterating** — When something isn't working, ask for console errors or DevTools output before trying multiple fixes. Don't iterate blindly through solutions.
  - *Loop mode:* No human to ask. Capture the failing output (test output, build log, runtime error) into the task .md and try one targeted fix per iteration. If the same task fails three iterations in a row, move it to `BLOCKED.md` with the captured evidence.
- **Check the obvious first** — Missing closing tags, wrong scope, inherited CSS — look for simple root causes before complex ones.

## Git

- **Provide commit messages as text** — Matt handles his own git workflow. Suggest commit messages as copyable text, don't run git commands unless explicitly asked.
  - *Loop mode:* Claude runs git itself — commits per task with the message it would have suggested, no asking.
- **Auto-suggest commit message** — At the end of a logical chunk of work, automatically provide a commit message without being asked. When Matt says "commit", immediately give the statement — no preamble, no asking if he wants one. After the commit statement, give one short sentence suggesting what to do next. Always follow the commit statement with one short sentence suggesting what to do next — whether triggered by "commit" or auto-suggested. If working through a task list, show the current list state after the next-step suggestion so Matt can see what's remaining.
- **No co-author lines** — Unless asked.

## Git Isolation

- **Create a branch before starting any non-trivial task** — Run `git checkout -b task/<short-name>` before writing any code. Branch name should match the task .md filename (e.g. `task/fix-cashback-cpp`). Do this without asking — it's always the right move.
- **Merge short — implementation done + testing gate passed = merge** — As soon as the testing gate passes (see "Testing Gate" below), fast-forward merge to main and delete the branch. Don't wait for post-deploy verification; that's tracked in `TEST.md` against the deployed main, not against feature branches. The task .md can stay in `tasks/active/` after the merge if TEST.md items are still pending — the branch shouldn't. Short-lived branches don't pile up and don't surprise anyone.
- **Don't run parallel branches that touch shared files** — Branches fight over `CHANGELOG.md`, `TEST.md`, `PLAN.md`, and `.claude/settings.json` every time. For solo work, serialize: finish → merge → delete → start the next branch from updated main. For genuinely parallel work that touches different code areas, use `git worktree add ../<project>-<task> main` so each chat session gets its own physical directory and branch — but note that worktrees prevent file collisions, not merge conflicts on shared files.
  - *Loop mode:* Inherently serialized — one iteration at a time, one branch at a time. Don't run multiple loops against the same project.
- **Verify branch state when resuming a session** — Before continuing work, run `git status` and `git branch --show-current`. State may have changed since the last session (commits made elsewhere, branches created in another window, files modified by other tools). Investigate any surprises before overwriting — they often represent the user's in-progress work in another thread.
- **Parallel agents use worktree isolation** — When spawning subagents for tasks that can run in parallel, always pass `isolation: "worktree"` to the Agent tool. This gives each agent its own directory and branch so they don't conflict.

## General

- **Stop and ask** — If something is getting more complex than expected, stop and ask rather than pushing through with an approach that might not be right.
  - *Loop mode:* Push to `BLOCKED.md` with a clear note, then move on.
- **Test assumptions** — When unsure how something works (a CSS property, a framework behavior), test it rather than assuming.

## Context Management

- **Suggest changing models when appropriate:**
  - On Opus + straightforward task (UI tweak, simple bug fix, writing copy) → suggest Sonnet to save credits
  - On Sonnet + genuinely hard reasoning (architecture, subtle debugging, big refactors) → suggest Opus
  - Conversation getting long and Sonnet hits the credit wall → suggest ending the session and starting fresh on Sonnet
  - *Loop mode:* N/A — the loop invocation pins the model.

- **Suggest using a subagent when:**
  - A task needs searching across many files ("find all usages of X") → use the Explore agent
  - Research that would otherwise pull a lot of content into the main context → use general-purpose
  - Planning a multi-step implementation → use the Plan agent
  - Goal: keep the main conversation lean by pushing exploration into agents that just return summaries

- **Suggest creating a skill when:**
  - Matt asks for the same multi-step workflow more than once or twice
  - A repeatable process emerges with clear steps (e.g., "audit page for accessibility", "review Tailwind for unused classes")
  - Skills live in `~/.claude/skills/` and are invoked with `/skill-name`

- **Suggest ending the session when:**
  - We've completed a logical chunk of work
  - Conversation has grown long enough that responses slow or context gets fuzzy
  - Starting fresh with CLAUDE.md context will be more productive than continuing

## .md File Architecture

Every project follows a consistent doc structure so future sessions can orient quickly and direction doesn't drift.

### Folder structure

- **Project root** holds index files and orientation docs only:
  - `README.md` — what it is, how to run it
  - `ARCHITECTURE.md` — what this project is (stack, runtime, brand, key folders, page map, deploy topology, test command). **Read-only to the agent.**
  - `CHANGELOG.md` — log of completed tasks (date, name, one-line description, link to archived task .md)
  - `PLAN.md` — thin index pointing at sub-plans in `plans/`
  - `ROUTINES.md` — thin index pointing at routines in `routines/`
  - `TEST.md` — one-time verifications (post-deploy) + recurring test cadence
  - `BLOCKED.md` — tasks the loop couldn't make progress on, with captured evidence (loop mode only)
  - `ARCHITECTURE_REVIEW.md` — agent's proposed changes to ARCHITECTURE.md, awaiting human review (created only when needed)
  - `prompt.md` — what Claude reads each loop iteration (loop mode only)
  - `loop.sh` — the loop runner inside the container (loop mode only)
  - `ralph.sh` — CLI wrapper that builds and runs the container (loop mode only)

- **`plans/`** — sub-plans, one file per area (e.g. `calculator_plan.md`, `monetization_plan.md`). Each is a living document for that domain. `PLAN.md` at root just lists them with status.

- **`routines/`** — operational routines, one file per recurring process (e.g. `card_data.md`). Use `routines/sources/` (or similar subfolders) for reference data that supports a routine.

- **`reference/`** — background research, third-party info, or external context that isn't itself a plan or routine.

- **`tasks/active/`** — active task .md files (each with a checklist)
- **`tasks/done/`** — archived completed task .md files
- **`_archive/`** — superseded docs kept for historical reference (renamed if needed to avoid collisions)

### How plans and tasks connect

Plans and tasks are two levels of the same hierarchy:

- A **plan** (in `plans/`) contains a checklist of things to do for that area
- A **task** (in `tasks/active/`) is one of those items being actively worked on
- Each plan checkbox links to its task file once work begins, so you can trace from the plan to the task and back

Example inside `plans/calculator_plan.md`:

```
- [ ] Fix cash back mode CPP — [task](../tasks/active/fix-cashback-cpp.md)
- [x] Add program type badges — [done](../tasks/done/add-program-badges.md)
```

When the task is verified and moved to `tasks/done/`, the link target still resolves (just update `active/` to `done/` in the link) and the checkbox gets ticked.

### Task settings — recommend model, effort, and thinking

When creating a new task .md (or before starting non-trivial work), recommend three settings upfront and capture them at the top of the task file. This sets expectations for the session and lets future sessions opening the task file know what setup matched the work.

**Model:**
- **Haiku** — trivial mechanical work (typo fixes, find/replace, simple formatting)
- **Sonnet** (default) — most coding, UI work, standard debugging, writing copy, doc updates
- **Opus** — architecture decisions, subtle debugging, complex refactors, hard design synthesis

**Effort level** (set via the `/` menu — 5 levels):
- **Lowest / Minimal** — purely mechanical changes; no exploration needed
- **Low** — well-understood tweak; one or two files; no agent help
- **Medium** (default) — standard task; confirm understanding, use TodoWrite, work through it
- **High** — complex multi-step work; plan mode upfront, consider dispatching Explore/Plan agents
- **Highest / Maximum** — architecture decisions, big refactors, multiple unknowns; full plan mode + multiple agents

**Extended thinking:**
- **Off** — mechanical changes, copy edits, well-understood patterns
- **On** — debugging, design tradeoffs, anything requiring reasoning chains before responding

Capture the recommendation in the task .md header. Loop mode adds two more fields — `Attempts` and `Tokens estimated` (see "Testing Gate" and "Autonomous Loop"). Example:

```
# Task — Fix cash back CPP

**Model:** Sonnet · **Effort:** Medium · **Thinking:** On
**Attempts:** 0/3 · **Tokens estimated:** 50000 · **Test command:** npm run build && npm test

## Smoke test
- Open `/calculator`, switch to cashback mode, enter $100 → should show 1.5% CPP

## Checklist
- [ ] ...
```

### Per-task workflow

Each discrete piece of work gets its own .md file with a checklist:

1. **Create** `tasks/active/<short-name>.md` with a clear checklist, scope notes, the recommended settings (including `Tokens estimated`), and a `## Smoke test` section describing what "done" actually looks like in the running app
2. **Link from the plan** — in the relevant `plans/<plan>.md`, update the matching checklist item to point at the new task file
3. **Work** through the checklist, marking items complete as we go
4. **Run the testing gate** (see "Testing Gate" below):
   - *Interactive mode:* report gate results to Matt; ask for verification on anything mechanical tests can't cover (UI, taste, real-world behavior)
   - *Loop mode:* on pass, proceed to step 5; on fail, retry per the gate's retry rules
5. **On a passing gate (and Matt's verification, if interactive):**
   - Move the file from `tasks/active/` to `tasks/done/`
   - Update the link in the plan from `tasks/active/...` to `tasks/done/...` and check off the box
   - Append an entry to `CHANGELOG.md` (date, task name, one-line description, link to archived task .md, link to the plan it served)
   - **Sweep other related docs** for updates triggered by this task:
     - `ARCHITECTURE.md` — **never edit directly.** If the task implies an architecture change (new dependency, new key folder, changed deploy, changed test command), write a proposed update to `ARCHITECTURE_REVIEW.md` and surface it for human review. *Loop mode:* write the proposal, then `echo "ARCHITECTURE review requested" > STOP` and exit.
     - `PLAN.md` (root) — if a sub-plan was completed/archived
     - Routines in `routines/` — if operational behavior changed
     - Reference docs — if background facts changed
     - Surface the list of "docs touched" in the verification message so the user can review
6. **Context hygiene:** after archiving + CHANGELOG + doc sweep, suggest `/compact` (same session) or a fresh session before the next task. Long sessions across many tasks risk the context-credit wall; one-task-per-session with good docs is the safer default. *Loop mode skips this — each iteration is already a fresh invocation.*

### Per-sub-plan workflow

Sub-plans (in `plans/`) follow the same lifecycle as tasks, just at a larger granularity:

1. A sub-plan is a living document while the area is active — its checklist grows or evolves as work progresses
2. As items get worked, they spawn task files (see "How plans and tasks connect" above)
3. When every item is done and direction is stable, archive the whole sub-plan: move to `_archive/<name>.md`, remove from the `PLAN.md` root index
4. Append a CHANGELOG entry noting the sub-plan completion (with link to the archived file)

### How TEST.md works

`TEST.md` is two checklists in one file at project root — lives alongside `PLAN.md` and `ROUTINES.md` but tracks verifications instead of plans or routines.

- **One-time tests** — verifications a task couldn't run inline because they need a deploy, real traffic, or manual click-through. Grouped under a heading per task with a link back to the task .md so the *why* survives.
- **Routine tests** — recurring checks (weekly / monthly / scheduled one-offs). Living checklist — uncheck items after each run so the cadence stays visible.

How TEST.md interacts with the per-task workflow:
- If a task's verification can be done inline (curl, unit test, type check), do it before moving the task to `tasks/done/` — don't pollute TEST.md
- If a task's verification needs production state (deploy, real users, third-party dashboard), move those items into TEST.md's "One-time tests" with a link back to the task .md. The task stays in `tasks/active/` until those TEST.md items are ticked, then moves to `tasks/done/`
- Routine items don't belong to any single task — they're cross-cutting (e.g. "compare two analytics streams weekly") and live in TEST.md from creation

### Why this works

- A fresh session reads CLAUDE.md (working standards) + ARCHITECTURE.md (project facts) + CHANGELOG.md (history) + `PLAN.md` (current plans) + `TEST.md` (open verifications) and is oriented in minutes
- Index files (PLAN.md, ROUTINES.md) never duplicate content — they only point at sub-docs, preventing drift
- Completed work doesn't grow ARCHITECTURE.md or eat context every session
- Past task .md files stay searchable without being loaded by default
- Recent language wins — older docs that get superseded are archived (renamed if needed), not left at root to mislead
- The doc sweep on verification keeps canonical docs from drifting out of sync with the code — and ARCHITECTURE.md drift is caught by the review pattern instead of silently accepted

## Autonomous Loop (Ralph)

The Ralph Loop is the simplest possible autonomy: a shell `while` loop that runs Claude Code headless against a prompt file, over and over, until a stop signal appears. State lives in `.md` files in the project — Claude reads them at the start of each iteration, picks the highest-priority work, does one slice, updates the files, and exits. The next iteration starts fresh.

The loop is dumb on purpose. The agent gets smarter; the loop stays simple.

### The loop itself

`loop.sh` runs *inside* the container (started by `ralph.sh` from the host). Sketch:

```bash
#!/usr/bin/env bash
set -u
i=0
while [ ! -f STOP ]; do
  i=$((i+1))
  echo "── iteration $i ──"
  cat prompt.md | claude -p --output-format json --dangerously-skip-permissions \
    | tee ".ralph/iter-$i.json"
  # next session will add: parse usage, update task .md token totals,
  # check 2× budget per task, write STOP if exceeded
  sleep 2
done

REASON=$(cat STOP 2>/dev/null || echo "Loop stopped")
echo "$REASON — exited after $i iterations."

if [ -n "${NTFY_TOPIC:-}" ]; then
  curl -fsS -d "$REASON ($i iterations)" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null || true
fi
```

Start it: `bash ralph.sh` (from the host).
Stop it: `touch STOP` from any terminal — or Claude writes its reason: `echo "All tasks complete" > STOP`.

`--dangerously-skip-permissions` is safe here *because the loop runs inside the container* (see Containment). Outside the container, never use this flag.

### `prompt.md` — what Claude reads each iteration

Lives at project root. Stays short (under 100 lines) because Claude re-reads it every iteration. Starter template:

```md
You are running in Ralph loop mode in a sandboxed container.
CLAUDE.md is your operating manual — project working standards (read-only to you).
ARCHITECTURE.md describes this specific project (read-only to you).

Each iteration, you must:

1. Read state:
   - ARCHITECTURE.md (read-only — what this project is)
   - PLAN.md (current plans index) and any plans/*.md it points to
   - tasks/active/*.md (open tasks, with their headers)
   - BLOCKED.md (skip anything listed here)
   - TEST.md (open verifications)

2. Pick the highest-priority unblocked task. If nothing is left:
   `echo "All tasks complete" > STOP` and exit.

3. Branch: `git checkout -b task/<short-name>` (skip if branch already exists).

4. Do one slice of work — one logical change. If the task is large, do the smallest
   useful slice and let the next iteration continue.

5. Run the testing gate (CLAUDE.md → Testing Gate). On failure:
   - Try one targeted fix and re-run the gate
   - If still failing, increment `Attempts:` in the task header
   - At 3/3 attempts, move the task to BLOCKED.md with the failure output and exit

6. If the gate passes and the checklist is complete:
   - Commit with a clear message
   - Fast-forward merge to main, delete the branch
   - Move task .md from active/ to done/
   - Update the linking plan and CHANGELOG
   - Sweep related docs (CLAUDE.md → Per-task workflow step 5)
   - If a sweep would touch ARCHITECTURE.md, write the proposal to
     ARCHITECTURE_REVIEW.md and `echo "ARCHITECTURE review requested" > STOP`

7. Exit cleanly. The loop will restart you.

If you're ever uncertain, prefer the simpler, smaller, more reversible action.
Write any assumption you made into the task .md so a human can audit later.
```

### State files Claude reads/writes per iteration

| File | Purpose | Owner |
|---|---|---|
| `CLAUDE.md` | Project working standards (chmod 0444) | human only — agent reads |
| `ARCHITECTURE.md` | What this project is (chmod 0444) | human only — agent reads, proposes changes via review |
| `PLAN.md` | Index of sub-plans + priority order | shared |
| `plans/*.md` | Each domain's checklist | shared |
| `tasks/active/*.md` | Open tasks with checklist + headers | Claude |
| `tasks/done/*.md` | Archived completed tasks | Claude |
| `CHANGELOG.md` | Append-only log | Claude |
| `BLOCKED.md` | Tasks Claude can't make progress on | Claude |
| `ARCHITECTURE_REVIEW.md` | Proposed changes to ARCHITECTURE.md | Claude writes, human reviews |
| `TEST.md` | Post-deploy + recurring verifications | shared |
| `STOP` | Sentinel — loop exits when present; contents become the notification body | either |
| `.ralph/*` | Per-iteration JSON output for usage tracking | Claude |

### Stop conditions

The loop exits when any of:
- `STOP` file exists (contents = reason, becomes notification body)
- A task's actual token usage exceeds 2× its `Tokens estimated` budget (see "Usage budget" below)
- The same task has failed its testing gate 3+ times and there's no other unblocked work
- The agent decides ARCHITECTURE.md needs to change (review pattern)
- Manual stop from any terminal: `touch STOP`

### Usage budget

Each task's header declares `Tokens estimated: <n>` — a rough order-of-magnitude guess at total output tokens for the task across all iterations (~10k small, ~50k medium, ~200k large).

Each iteration writes its JSON output to `.ralph/iter-<n>.json`. The loop sums `.usage.output_tokens` for the current task across iterations. When the running total exceeds 2× the estimate, the loop writes a STOP with the reason — something is clearly off and human review is cheaper than letting it spiral.

The full sum/compare logic lives in the next session's `loop.sh`. The contract: estimate honestly upfront, accept 2× as the alarm, surface the overrun loudly.

### Phone notifications

When the loop stops (any reason), `loop.sh` fires a notification via **ntfy.sh** — free, no signup, no account. Install the ntfy app on your phone, subscribe to a topic name unique to you (e.g. `ralph-matt-7a3k`), and the loop hits it on exit with the contents of `STOP` as the body.

Set `NTFY_TOPIC` as an env var in `ralph.sh` so it's passed through to the container. The firewall allowlist must include `ntfy.sh` (see Containment).

Alternatives if you outgrow ntfy: Pushover (paid once, more polished), a Discord/Slack webhook, or self-hosted ntfy. The loop only changes which URL it curls.

### When *not* to use Ralph

- Anything touching production credentials, billing, live deploys, or paid third-party APIs at scale — keep a human in the loop.
- Greenfield architecture decisions — write the plan with a human first in interactive mode, *then* let Ralph execute it.
- UI work where Matt's taste is the spec — confirm the look in interactive mode, let Ralph handle the mechanical follow-through.

## Testing Gate

No task moves from `tasks/active/` to `tasks/done/` until the testing gate passes. This applies in both modes.

### What "tests pass" means

Every project's **ARCHITECTURE.md** declares its test command. If unset, the default chain is:

1. **Build** — `npm run build` (or project equivalent). Must complete with zero errors.
2. **Type check** — `npm run typecheck` if the script exists. Must be clean.
3. **Lint** — `npm run lint` if the script exists. Warnings ok, errors not.
4. **Unit tests** — `npm test` if the script exists. All pass.
5. **Smoke test** — a focused check of the specific thing the task changed (curl a route, render the component, parse a sample input). Defined in the task's `## Smoke test` section.

The first four are mechanical. The smoke test is task-specific.

### In loop mode

The gate runs automatically before the move-to-done step. Failures don't pause for human input:

1. First failure → try one targeted fix, re-run the gate
2. Second failure → try a different targeted fix, re-run the gate
3. Third failure → move the task to `BLOCKED.md` with link back to the task .md, full output of the failing test, and a brief note on what was tried. End the iteration.

The `Attempts:` field in the task header tracks this across iterations so a task that fails once, gets picked up next iteration, and fails again counts correctly.

### In interactive mode

After the checklist is complete, run the gate and report the result to Matt before moving to done. Don't move on a failing gate; ask.

## Containment

Loop mode runs with `--dangerously-skip-permissions`, which would be reckless on the host machine. The whole pattern only works because Claude runs inside a container that can't see anything outside the project — and even inside the project, can't write to the files we mark read-only.

### Recommended setup: CLI wrapper with plain Docker

A single `ralph.sh` at project root builds and runs the container. (Detailed scripts come from the next session — this section is the contract those scripts honor.)

- **Base image** — Ubuntu + Node + `@anthropic-ai/claude-code` (via npm) + git, jq, ripgrep, curl. Non-root user.
- **Workspace mount** — `$(pwd):/workspace` (read-write for the agent's work).
- **CLAUDE.md and ARCHITECTURE.md** — both live in `/workspace` (project root). At container init, `init-firewall.sh` runs `chmod 0444 /workspace/CLAUDE.md /workspace/ARCHITECTURE.md` so the non-root agent can't write to either at the OS level. No separate host mount needed.
- **Firewall** — iptables blocks all egress by default; init script allowlists only what's needed.
- **NTFY_TOPIC** — passed through as env var so `loop.sh` can curl notifications.
- **Caps** — `--cap-add=NET_ADMIN --cap-add=NET_RAW` so the firewall init can run iptables.

Usage:

```bash
export NTFY_TOPIC=ralph-matt-<random>   # one-time, add to your shell profile
bash ralph.sh                            # start
touch STOP                               # stop (from any terminal)
tail -f .ralph/loop.log                  # observe
```

VS Code stays in the picture as your editor — open the workspace, watch files change, watch the log in a terminal pane. The container just runs the loop, not the editor.

### Firewall allowlist

Minimum domains the container needs egress to:

- `api.anthropic.com` — Claude API
- `github.com`, `objects.githubusercontent.com`, `codeload.github.com` — git operations
- `registry.npmjs.org`, `registry.yarnpkg.com` — node deps
- `pypi.org`, `files.pythonhosted.org` — python deps (if relevant)
- `ntfy.sh` — phone notifications

Everything else is dropped. If a project genuinely needs more (a specific API for testing, a CDN), add it project-by-project in the project's ARCHITECTURE.md and pass it through to the firewall init — never globally.

### Why this makes Ralph safe

The two failure modes for an unsupervised agent are:

1. Destroying files outside the project (rm in the wrong directory, overwriting dotfiles, leaking secrets)
2. Hitting the wrong network endpoint (paid APIs at scale, prod databases, sending real email)

The container blocks both at the OS level. Worst case becomes "messes up files inside the project" — and git protects against that: every branch is recoverable, main is fast-forward only, and the merge happens after the testing gate.

`--dangerously-skip-permissions` is safe here because it bypasses Claude Code's *own* permission prompts, not OS file permissions. A `:ro` mount or chmod 0444 file rejects writes regardless of the flag.

### .gitignore additions

```
STOP
.ralph/
```

Commit `BLOCKED.md` and `ARCHITECTURE_REVIEW.md` — they're useful history and need to be visible for review.

### README additions

```
## Running Ralph (autonomous loop)
1. Set NTFY_TOPIC in your shell: `export NTFY_TOPIC=ralph-<your-name>-<random>`
2. From project root: `bash ralph.sh`
3. To stop: `touch STOP` from any terminal
4. Phone alerts via the ntfy.sh app subscribed to your topic

See CLAUDE.md → Autonomous Loop for the full pattern.
```

## Read-only files and the review pattern

Some files are inputs to the agent, not outputs. The agent reads them to orient or follow instructions but must never modify them. Current read-only list:

- **CLAUDE.md** — project working standards. Lives at project root, checked into git. Chmodded `0444` inside the container.
- **ARCHITECTURE.md** — per-project description. Chmodded `0444` inside the container.

If the agent believes a read-only file needs to change to complete a task, that's a signal something more fundamental is happening — a new architectural direction, a change in working standards. Those decisions belong to a human, not the agent.

### The review pattern

When the agent thinks ARCHITECTURE.md needs an update:

1. **Don't try to edit it** — the OS will reject the write
2. Write the proposed change to `ARCHITECTURE_REVIEW.md` at project root. Include:
   - What part of ARCHITECTURE.md would change
   - Why the change is needed (link the triggering task)
   - The exact proposed new text
3. Note the proposed change in the current task .md so it's discoverable from the task
4. **Loop mode:** `echo "ARCHITECTURE review requested — see ARCHITECTURE_REVIEW.md" > STOP` and exit. The phone notification fires with that message.
5. **Interactive mode:** surface the proposal at the end of the response; don't proceed with the task until Matt decides.

The human reviews. If accepted: Matt edits ARCHITECTURE.md manually, deletes ARCHITECTURE_REVIEW.md, resumes the loop. If rejected: Matt updates the task to work within the existing architecture.

If CLAUDE.md ever needs to change, the same pattern applies with `CLAUDE_REVIEW.md` — but this should be rare. CLAUDE.md is working preferences, not anything that emerges from a single task.

### Why not let the agent just edit it?

Two reasons:

1. **ARCHITECTURE.md is the spec.** The agent works from the spec; the human owns the spec. Letting the agent edit its own spec breaks the chain.
2. **Drift.** If the agent can quietly evolve the spec to match whatever it's doing, the doc stops being a check on the agent and becomes a record of what the agent already did. That's the opposite of what it's for.
