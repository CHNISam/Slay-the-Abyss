# Whole GameUI Host comparison

`old-host.lua` is the complete pre-extraction entry at
`78e4e746a7f05754f0d838999c466cd88630368c`, with LF SHA256
`165e2ad1180cab9daf5321b46d1f87fe9c34ed6ebbcd3c3a8b495d23974e0933`.
It is not a reconstructed or projected oracle. The driver checks that identity,
copies all real runtime/generated dependencies into separate temporary roots,
removes the five extracted modules only from the old root, and compares every
common dependency byte-for-byte. Each side runs in a fresh process and Fengari VM.

Each window executes the original command prefix through its last boundary,
including the assertions before the next command. An explicit coroutine driver
then finishes the window; the final window executes all 35 commands. The manifest
proves the observation windows cover 1–35 exactly once per seed. Separate files
partition input/construction, map, modals, results, lifecycle, seed/failure,
overlay and chapter/reward scenarios. Short scenarios have their own exact
coverage manifests. This bounds each VM at the existing 30 seconds; no command,
assertion or covered boundary is removed when partitioning.

At each covered boundary the observer freshly visits the whole Host, source
data/presentation and every allocated native fixture control, including retired
instances. It records typed fields/keys, metatables, cycles, aliases and stable
table/function identities. It emits complete replacement definitions for nodes
whose contents changed. Earlier definitions remain part of the trace. There is
no immutable-data exemption: a child mutation and restoration under an unchanged
parent produce separate definitions. Functions are observed by identity and
actual calls, not by bytecode or closure upvalues. Native engine internals beyond
the fixture's backing fields, alive and hierarchy state are outside this model.

The native adapter moves own properties into backing storage so *every* repeated
property write is observed. It retains read-only/alive guards and saved-method
replacement semantics. The ordered event ledger records setters, property writes
and listener registrations, including argument counts and complete non-handle
argument graphs. Native controls at any argument depth are typed opaque handles
using the same identity as checkpoint definitions. `GetChild`/`GetChildren` calls
and native method return values are deliberately outside the event ledger;
invalid-object behavior remains enforced by the original fixture. Public Host
results preserve packed return arity, nil holes and table error identity. Only
leading Lua source coordinates are removed from string errors.

Full trace output is explicit opt-in. The Node bridge losslessly gzips the stream
for transport under the unchanged 32 MiB stdout cap. Decoding has a fixed 128 MiB
limit. The parent compares every decoded byte and checks exact state/event/end
counts; it does not compare digests or summaries. Uncompressed old/new logs are
written beneath `build/ui-host-impl`. The raw Lua fixture defaults to bounded
stdout and does not claim authoritative graph comparison without the bridge.

Terminal combat and chapter staging reuse the controlled-boundary technique of
the existing reward/chapter regressions. Real map, battle, reward, node and Host
commands execute afterward; these cases do not claim a naturally played complete
run or validate balance. Existing six-seed current-Host/direct-Run playback and
native lifecycle contracts remain separate regressions. No GUI, official import,
ready, device, capacity or release claim follows from these offline traces.
