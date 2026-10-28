import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const hash = value => createHash('sha256').update(value).digest('hex');
const bytes = readFileSync('docs/reviews/formal-entry-source-inverses-20261028.json');
assert.equal(hash(bytes), '907287ffd60963d70f518c723cab2fe4455d13da42f01ea0f0711da34d9b7f21');
export const formalEntryInverses = JSON.parse(bytes).files;

// These exact launch-step changes affect historical source-identity proofs. The live
// trace separately checks every current write and conserves all 79475 old rows.
export function preFormalEntrySource(path, source) {
  const text = source.replaceAll('\r\n', '\n'), binding = formalEntryInverses[path];
  if (!binding || hash(text) === binding.beforeSha256) return text;
  assert.equal(hash(text), binding.afterSha256, `complete reviewed formal entry source: ${path}`);
  const lines = text.split('\n');
  for (const hunk of [...binding.hunks].reverse()) {
    assert.deepEqual(lines.slice(hunk.at, hunk.at + hunk.after.length), hunk.after);
    lines.splice(hunk.at, hunk.after.length, ...hunk.before);
  }
  const before = lines.join('\n');
  assert.equal(hash(before), binding.beforeSha256, 'exact inverse must recover the complete original source');
  return before;
}
