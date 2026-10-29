import {preRunMaxHpConfig} from './run-max-hp-config-inverse.mjs';
// Exact outer test-only bridge. Both original complete config proofs stay immutable.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/nodes-battle-max-hp-config-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'5e130a11180cb03714f315a21f5cf90a722374c2833dda033529851ad2809b92','complete reviewed combined Nodes Battle Max HP config witness');
const proof=JSON.parse(bytes);
export function projectNodesBattleMaxHpConfig(path,source,target){
 assert.equal(path,proof.path,'combined Nodes Battle Max HP path');
 assert.equal(typeof source,'string','combined Nodes Battle Max HP source must exist');
 assert.ok(Object.hasOwn(proof.targets,target),'combined Nodes Battle Max HP target');
 source=normalize(source);
 assert.equal(hash(source),proof.combinedSha256LF,'unreviewed combined Nodes Battle Max HP config source');
 const lines=source.split('\n'),binding=proof.targets[target];
 for(const edit of [...binding.edits].reverse()){
  assert.deepEqual(lines.slice(edit.at,edit.at+edit.before.length),edit.before,'exact combined Nodes Battle Max HP hunk and position');
  lines.splice(edit.at,edit.before.length,...edit.after);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.sha256LF,'complete accepted combined Nodes Battle Max HP target recovered');
 return previous;
}
export function preNodesBattleMaxHpConfig(path,source,target='candidate'){
 source=preRunMaxHpConfig(path,source);
 if(path!==proof.path||typeof source!=='string'||hash(normalize(source))!==proof.combinedSha256LF)return source;
 return projectNodesBattleMaxHpConfig(path,source,target);
}
