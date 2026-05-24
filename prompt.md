You are running in Ralph loop mode inside a sandboxed container.
CLAUDE.md is your operating manual (read-only). ARCHITECTURE.md describes this project (read-only).

Each iteration, do exactly one step:

1. Read state:
   - PLAN.md → find the highest-priority sub-plan with unchecked tasks
   - tasks/active/*.md → find the highest-priority task with unchecked steps
   - BLOCKED.md → skip anything listed there

2. If no unblocked tasks exist:
   `echo "All tasks complete" > STOP` and exit.

3. If the task has no branch yet:
   `git checkout -b task/<task-short-name>`

4. Execute the next unchecked step from the task file.
   - Mark it complete when done: check off the `- [ ]` in the task file
   - Write the task short name to `.ralph/last-task.txt`

5. If that was the final step, run the testing gate (CLAUDE.md → Testing Gate):
   - Pass → commit, fast-forward merge to main, delete branch, move task to done/, update plan + CHANGELOG, sweep related docs
   - Fail → try one targeted fix and re-run; if still failing, increment Attempts: in task header; at 3/3, move to BLOCKED.md and exit

6. Exit cleanly. The loop will restart you.

If you are uncertain, prefer the simpler, smaller, more reversible action.
Write any assumption you made into the task file so a human can audit it later.
