import {preCurrentSource} from '../helpers/task77-current-source-layers.mjs';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const hash = value => createHash('sha256').update(value).digest('hex');
const bytes = readFileSync('docs/reviews/formal-entry-source-inverses-20261028.json');
assert.equal(hash(bytes), 'cb1c42674c3a4ca3e399e63ea61a4c919513a452e80d7fc95881dfa4262c9893');
export const formalEntryInverses = JSON.parse(bytes).files;

// These exact launch-step changes affect historical source-identity proofs. The live
// trace checks the current semantic scene; the exact frozen replay conserves old rows.
export function preFormalEntrySource(path, source) {
  const text = preCurrentSource(path,source);
  let binding = formalEntryInverses[path];
  // Compose the same immutable launch hunks with the two reviewed relic glyphs.
  // Their ten inserted lines precede every launch hunk. Both complete identities
  // bind every glyph byte and position; no field filtering or wildcard inverse.
  const contentBefore='992e36ac0923209eb0ae09eac564e2685b0768a5cbbe211762e6b62b723478cf';
  const contentAfter='f88fac509e27f23db8e7f65c50236377fd7c230356695987e51f93881f6ec128';
  if(path==='data/presentation/ui_theme.json' && [contentBefore,contentAfter].includes(hash(text)))
    binding={...binding,beforeSha256:contentBefore,afterSha256:contentAfter,
      hunks:binding.hunks.map(hunk=>({...hunk,at:hunk.at+10}))};
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
