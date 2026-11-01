import {preIntegrationSource} from './pr372-integration-source.mjs';
// Test-only exact outermost inverse for the map path a11y slice (STS MapEdge port).
// Live map tests use real sources; historical witnesses stay byte-identical.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
const hash = source => createHash('sha256').update(source).digest('hex');
export const mapPathA11yLayer = Object.freeze({
  "data/presentation/ui_theme.json": {
    "beforeSha256": "ad7a52c5b5df717a9aa59c07bc70580d437017b95ff90a22455105b382807fd7",
    "afterSha256": "dbd88c07c88f3070c20f226d133ca62073884ef2ccfd2b833f1fdb6019781192",
    "hunks": [
      {
        "before": "      \"path\": \"#5A6078\",",
        "after": "      \"path\": \"#77707A\","
      },
      {
        "before": "      \"far\": \"#C2B29A\",\n      \"visited\": \"#7E6E5C\",",
        "after": "      \"far\": \"#77707A\",\n      \"visited\": \"#C99A4E\","
      },
      {
        "before": "        \"pathWidth\": 2,\n        \"futureOpacity\": 0.28,\n        \"takenOpacity\": 0.85,\n        \"nextOpacity\": 0.7,",
        "after": "        \"pathWidth\": 3,\n        \"futureOpacity\": 0.9,\n        \"takenOpacity\": 1,\n        \"nextOpacity\": 1,"
      }
    ]
  },
  "src/lua/abyss_map_ui.lua": {
    "beforeSha256": "3e48e40660d1f590194e81ffa30d45674d0254973b21115cae812f6104331a39",
    "afterSha256": "63e105dd31995f60f1554a07ad28728d206ab5d2c5263c0f8c252765db42e938",
    "hunks": [
      {
        "before": "    local pathColours = {\n        taken = pathColour(Theme.color.node.pathTaken, visual.takenOpacity),\n        next = pathColour(Theme.color.node.path, visual.nextOpacity),",
        "after": "    -- STS MapEdge/MapRoomNode contract: taken ink, reachable bright, unreachable recessive.\n    local pathColours = {\n        taken = pathColour(Theme.color.node.pathTaken, visual.takenOpacity),\n        next = pathColour(Theme.color.node.reachable, visual.nextOpacity),"
      }
    ]
  }
});
export function preMapPathA11ySource(path, source) {
 source=preIntegrationSource(path,source,'map');
  const layer = mapPathA11yLayer[path];
  if (!layer || typeof source !== 'string') return source;
  const normalized = source.replaceAll('\r\n', '\n');
  if (hash(normalized) !== layer.afterSha256) return source;
  let previous = normalized;
  for (const {before, after} of layer.hunks) {
    assert.equal(previous.split(after).length, 2, 'one exact map a11y hunk');
    previous = previous.replace(after, before);
  }
  assert.equal(hash(previous), layer.beforeSha256, 'complete prior source recovered');
  return previous;
}
