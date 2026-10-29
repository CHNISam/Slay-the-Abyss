// Exact outer test-only Run/MaxHP bridge. All accepted inner witnesses stay immutable.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/run-max-hp-config-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'3d20be55337d0e4999d90282f14c49a71b77c0b82cc545fd65161378dead85a2','complete reviewed Run Max HP config witness');
const proof=JSON.parse(bytes);
export function projectRunMaxHpConfig(path,source,target){
 assert.equal(path,proof.path,'combined Run Max HP path');
 assert.equal(typeof source,'string','combined Run Max HP source must exist');
 assert.ok(Object.hasOwn(proof.targets,target),'combined Run Max HP target');
 source=normalize(source);
 assert.equal(hash(source),proof.combinedSha256LF,'unreviewed combined Run Max HP config source');
 const lines=source.split('\n'),binding=proof.targets[target];
 for(const edit of [...binding.edits].reverse()){
  assert.deepEqual(lines.slice(edit.at,edit.at+edit.before.length),edit.before,'exact combined Run Max HP hunk and position');
  lines.splice(edit.at,edit.before.length,...edit.after);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.sha256LF,'complete accepted combined Run Max HP target recovered');
 return previous;
}
export function preRunMaxHpConfig(path,source,target='combined'){
 if(path!==proof.path||typeof source!=='string'||hash(normalize(source))!==proof.combinedSha256LF)return source;
 return projectRunMaxHpConfig(path,source,target);
}
