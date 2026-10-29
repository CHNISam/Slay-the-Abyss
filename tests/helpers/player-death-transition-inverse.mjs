// Exact additive replay adapter. Live tests still use the new death sequence;
// historical tests recover the unchanged accepted source and frozen assertions.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/player-death-transition-inverse.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'864bef1d366836036fc8d7cefd6c9fb18d0c90877628f1030a310ac780148dd7','complete player-death replay layer identity');
export const playerDeathLayer=JSON.parse(bytes);
export function prePlayerDeathSource(path,source){
  const binding=playerDeathLayer.files[path];
  if(!binding||source===null)return source;
  source=source.replaceAll('\r\n','\n');
  // Older witnesses and unknown/partial sources remain for the frozen upstream guards.
  if(hash(source)!==binding.afterSha256)return source;
  const lines=source.split('\n');
  for(const hunk of [...binding.hunks].reverse()){
    assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact player-death hunk and position: '+path);
    lines.splice(hunk.at,hunk.after.length,...hunk.before);
  }
  const previous=lines.join('\n');
  assert.equal(hash(previous),binding.beforeSha256,'complete pre-death-transition source recovered: '+path);
  return previous;
}
