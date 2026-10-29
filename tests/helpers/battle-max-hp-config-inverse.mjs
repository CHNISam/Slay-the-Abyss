import {preAcceptedPr323Source} from './pr323-accepted-source-inverse.mjs';
// Exact additive test-only bridge; original Battle and Max HP witnesses stay immutable.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=source=>source.replaceAll('\r\n','\n');
const hash=source=>createHash('sha256').update(source).digest('hex');
const bytes=normalize(readFileSync(new URL('../fixtures/battle-max-hp-config-inverse.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'79bca8cc4391e1906049dd815dd143267894f37425253ca6ac9a836d7aa21456','complete reviewed combined Battle Max HP config witness');
const proof=JSON.parse(bytes);
export function projectBattleMaxHpConfig(path,source,target){
 if(path==='config/architecture.json')source=preAcceptedPr323Source(path,source);
 assert.equal(path,proof.path,'combined Battle Max HP path');
 assert.equal(typeof source,'string','combined Battle Max HP source must exist');
 assert.ok(Object.hasOwn(proof.targets,target),'combined Battle Max HP target');
 source=normalize(source);
 assert.equal(hash(source),proof.combinedSha256LF,'unreviewed combined Battle Max HP config source');
 const lines=source.split('\n'),binding=proof.targets[target];
 for(const edit of [...binding.edits].reverse()){
  assert.deepEqual(lines.slice(edit.at,edit.at+edit.before.length),edit.before,'exact combined Battle Max HP hunk and position');
  lines.splice(edit.at,edit.before.length,...edit.after);
 }
 const previous=lines.join('\n');
 assert.equal(hash(previous),binding.sha256LF,'complete accepted combined Battle Max HP target recovered');
 return previous;
}
export function preCompositeBattleMaxHpConfig(path,source){
 if(path==='config/architecture.json')source=preAcceptedPr323Source(path,source);
 if(path!==proof.path||typeof source!=='string'||hash(normalize(source))!==proof.combinedSha256LF)return source;
 return projectBattleMaxHpConfig(path,source,'maxHp');
}
