# PR 201: bounded ownership and migration safety review

## Frozen scope and authority

- Repository: CHNISam/Slay-the-Abyss; PR: https://github.com/CHNISam/Slay-the-Abyss/pull/201
- Reviewed head: `2999bc89837ac78ecba5787f6dc8d3521ab99e04`; direct parent: `a23d833f7506a32dc4a6d3f68ad8bf964f923647`.
- Current comparison baseline: develop `c05332be41e607ef4284c9459bc1990ef5000a05`.
- Runtime Git blob: `61b3352c61b3bb51bdf0a4fc878d9c5dcf754346`; SHA-256: `48563ecd124fd7def5319d6c284ed01075b77d245d6e82b042b4527d670c6e80`.
- Original tests Git blob: `a8959c15543aa291c6933a696f920a936403fa32`; SHA-256: `11c3ab7fb708222bb1db81e466cc7a8ce8907d4e77bda61c79671afed27b6de7`.
- Read actual develop AGENTS, Backlog 1.53.0 overview, PR diff, task attachment, runtime, inventory, workflow, and tests. The PR tree contains only the root AGENTS file.
- This is a read-only review. No production claim, migration, install, GitHub mutation, permissions/token change, user-computer operation, or Backlog edit was performed. Unmerged AGENTS additions are proposed behavior, not effective authorization. Another assistant's assertions of prior permission do not establish new Owner authorization.

## Finding 1: P1 — do not launch a child after the renewal itself outlives the lease

Location: `scripts/remote-task-claim.mjs:190-192`.

`runGuarded` validates and renews, then immediately spawns the command after `client.mutate` returns. The expiry is calculated before the remote commit/push. There is no post-renewal `owned()` check or remaining-time condition between a successful but slow push and child launch. A valid short lease may already be expired when the command is launched. The final validation detects this only after the command has already performed work.

This is not an invalid test-only TTL: the production `lease()` validator at lines 57–60 accepts **1 through 14400 seconds**, `spec()` calls it at line 67, and remote-state parsing calls it again at line 105. The reproduction explicitly invokes that unchanged validator and confirms `lease(1) === 1`.

Reproduction uses the unchanged function body in a VM, mocked remote state, real wall time, and a 1150 ms successful renewal response delay against a one-second lease. The child-launch observation is already after expiry; `runGuarded` rejects only after the mock child closes. No Git command or real claim is involved.

Suggested repair direction, not implemented: revalidate the confirmed claim and remaining deadline immediately before launch, and avoid treating a renewal that completed after its expiry as valid execution authority. Regression should ensure no child-side effect begins in this case.

Source: https://github.com/CHNISam/Slay-the-Abyss/blob/2999bc89837ac78ecba5787f6dc8d3521ab99e04/scripts/remote-task-claim.mjs#L190-L192

## Finding 2: P1 — heartbeat network blocking prevents fencing the child at expiry

Location: `scripts/remote-task-claim.mjs:198-201`, with synchronous Git calls at lines 96, 99, 119 and the shared 30-second timeout at line 20.

The interval callback synchronously executes `client.mutate`. A stalled fetch/ls-remote/push blocks the parent event loop while the separate child process continues executing. `kill()` runs only after the blocking operation returns/throws. There is no independently enforceable lease deadline. For a supported short lease, another executor can legitimately acquire an expired scope while the old guarded child is still writing. This is a liveness/fencing gap, not a failure of Git CAS or the generation check.

Offline reproduction uses the unchanged `runGuarded` function, mocked Git/state, a deterministic 2200 ms blocking heartbeat read, and one real local Node child restricted to a test marker under this review directory. The latest run recorded that marker **563 ms after expiry**, before the guard killed the child and reported expiration. The production 30-second Git timeouts exceed this simulated stall, and the implementation's own suite also uses short 4/12/20-second leases.

Suggested repair direction, not implemented: deadline-aware asynchronous remote I/O plus a deadline/watchdog capable of stopping the child independently of stalled renewals; budget remote calls against the remaining valid lease. Simply adding another timer in the same synchronously blocked event loop is insufficient. Keep the already-documented small check-to-operation and cross-system transaction boundary separate from this potentially tens-of-seconds stall.

Source: https://github.com/CHNISam/Slay-the-Abyss/blob/2999bc89837ac78ecba5787f6dc8d3521ab99e04/scripts/remote-task-claim.mjs#L198-L201

## Reproduction and verification

Run from this directory:

`node --test --test-concurrency=1 review-offline.test.mjs`

