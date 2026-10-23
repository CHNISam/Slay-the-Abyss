# Dazed temporary status cards

Goal: support the source-verified Dazed lifecycle needed by A0 Sentries without
adding a replacement Sentry AI or changing the approved PR19 visual design.

Architecture: retain STATUS / COMMON / cost -2 / ethereal and empty use payload.
Reject play before energy mutation. A bounded data-driven
`makeTempCardInDiscard(card,value)` creates fresh combat instances in discard;
existing ethereal disposal exhausts them when held at player turn end. Run deck,
reward and shop ownership remain separate. Artifact integration is a later commit
owned by enemy_parity; this slice has no dependency on its new Actor API.

Tech stack: JSON source/schema, Lua core and read-only native UI, Python renderer,
Node/Fengari and Python targeted tests. No game/MCP/live writes.

1. Pin Dazed, MakeTempCardInDiscardAction, ShowCardAndAddToDiscardEffect,
   CardGroup and AbstractCard evidence; record source/ABI limits.
2. Write real Combat/Run entry tests and schema/presentation tests. Run them on
   the unchanged implementation and retain the failing result.
3. Add the minimum data, op, play guard, explicit pool filters and blank cost
   presentation. Prevalidate generation to prevent partial piles/UID changes.
4. Run focused regressions, source/schema/presentation checks, record evidence
   and commit. Leave TASK-16/16.1 strict/platform AC unchecked.

The count 0..5 boundary is this candidate ABI, not a claim that the original
creates no cards for larger counts. A0 Sentry's count two is verified. Exhaust
trigger ordering, Medical Kit and arbitrary status cards are outside this slice.
