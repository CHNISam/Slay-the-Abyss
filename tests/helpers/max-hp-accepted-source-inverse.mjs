import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync('tests/fixtures/max-hp-accepted-source-inverse.json');
assert.equal(hash(bytes),'c8832fa6dbc78820604351896a2ea7545dcf8278d809ef16997ca44bd79d1457');
export const maxHpAcceptedInverse=JSON.parse(bytes);
// Test-only exact insertion inverse. Unknown identities flow to the existing
// historical guards unchanged, so drift cannot be hidden by field filtering.
export function preMaxHpSource(path,source){
 source=source.replaceAll('\r\n','\n');
 const binding=maxHpAcceptedInverse.files[path];
 if(!binding || hash(source)!==binding.afterSha256)return source;
 for(const edit of binding.edits){
  assert.equal(source.split(edit.after).length,2,'one exact Max HP addition');
  source=source.replace(edit.after,edit.before);
 }
 assert.equal(hash(source),binding.beforeSha256,'complete accepted pre-Max-HP source recovered');
 return source;
}
