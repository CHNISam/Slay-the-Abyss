import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
export const rosterSourceBindings=JSON.parse(readFileSync('tests/fixtures/competition-roster-source-inverse.json','utf8'));
const hash=value=>createHash('sha256').update(value).digest('hex');
// Exact test-only layer. Unknown identities pass to the original strict drift
// guards; no old source hash, rendering witness or timeout is replaced.
export function preRosterSource(path,source){
  source=source.replaceAll('\r\n','\n');
  const binding=rosterSourceBindings.files[path];
  if(!binding || hash(source)!==binding.afterSha256)return source;
  const lines=source.split('\n');
  for(const hunk of [...binding.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'one exact roster admission hunk');
    lines.splice(hunk.at,hunk.after.length,...hunk.before);
  }
  const before=lines.join('\n');
  assert.equal(hash(before),binding.beforeSha256,'complete pre-roster source recovered');
  return before;
}
