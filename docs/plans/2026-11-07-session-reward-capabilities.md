# Session reward capability boundary

Goal: remove reward preparation's dependency on the mixed permanent relic command facade. This is a TASK-74.19 continuation explicitly requested by the Owner on 2026-11-07, not a new claim. The Combat SCC and Watcher complexity work have separate owners.

The three existing consumers are `abyss_potion_rewards`, `abyss_event_combat`, and `abyss_event_combat_routes`. They only read `owns` or invoke `previewCardReward`; both already have fixed capability slots (`abyss_relic_queries.hooks` and `abyss_relic_family_combat.common`) with ordinary writes forwarded from the public facade. Consume those tables directly, still reading the function at each call. No new production module, callback registry, transaction, cache, or random stream.

Alternatives rejected: injecting the complete Run API preserves the wrong dependency; moving the reward algorithms adds responsibilities without changing ownership. Extracting all permanent relic commands would be a separate large transaction change. This bounded change removes an actual direction violation and protects it with the existing AST boundary mechanism.

- [x] Pin the three complete baseline sources at develop 2c85bc61 and add a failing test requiring them outside every SCC and unable to return to the Session facade.
- [x] Exercise real potion generation and both event reward paths in separate old/current VMs; compare full state graphs, RNG, aliases, dynamic function replacement/nil restoration, return values and thrown error identity.
- [x] Rewire only these capability reads; add an eager/deferred dependency boundary.
- [x] Preserve immutable historical witnesses with an exact outer source projection, freshly checking every linked owner. No old expected values, budgets or cases change.
- [ ] Run affected event/reward regressions, source guards and architecture/static checks; record absolute SCC and CC results. Obtain independent review; coordinate the shared configuration/source projection with the Combat owner before PR/merge gates. No duplicate Full run.

Current result: Session SCC 15→12, Combat 81 unchanged. CC>30=58, CC>15=237 and maximum=75 are unchanged. 84 differential checkpoints / 25,356,882 bytes per side agree. Eight existing event regressions, three new source guards, whole-source engineering, guidance and backlog scope checks pass. The first review found the VM-only fixture in the auto-discovery directory; it is now under tests/lua/support and the reviewer verified closure. Long existing source-contract tests are still in progress. Full CI and merge have not run.
