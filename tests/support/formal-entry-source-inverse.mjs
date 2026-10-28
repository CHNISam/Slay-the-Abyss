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
  let text = source.replaceAll('\r\n', '\n');
  const binding = formalEntryInverses[path];
 if(path==='data/presentation/ui_theme.json' && hash(text)==='f88fac509e27f23db8e7f65c50236377fd7c230356695987e51f93881f6ec128'){
  // Exact new glyph inverse; the complete accepted hash below still binds
  // every old byte and prevents unrelated deletions, edits or reordered fields.
  const molten=",\n      \"molten_egg\": {\n        \"id\": 102031,\n        \"placeholder\": true,\n        \"note\": \"暂沿用现有遗物图标；专属美术与设备验收待完成。\"\n      }";
  assert.equal(text?.split(molten).length,2,'one exact Molten Egg placeholder');
  text=text.replace(molten,'');
  const mushroom="      \"odd_mushroom\": {\n        \"id\": 102028,\n        \"placeholder\": true,\n        \"note\": \"奇怪蘑菇暂沿用批准主题现有宝箱图标；专属美术与设备验收待完成。\"\n      },\n";
  const relic='    \"relic\": {\n',at=text.indexOf(relic)+relic.length;
  assert.equal(text.split(relic).length,2,'one relic mapping container');
  assert.equal(text.slice(at,at+mushroom.length),mushroom,'exact Mushroom insertion position');
  text=text.slice(0,at)+text.slice(at+mushroom.length);
 }

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
