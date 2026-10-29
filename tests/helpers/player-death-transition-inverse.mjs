// Exact additive replay adapter. Live tests still use the new death sequence;
// historical tests recover the unchanged accepted source and frozen assertions.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=readFileSync(new URL('../fixtures/player-death-transition-inverse.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'b8bb1dd98349c1306557d917c81005c408789d757214cc8e16bead226b2e28da','complete player-death replay layer identity');
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
