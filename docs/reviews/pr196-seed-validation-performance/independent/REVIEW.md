# Pure signed64 validation: independent review

## Verdict

No blocking, important, or minor production-code finding in this frozen slice. The candidate is suitable for root integration, with the regression test included. This is not approval of unrelated PR196 changes, a merge/CI result, or a Fengari/platform timing result.

Target baseline: PR196 head `9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf` as recorded by the supplied frozen manifest. All four original Git blobs and all four candidate Git blobs/SHA256 hashes match that manifest. The snapshot itself is not a Git checkout, so no remote provenance/PR state is independently claimed.

## Scope and source proof

- The only production changes are `abyss_randomxs128.lua`, `abyss_sts_random.lua`, `abyss_run_seed.lua`, and `abyss_map_topology.lua`. The only additional file is `tests/lua/run_seed_validation.lua`; no deletion exists.
- A mechanical source comparison proves that the original constructor's four signed64 assertions were extracted verbatim. The complete constructor tail, including decimal limb accumulation, negative two's complement, zero-to-signed-min mapping, both mix calls, and every later RNG method is byte-identical.
- The wrapper adds only `validateSeed`. It checks extra argument count before calling the primitive, just as its original constructor does. Primitive validation, like the original primitive constructor, deliberately ignores extra arguments. Normalize/increment/forFloor keep their original permissive Lua arity.
- The only changes in run-seed and topology are replacing the discarded `Random.fromSeed(seed)` validation call with `Random.validateSeed(seed)` and updating its comment. Decimal +1, signed64 wrap, forFloor looping, and the real topology RNG constructor remain unchanged.
- No cache, seed narrowing, RNG stub, loop bypass, global write, or new hash computation was added to production. A validation failure still throws; no error is swallowed. Error message bodies and rejection precedence are retained. Source line numbers/stack frames naturally change with extraction and are not claimed identical.

## Fresh independent evidence

All execution used the supplied native Lua 5.4 runner, without installing software, running full npm, or using a user machine/platform.

1. Independent Python integer/regex oracle: 588 distinct string inputs, including all 256 byte values in both prefix/suffix positions, UTF-8 digits/signs, NUL/newlines, overlength strings, canonical zero, signed64 boundaries, and full-width random seeds. Exactly 73 inputs are canonical. Both original constructors and candidate constructors/validators agree with that oracle.
2. Independent base/candidate differential: 6042 records are byte-identical. Includes typed nil/Boolean/number/function/thread/userdata/metatable inputs; NaN/infinity/unsafe integers/negative numeric zero; extra nil and multiple extra arguments; exact error-message bodies; 56 seed identities; all floors 0–17; Python-derived wrap/legacy expectations; initial states; 12 primitive raw draws per seed; 27 mixed wrapper operations per seed with every returned value/state/counter; replay atCounter; counter wrap and rejected-bound aftermath; and four full topology node/edge/state outputs.
3. Run initialization integration: 4 boundary seeds, 20 persistent run streams, 96 room streams across floors 0/1/16/17, and 348 subsequent raw draws. Base/candidate records are byte-identical. This checks real Run.new and roomStreams without constructing or replaying the other worker's boss reward traces.
4. Non-stub purity probe: 56 seeds exercise primitive/wrapper validation, normalization, legacy conversion, increment, forFloor, and topology seed derivation. A debug hook monitors 23 construction/mix/state/draw/global-RNG functions and observes zero calls. Already-loaded global/module table fields, held RNG state, external entropy state/revision, and math.random state remain unchanged. Cold require/package-loader side effects are not included in that hot-module table check; those pre-existing require paths are unchanged.
5. Existing source-vector suites: 25/25 pass. Verified test bodies and fixture bytes against originals; the only harness changes are native-runner imports and promoted production module paths. These include 128 raw transitions per fixture seed, rejection sampling, scaled floats, state restoration, and counter semantics.
6. Latest persistent regression file: 7/7 pass, including its 10 fixed independent source-vector initial states/first draws/counters. Gremlin tests: 18 + 5 + 5 + 1 = 29 pass.
7. Selection path check, without replacement of production functions by this reviewer: 1680 real Run.startCombat entries, 3360 real forFloor entries, and 5 retained wrapper constructions. The unchanged existing selection test still uses its explicit combat/draw seam; this is not 1680 complete combat worlds.
8. Instruction-hook rerun at interval 1000: baseline 286283 hook events, candidate 9345, a 96.7357474946% reduction. This reproduces the instruction proxy, not a Fengari 30-second budget or platform wall time.
9. Independent mutation sensitivity: negative-zero acceptance, wrapper-extra-argument, and long-wrap mutants fail the independent harness. A bounded independent zero/signed-min equivalence sentinel passes candidate and rejects the zero-state mutant. An initial full zero-state mutant run was manually interrupted (exit 130) after reaching a nonterminating topology reroll with the deliberately absorbing RNG; it is not counted as a passing run or as the sentinel result.

## Frozen artifact hashes

- Production patch SHA256: `52665c918f92eca95be1f5aa925c02c8207b075eff2ad06f09849b6042e46226`
- Regression patch SHA256: `783758906551f728c3b4bc9f14003839c0c4b3f47c17a7599a7996b734da3741`
- Regression Lua file SHA256: `67598a55f0c0b8dbc1d7fe3adb8909e3705bb1907a6f9197cad6f4e01d6d0ccc`
- Candidate primitive SHA256: `8e886c3737c875e56a40b5886e4f20b76068101cfcf1b6a18bafa6b144f14d39`
- Candidate wrapper SHA256: `33af2fadd844eb303c3de5bcb9831f7d99e592d3cf7369ca97cee687eba99bab`
- Candidate run-seed SHA256: `5824976965571af562afebd83dd55bc54516c1436cf61cccd27d4934e05b609c`
- Candidate topology SHA256: `628b351e5c21b2ea79b5d5b12273e63e97042780c84e168f8a925fbc43012b1a`

## Declined to judge

- Current remote PR196 ownership, branch state, or merge readiness: root owns remote integration; no remote writes performed.
- Full project regression, CI, Fengari deadline, generated artifact, and game/platform smoke: outside this bounded native review; no such pass claimed.
- 128-seed boss reward trace: explicitly assigned to another independent worker and not duplicated.
- Unrelated pre-existing RNG/decimal algorithm behavior: unchanged and checked for regression, not redesigned.

## Reproduction and evidence

Scripts and logs are co-located with this report. `manifest.json` records the input corpus and source hashes; `static-check.json` records exact source extraction and suite adaptations; `results.json` records equality and instruction counts; `mutations.json` records actual mutation failures. `independent.lua`, `purity.lua`, `run-streams.lua`, `path-counts.lua`, and `zero-sentinel.lua` run through the supplied `/workspace/scratch/331215e8236a/signed-cap-review/run-lua.py` from the relevant baseline/candidate directory.

The mandatory Backlog overview command was attempted and unavailable (`backlog: command not found`). No Backlog, source checkout, or remote data was changed. Repository AGENTS and review/verification guidance were read; writes are confined to this separate review directory.
