// Exact test-only inverse of one conservative admission correction on 768f364.
// Not a timing claim: new-head raw evidence is required before applying it.
// No cache may cover caller-owned linked-source reads.
import {createHash} from 'node:crypto';
export const textSafetyCorrection = Object.freeze({
  "parentHead": "768f364a7e2dc92b6ae40c0c9299b1ec10a8cd15",
  "file": "tests/lua/presentation_responsibilities_text.lua",
  "previousMs": 1829,
  "safetyMs": 30000,
  "parentSha256": "d6ca99460b69139cf639e03cf225a8d2f0b8d85af292a033e98de5af1d092440",
  "parentGitBlob": "d8f6d17c456e14352f413113c23b563d5964cb1b",
  "beforeDescription": "Unchanged raw Fengari step scheduling weights for 974 Lua fixtures. JS measurements are now recorded separately in jsSource. Lua weights, exclusive-worker classification and all deadlines remain unchanged.",
  "afterDescription": "Original raw Fengari step scheduling measurements for 974 Lua fixtures. JS measurements are now recorded separately in jsSource. The text replay admission estimate is conservatively 30000 ms, not a successful duration measurement; placement weights, other safety classifications and all deadlines remain unchanged."
});
export function preTextSafetySource(path, source) {
  if (path !== 'scripts/ci-test-timings.json' || typeof source !== 'string') return source;
  try {
    const raw = source.replaceAll('\r\n', '\n'), data = JSON.parse(raw), w = textSafetyCorrection;
    if (raw !== JSON.stringify(data, null, 2) + '\n'
        || data.lua?.[w.file] !== w.safetyMs || data.source?.description !== w.afterDescription) return source;
    data.lua[w.file] = w.previousMs;
    data.source.description = w.beforeDescription;
    const prior = JSON.stringify(data, null, 2) + '\n';
    if (createHash('sha256').update(prior).digest('hex') !== w.parentSha256
        || createHash('sha1').update('blob ' + Buffer.byteLength(prior) + '\0').update(prior).digest('hex') !== w.parentGitBlob) return source;
    return prior;
  } catch { return source; }
}
