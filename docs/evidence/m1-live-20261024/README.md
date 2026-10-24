# 2026-10-24 live diagnostic evidence

This package records run `ced168e4-7e7a-4699-97b4-4873610e0c41`, official save1841 and diagnostic candidate01dd3927. `report.json` separates execution, log expectations and visual review. It does not update task acceptance.

The historical independent review marked transient flying-card/HP overlap as FAIL. The user subsequently accepted this ordinary animation behavior and the existing block-badge evidence, instructed that it must not delay M1, and stopped the second round. Original reviewer bytes remain unchanged; see user-acceptance-decision.json. No new native-fix test is claimed.

`manifest.json` records absolute original paths, original SHA256 and package paths/hashes. Official readback and full MCP status are losslessly gzip-compressed originals. `session-log.gia` is the current raw log; `log-decoded.json` is derived from the identified MCP response. `selected-screens.json` maps unchanged original frames to reviewer observations. `raw-run-inventory.json` hashes the complete local run directory; the high-frequency raw frames remain local.

Review files preserve their authors' exact stated scope, including missing frames or pending decisions. Fixture injection and synthetic callbacks do not certify natural acquisition, physical phone input or full-game acceptance. Runner completion and printed expectations do not prove every visual requirement passed.

Original CRLF text artifacts are stored as lossless `.gz` wrappers so unchanged original bytes and hashes coexist with the normal Git whitespace check. Rebuilding uses `build-package.py` followed by `repair-byte-storage.py`; no CI rule or original hash is weakened.
