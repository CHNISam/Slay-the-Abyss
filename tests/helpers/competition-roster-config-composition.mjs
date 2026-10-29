// Exact outer roster registration bridge; every older complete config proof stays immutable.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/competition-roster-config-composition.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'81622ae6facb0cb8fd3e3422342873412eb49eb9874f2deb80e108c14e24f512','complete reviewed roster config composition');
export const rosterConfigComposition=JSON.parse(bytes);
export function projectRosterConfigSource(path,source,target){
 const proof=rosterConfigComposition;
 assert.equal(path,proof.path,'roster config composition path');
 assert.equal(typeof source,'string','roster config composition source must exist');
 assert.ok(Object.hasOwn(proof.targets,target),'roster config composition target');
 source=normalize(source);
 assert.equal(hash(source),proof.combinedSha256LF,'unreviewed integrated roster config source');
 const lines=source.split('\n'),binding=proof.targets[target];
 for(const edit of [...binding.edits].reverse()){
  assert.deepEqual(lines.slice(edit.at,edit.at+edit.before.length),edit.before,'exact roster config composition hunk and position');
  lines.splice(edit.at,edit.before.length,...edit.after);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.sha256LF,'complete accepted roster config target recovered');
 return previous;
}
export function preRosterConfigSource(path,source,target='current'){
 if(path!==rosterConfigComposition.path||typeof source!=='string'||hash(normalize(source))!==rosterConfigComposition.combinedSha256LF)return source;
 return projectRosterConfigSource(path,source,target);
}
