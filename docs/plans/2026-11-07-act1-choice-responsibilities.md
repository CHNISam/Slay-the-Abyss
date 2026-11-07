# Act 1 choice responsibilities

Continuation of the owner's TASK-74.20 architecture assignment, after checking active PRs and coordinating source ownership. Base is the exact #543 superset 939e0820; do not duplicate its Session, Watcher or Inventory work, or #541 Power/Shop and launch work.

1. Freeze the complete existing Act1Events source, verify its Git blob, and add a failing CC15 dispatcher/responsibility test.
2. Move each of the six local event choices to an event-specific handler. Keep common validation, extension dispatch, transaction boundaries, capability reads, RNG calls and return arity. Separate Bonfire reward calculation from permanent removal because their order is a real domain contract.
3. Compare independent old/current Lua VMs using complete graph observations of existing event fixtures and additional invalid-input/capability-failure cases. Preserve the old test sources and assertions. Add semantic negative controls and exact source-epoch freshness/CRLF tests.
4. Measure all Lua modules and dependency edges; add the selected responsibilities to the existing hard CC15 gate. Register the new JS test without changing sharding or the test inventory.
5. Obtain independent exact-source review, retain targeted evidence and create a stacked PR or hand off the isolated commit if #543 has not merged. No repeated Full or user-computer operations.
