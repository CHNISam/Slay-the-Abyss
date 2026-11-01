# Engineering upgrade implementation plan

**Goal:** Turn the supplied upgrade package's four demonstrated false positives and existing Lua boundaries into executable checks.

**Architecture:** Extend existing builders, node:test, Fengari and Quality. Candidate receipts own build identity; validators re-read actual files. Offline checks remain separate from official import, gameplay and human UI review.

**Tech stack:** Node 22.22.1, Lua 5.3/Fengari, luaparse 0.3.1, Ajv 8.20.0, Python/Pillow; Luacheck 1.2.0 adaptation.

The user supplied the design and requested implementation. Backlog TASK-33/34/35 are the execution record. Work is sequential in this worktree per project instructions.

1. TASK-33: reproduce empty-check/overwrite and evidence false positives; add normal fixtures. Refactor `scripts/build-native-candidate.mjs` behind an injectable client; build in unique directories, rebuild inputs, validate exact checked set, write exclusive receipts with actual hashes. Bind startup to MCP request/run and raw decoder, and UI to decoded images/current approved files. Run focused Node tests.
2. TASK-34: classify current Lua modules in `config/architecture.json`; use scoped ASTs to enforce core dependencies and reveal dynamic access. Test allowed edges, false text matches, shadowing, forbidden edges, parse errors and cycles. Adapt pinned Luacheck with specific baseline diagnostics; tool errors fail explicitly.
3. TASK-35: add public-API potion finalization failure injection. Execute four unique semantic mutations in temporary copies through `runLua`; require exact test assertion identity, distinguish invalid/infrastructure/timeouts/survivors. Test the dispatcher classification.
4. Integrate stable checks into package scripts and Quality; run Node filesystem tests on Ubuntu too. Validate delivery metadata for current PR head/base/tested merge and all mandatory jobs. Keep real UI/candidate gates independent.
5. Run full `npm run check`, critical mutations and `git diff --check`; review the full diff. Record current source, command results and external evidence gaps. Do not claim independent review, official import or gameplay without those events.

Optional Stryker/LuaCov/coverage trials are separate diagnostics with explicit availability/results; they do not silently become passing required jobs.
