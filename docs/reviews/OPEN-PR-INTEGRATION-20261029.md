# Open PR integration · 2026-10-29

This single-parent tree combines reviewed PR342 (`ac443e69`), PR343 (`ddc7e37`), PR344 (`85052c6e`), plus the separately reviewed same-frame controller-click fix `da323b94`, on develop `899f02d4`. Original PR334/336/338 and replacement branches retain their source history; this integration does not rewrite them.

Runtime changes retain hero image slots, direct Neow entry, owned relic bar/modal and Chinese descriptions, Duplicator, and Match event behavior. The only review repair to these runtime slices is the relic pointer listener's existing Controller.pointerBlocked guard; real controller Confirm followed by same-frame Click executes once, and the next-frame genuine pointer click remains usable.

The three original source witnesses remain immutable. A new complete-source composition archive binds final input bytes to each reviewed branch's full sources. Each leaf inverse applies it only for paths in its own original inventory. PR323 applies new projections only to its registered paths; NodeUI and P0 own their separately registered inputs. No Run pathname bypass remains. Tests reject missing, partial, appended, duplicated, reordered, cross-path and unknown source bytes. Original historical assertions and time budgets remain unchanged.

Final local evidence before push:
- 34 source guard/composition/architecture identity/controller-click tests passed, zero skip.
- 28 affected runtime/layout/oracle tests passed, zero skip, including real game entry/controllers, Match sampling/commands/native UI/timer host, both production event integrations, relic pagination/modal and Chinese descriptions.
- check:engineering passed: 262 modules, 4039 measurements, architecture 1462 edges; Luacheck zero new diagnostics and 33 historical warnings; all four semantic mutants killed; native UI contract 4/4.
- No official client import, platform UI acceptance, natural two-act playthrough or physical phone evidence is added by this PR. These remain in the existing Backlog tasks.

Current-SHA GitHub Quality remains the final merge gate. Historical strict text/native trace passed on the event slice before combination; final combined full CI must rerun them.