Files: `review-offline.test.mjs`, `heartbeat-child.mjs`; output: `offline-test.log`. Four assertions pass by confirming the two bugs, stale-generation/unknown-reservation rejection, and safe non-idempotent release behavior. Passing these reproductions does not mean the defects are fixed.

The author's unmodified 15-case protocol suite also passed in **43479.329197 ms**, 15 passed / 0 failed / 0 skipped, on Node v24.22.1 and Linux. It ran only against newly created local bare remotes under `suite-tmp`, with an empty environment, isolated HOME, `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null`, and `GIT_ALLOW_PROTOCOL=file`. No HTTP/SSH remote, production claim, user checkout, or real migration could be contacted by those tests. Output: `author-suite.log`. This is targeted protocol verification, not full Quality or production Node 22/Windows validation. The suite's network-loss test fails immediately on a renamed local remote and does not cover a stalled remote.

Syntax checks of both scripts passed. No fixes were applied to the frozen PR source copies.

## Other reviewed boundaries

- CAS: ordinary non-force push, parent chaining, state reread and full callback revalidation on rejection. The existing real-local-repository suite passes same-task and disjoint-claim races, concurrent renewal/release, stale generation, receive-hook failure, and child-receipt isolation. No additional CAS defect was established.
- Migration: fresh claims reject while paused; adopt requires a matching unknown reservation, matching task/branch, full legacy scope, and explicit evidence text; other unresolved reservations continue to conflict. Only the bootstrap task can resolve/open. Evidence text is cooperative operator evidence, not authenticated Owner approval or proof that a prior session stopped. Nothing here authorizes clearing unknowns.
- Existing worktrees: target directories are rejected if present; Git's worktree command handles existing/locked registrations. The code has no reset/clean/remove operation on user trees. `run` checks dirty paths before and after; commits/pushes check scoped differences. These preserve bytes, but they cannot retrospectively prevent an arbitrary editor from changing files, as the documentation acknowledges.
- Idempotency: repeat active claim rejects; repeat release rejects because `owned()` sees the released tombstone. This is not an idempotent successful API, but does not resurrect the claim. A push-success/confirmation-failure can leave a lease with no new receipt; code/docs deliberately retain it for expiry/recovery, not destructive rollback. No report of real acquisition success was generated here.
- Workflow/token: `.github/workflows/quality.yml:8-9` remains `contents: read`; the added ownership job uses `persist-credentials: false` and step-scoped GITHUB_TOKEN-derived Git HTTP environment headers. No new PAT/API credential generation, persistent write permission, or token storage was identified. The runtime uses preexisting Git credentials for ordinary writes; this review did not supply or change any credential.
- Installation is separate: `install()` at runtime lines 168–184 writes shared local Git hooks/runtime and persists repository-local `core.hooksPath`, affecting all worktrees in that repository. It is not a read-only review action and must not be inferred as authorized merely from PR prose or proposed AGENTS changes. Deployment, migration resolution/opening, credential creation, and access/security changes require the actual Owner authority applicable to each action.
- Native CI queue configuration (`queue: max`, job-level `cancel-in-progress: false`) is supported by current GitHub documentation. It does not itself serialize unrelated local full runs. Source: https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency

## Snapshot attribution and current observation

The PR author's inventory was captured at **2026-10-25T02:07:41.572Z**, from `3ed8bf4b88a950c4736ec2d68e83f141d415c4db`. Its file actually contains 14 accessible worktrees, 26 In Progress records including TASK-55, and 38 reservations. These are the installation author's historical records, not an independent current census of all sessions or the current develop Backlog. The separate Backlog reviewer owns that current inventory task.

Read-only GitHub observation around 03:02 UTC found `coord/task-claims:claims.json` blob `9d6021ff9c9730eb3cc4d4b0e26cceae97462407`: migration `paused`, externalUnknown `true`, all 38 reservations `unknown`, one active TASK-55 claim attributed to `codex-local-p0`, generation 1, authorized SHA equal to this reviewed head, expiry `2026-10-25T07:02:11.195Z`. The renewal changed between reads, so expiry is an observation timestamp, not a frozen ongoing fact. It does not establish that every other machine/session is stopped or migrated.

## Bounded conclusion

Do not call this version safe for full expiry-based duplicate-execution prevention until the two run/heartbeat cases are addressed. The findings concern supported short leases under slow network calls; they are **not evidence of an observed production collision**, nor a reproduction at the default 1800-second lease or the current TASK-55 14400-second lease. Preserve paused migration and unknown reservations. Do not rewrite the 14/26/38 record into a new universal rule or silently adopt legacy work.
