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

4. Write the task short name to `.ralph/last-task.txt`.

5. Execute the next unchecked step from the task file.
   Mark it complete: change `- [ ]` to `- [x]` in the task file.

6. After executing the step, determine if it succeeded or failed:
   - **Pass:** the step's acceptance criterion is met (tests pass, output is correct, etc.)
     - If this was the FINAL step: also run the task's test command and smoke test
     - Write `pass` to `.ralph/last-result.txt`
   - **Fail:** the step could not be completed or tests failed
     - Write `fail` to `.ralph/last-result.txt`
     - Write the error details to `.ralph/last-failure.txt`
   - **In progress:** this was not the final step and it succeeded
     - Write `pass` to `.ralph/last-result.txt`
     - (loop.sh treats pass on a non-final step as progress, not task completion)

7. On final-step pass:
   - Commit all changes: `git commit -m "<task-short-name>: <one-line summary>"`
   - Fast-forward merge to main: `git checkout main && git merge --ff-only task/<name> && git branch -d task/<name>`
   - Move task file: `mv tasks/active/<name>.md tasks/done/<name>.md`
   - Update the plan: mark checkbox done, update link to `tasks/done/`
   - Append to CHANGELOG.md: `date | task name | one-line description | link to task file`
   - Sweep related docs if operational behavior changed (routines/, PLAN.md)
   - If ARCHITECTURE.md needs updating: write proposal to ARCHITECTURE_REVIEW.md and `echo "ARCHITECTURE review requested" > STOP`

8. Exit cleanly. The loop will restart you.

If uncertain, prefer the simpler, smaller, more reversible action.
Write any assumption into the task file so a human can audit it later.
