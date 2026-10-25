# Remote Task Claim implementation plan

**Goal:** Give cooperating local, remote and child executors one remotely verified execution right, without replacing Backlog.

**Architecture:** An independent `coord/task-claims` Git branch stores one JSON state. Every mutation creates a child commit and uses an ordinary push as CAS; rejected pushes re-read and revalidate the entire state. Task ancestry, canonical path prefixes and shared module names conflict. A monotonically increasing generation fences stale sessions. Leases use UTC client clocks (synchronized clocks are required).

**Tech stack:** Node.js 22 built-ins, Git, existing Node test runner and GitHub CLI.

1. Snapshot accessible tasks, worktrees, dirty paths, branches and remote PRs; remote machines remain unknown. Initialize a paused migration with reservations and a narrowly scoped bootstrap owner. Preserve all historical work.
2. Write black-box tests invoking real Node processes in separate clones against disposable Git bare remotes. Observe missing CLI failure, then implement acquisition, renewal, check, release, recovery, scope expansion and conservative adoption.
3. Add controlled `run`, `worktree`, `integrate` commands and shared Git pre-commit/pre-push gates. Bind each operation to an explicit session, branch and generation; check changed paths. Heartbeat long-running children and terminate them on renewal failure. Preserve unrelated hooks by refusing replacement.
4. Document executable entry commands for every executor, install gates locally, retain migration quarantine until old executors acknowledge stopping and unknown machines are reviewed. Assignee stays Furinya; claim agent/session is Executor.
5. Run targeted real-Git tests, then serialize full quality gates with the Windows runner. Review failure cases and current-SHA CI before squash merge. Release, verify remote state, preserve recoverable merged head and remove only this clean worktree/branch.

The implementation is authorized by the user's detailed P0 request. No game content, milestones or historical work is changed. Native Git hooks are a lightweight cooperative boundary, not an adversarial security boundary; remote merge and ownership are separate systems and cannot be one atomic transaction without a server.

6. Repair the paused migration deadlock using an explicit CAS reconciliation manifest. Keep every original reservation, require real source ownership and HEAD/index/file fingerprints, enumerate single-parent delivery commits and exact files, designate one executor and serial stages, and retain all outside unknowns. Recheck external handoffs throughout execution. Actual executor-targets may resume their own authorized work; parked sources remain frozen. Exercise rejection, CAS competition, intermediate release/recovery and exact current-SHA CI before integration; registering a manifest is a separate evidence-based action, not automatic cleanup.
