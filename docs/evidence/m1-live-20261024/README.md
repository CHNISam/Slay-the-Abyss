# 2026-10-24 live diagnostic evidence

This package records run `ced168e4-7e7a-4699-97b4-4873610e0c41`, official save1841 and diagnostic candidate01dd3927. `report.json` separates execution, log expectations and visual review. It does not update task acceptance.

The old candidate fails the HP-occlusion requirement: flying-card animation covers the HP area. A later fix must be verified in a new candidate/run. This package must not be used as proof of that fix.

`manifest.json` records absolute original paths, original SHA256 and package paths/hashes. Official readback and full MCP status are losslessly gzip-compressed originals. `session-log.gia` is the current raw log; `log-decoded.json` is derived from the identified MCP response. `selected-screens.json` maps unchanged original frames to reviewer observations. `raw-run-inventory.json` hashes the complete local run directory; the high-frequency raw frames remain local.

Review files preserve their authors' exact stated scope, including missing frames or pending decisions. Fixture injection and synthetic callbacks do not certify natural acquisition, physical phone input or full-game acceptance. Runner completion and printed expectations do not prove every visual requirement passed.
