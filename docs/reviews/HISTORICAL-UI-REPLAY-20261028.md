# Historical native UI replay boundary

The accepted native UI changed card skin, enemy/status/intent layout, character selection, map redraw/cache behavior and overlay visibility. The current scene is not byte-equivalent to the original formal-entry scene. Its observed count is not substituted into any historical golden.

`tests/fixtures/historical-ui-source-closure-20261028.json.gz` freezes the executable dependency closure of the original e46 formal-entry replay plus its original character-selection dependencies from 2ee2f401. It reuses unchanged current files by complete SHA, existing immutable archive bodies, original formal-entry hunks, and the complete pre-content relic fixture. Only unavailable changed historical bodies are added. It contains no generated UI/build outputs and requires no Git history, download, dependency, or new runner. The helper materializes it in an isolated temporary tree and uses the existing builders and Lua runner with their original deadlines.

Historical assertions remain exact:

- room port: 79,543 writes / 1,215,629,804;
- M3 visual delta: 79,757 / 1,467,902,785;
- retired announcement plus original formal entry: 81,392 / 1,836,812,524, with every ordered row checked.

All original archives, source hashes, vectors and golden values remain unchanged. This is historical proof, **not acceptance of the current write order, rendering budget, layout, or natural gameplay**.

The current real scene runs separately. It retains the strict native-field recorder and native interaction gates, then asserts exactly one permanent forge upgrade without deck/resource drift, actual attack damage and energy consumption, preserved battle owner/RNG/HP through exit overlays, and correct foreground/sheet dismissal. Current geometry, targeting, input and render-budget contracts remain separate live tests. No production rendering or gameplay is reverted to recover old write counts.

New negatives reject altered, missing or extra historical dependencies; current-to-history projection is enabled only for explicitly bound complete current identities. Unknown current source bytes remain unknown and fail the original strict downstream source guards.
