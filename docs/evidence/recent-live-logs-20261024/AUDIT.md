# Recent official log audit

Capture: 2026-10-24T20:51:50.8384727+08:00. 19:25 cutoff. 3 raw files, 182529 bytes, 1086 explicit prints, 4 UI load cycles. Only actual prints decoded. Candidate association of later cycles unknown.

| File / UI cycle | Records | Prints | Ready | Error prints | Observed encounter sequence |
|---|---:|---:|---:|---:|---|
| 26 / 1 | 0–7 | 8 | 1 | 0 | No combat prints |
| 27 / 1 | 0–105 | 106 | 1 | 0 | spike_slime_s_1+acid_slime_m_2 [win] → red_louse_1 [no victory print] |
| 28 / 1 | 0–552 | 553 | 1 | 0 | spike_slime_s_1+acid_slime_m_2 [win] → jaw_worm_1 [win] → green_louse_2+red_louse_1 [win] → jaw_worm_1 [win] → spike_slime_m_2+acid_slime_m_1 [win] → shield_gremlin_5+mad_gremlin_1+sneaky_gremlin_2+fat_gremlin_3+wizard_gremlin_4 [no victory print] |
| 28 / 2 | 553–971 | 419 | 1 | 0 | spike_slime_s_1+acid_slime_m_2 [win] → jaw_worm_1 [win] → green_louse_2+red_louse_1 [win] → jaw_worm_1 [win] → acid_slime_m_1+spike_slime_m_2 [win] |

- **observed repetition**: Three UI load cycles with combat (27,28 cycle 1,28 cycle 2) first show spike_slime_s_1 + acid_slime_m_2. Both 28 cycles next show jaw_worm_1. This is log evidence of repetition; seed root cause and candidate association require separate source/import evidence.

- **five explicit enemy IDs**: Sixth observed encounter contains shield_gremlin_5, mad_gremlin_1, sneaky_gremlin_2, fat_gremlin_3, wizard_gremlin_4. Verify target encounter rules separately. Records 521, 527, 531, 534, 537, 542.

- **damage/status limited evidence**: Green louse applies player status amount=2 at elapsed435; player later deals 4 to green louse at elapsed522. Status name/card id/preview value absent. Consistent with a modifier but does not identify weak independently. Records 188, 227.

- **damage/status limited evidence**: Player damage 8 to acid slime at elapsed151; player applies unnamed status amount2 to it; later damage9 at elapsed161. No status name or card id. No independent proof of vulnerable calculation or preview bug. Records 50, 52, 70.

- **block display cannot be judged**: No explicit single player block amount10 print in these logs. Two block5 events within same player turn are explicit, consistent with total10. Prints do not capture rendered glyphs/labels, so cannot decide whether a displayed 1 is clipped 10.

- **potion damage/use**: Elapsed976 player damage red_louse_1 amount12; elapsed977 death followed by potion target1. Logs prove this sequence, but omit potion id/base damage/target prior HP. Records 99, 101, 103.

- **potion status/use**: Elapsed1732 player status amount5 then potion target3; elapsed1734 status amount2 then potion target3. These are two explicit potion events, with unnamed statuses. Records 545, 547, 548, 550.

- **acquisition unknown**: No explicit potion acquisition/item-id print. merchant_buy prints are audio cues only; do not identify purchase type. Absence of acquisition prints does not prove no acquisition.

- **settlement limited evidence**: All four UI load cycles end in explicit settlement_requested defeat and ABYSS_SETTLEMENT_DEFEAT. No player death print is present. These entries do not prove combat killed the player; they may be user exit settlement.

## Raw hashes

- 2026-10-24_19-25-50_26_217122260.gia: `e8c7145662f8011f0d9506e81e27ca600bb717d60af2b46650a80e9bd8fbcd80` (1214 bytes, 8 prints)
- 2026-10-24_19-31-08_27_217122260.gia: `d3083a8c48ed2798bb032309bf642570ab80daab62b918d73ab2baa63ad18e4c` (17740 bytes, 106 prints)
- 2026-10-24_19-59-24_28_217122260.gia: `2a7e23fc04f34dd0b1911377031e51a060def626dcec80a8d574494821b60e50` (163575 bytes, 972 prints)

## Limits

- No screenshots: cannot verify clipping, card preview text, target preview text, or UI health/block totals.
- No card IDs, status names, pre-hit HP/block, or full state snapshots: damage arithmetic cannot be fully reconstructed.
- No seed/candidate hash printed: do not attribute later cycles to parent-verified candidate solely by visual/log similarity.
- No current explicit failed/error print observed; does not establish error-free execution of unlogged paths.

Raw files, full parser outputs, and machine-readable evidence: this directory. No source files changed.
