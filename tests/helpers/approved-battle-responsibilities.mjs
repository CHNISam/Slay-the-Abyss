// Additive source-compatibility layer. Original frozen fixtures and assertions stay immutable.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const normalize=s=>s.replaceAll('\r\n','\n');
const bytes=normalize(readFileSync(new URL('../fixtures/battle-ui-approved-responsibility-layer.json',import.meta.url),'utf8'));
assert.equal(hash(bytes),'dd1584e9e5f0ee47961742423d7161b5359129f6a14451374e3d764c37b9152b','complete additive responsibility layer identity');
const layer=JSON.parse(bytes);
const oldBytes=normalize(readFileSync(new URL('../fixtures/battle-ui-refactor-projection.json',import.meta.url),'utf8'));
assert.equal(hash(oldBytes),'a774d2c33c106ccfff8c0dda1cf54781a6cd544c7e31e4271006dc188caa4e8d','original Battle frozen record remains immutable');
const approvedBytes=readFileSync(new URL('../fixtures/approved-ui-latest-to-53fa.json',import.meta.url));
assert.equal(hash(approvedBytes),'39f651e8ec7a3037947d1a76123c2d03a521dd4a05168565f80f7222590ec89a','original approved UI record remains immutable');
const root='src/lua/abyss_battle_ui.lua',binding=JSON.parse(approvedBytes).files[root];
const lines=JSON.parse(oldBytes).before.split('\n');
assert.equal(hash(lines.join('\n')),binding.beforeSha256);
for(const edit of binding.hunks){
 assert.deepEqual(lines.slice(edit.at,edit.at+edit.before.length),edit.before,'exact existing approved forward hunk');
 lines.splice(edit.at,edit.before.length,...edit.after);
}
const source=lines.join('\n');
assert.equal(hash(source),binding.afterSha256,'recover the complete already-approved monolithic source');
assert.equal(binding.afterSha256,layer.approvedSourceSha256);
export function tryApprovedBattleRefactorSource(path,value){
 if(path!==root||value===null||hash(normalize(value))!==layer.modules[root])return undefined;
 for(const [file,expected]of Object.entries(layer.modules))
  assert.equal(hash(normalize(readFileSync(file,'utf8'))),expected,'unreviewed integrated retirement source drift: complete Battle responsibility: '+file);
 return source;
}
