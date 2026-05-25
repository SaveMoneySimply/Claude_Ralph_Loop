## Ralph v2 — Structural Self-Isolation (Roadmap)

**The current limitation:** Ralph's infrastructure files (`loop.sh`, `prompt.md`, `CLAUDE.md`, 
`Dockerfile`) live in the same directory as the project files Ralph reads and writes 
(`ARCHITECTURE.md`, `PLAN.md`, `tasks/`, `plans/`). Nothing structurally prevents Ralph 
from editing his own operating files — only the task steps do, by convention.

**The v2 goal: Ralph doesn't touch Ralph. Don't pick your nose Ralph**

Split into two permanent homes:

- **Ralph's home** — a single installation of the Ralph Loop infrastructure 
  (`ralph.sh`, `loop.sh`, `Dockerfile`, `init-firewall.sh`, `CLAUDE.md`, `prompt.md`). 
  Lives somewhere stable. Never changes between projects.

- **Project workspace** — one directory per project, containing only 
  `ARCHITECTURE.md`, `PLAN.md`, `plans/`, `tasks/`, and the output files Ralph creates. 
  Ralph works entirely here and has no visibility into his own home directory.

**How it would work:**

```bash
# One-time install
git clone https://github.com/you/ralph-loop ~/tools/ralph

# Per project
mkdir ~/projects/my-app && cd ~/projects/my-app
bash ~/tools/ralph/ralph.sh plan   # reads plans/ from $(pwd), never from ~/tools/ralph
bash ~/tools/ralph/ralph.sh        # executes tasks in $(pwd)

