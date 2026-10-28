import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const hash = value => createHash('sha256').update(value).digest('hex');
const bytes = readFileSync('docs/reviews/formal-entry-source-inverses-20261028.json');
assert.equal(hash(bytes), 'cb1c42674c3a4ca3e399e63ea61a4c919513a452e80d7fc95881dfa4262c9893');
export const formalEntryInverses = JSON.parse(bytes).files;

// These exact launch-step changes affect historical source-identity proofs. The live
// trace separately checks every current write and conserves all 79475 old rows.
export function preFormalEntrySource(path, source) {
  const text = source.replaceAll('\r\n', '\n'), binding = formalEntryInverses[path];
  if (!binding || hash(text) === binding.beforeSha256) return text;
  assert.equal(hash(text), binding.afterSha256, `unreviewed integrated retirement source drift: ${path}; formal entry binding`);
  const lines = text.split('\n');
  for (const hunk of [...binding.hunks].reverse()) {
    assert.deepEqual(lines.slice(hunk.at, hunk.at + hunk.after.length), hunk.after);
    lines.splice(hunk.at, hunk.after.length, ...hunk.before);
  }
  const before = lines.join('\n');
  assert.equal(hash(before), binding.beforeSha256, 'exact inverse must recover the complete original source');
  return before;
}
