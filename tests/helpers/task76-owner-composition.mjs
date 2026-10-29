// Additive exact inverse for PR315 on the existing sixteen Battle responsibilities.
// All current modules are validated before projection; frozen311/313 records stay unchanged.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const normalize=s=>s.replaceAll('\r\n','\n');
const hash=s=>createHash('sha256').update(normalize(s)).digest('hex');
const bytes=readFileSync(new URL('../fixtures/task76-owner-composition.json',import.meta.url),'utf8');
assert.equal(hash(bytes),'4ff211f47bab2f27d24d73366036f77b258a60c1165bd12edfba4f9ea958456b','complete additive TASK-76 owner composition record');
const layer=JSON.parse(bytes),root='src/lua/abyss_battle_ui.lua';
export const task76OwnerPaths=Object.freeze(Object.keys(layer.modules));
assert.equal(task76OwnerPaths.length,16,'all original Battle responsibilities remain covered');
function currentSource(file,overrides){
 if(Object.hasOwn(overrides,file))return overrides[file];
 try{return readFileSync(file,'utf8');}catch{assert.fail('unreviewed integrated retirement source drift: missing Battle responsibility: '+file);}
}
function validate(source,overrides){
 for(const file of Object.keys(overrides))assert.ok(Object.hasOwn(layer.modules,file),'unknown TASK-76 owner override: '+file);
 for(const [file,binding]of Object.entries(layer.modules)){
  const value=file===root?source:currentSource(file,overrides);
  assert.equal(typeof value,'string','missing TASK-76 Battle responsibility: '+file);
  assert.equal(hash(value),binding.afterSha256,'unreviewed integrated retirement source drift: complete TASK-76 Battle responsibility: '+file);
 }
}
export function preTask76OwnerSource(path,source,overrides={}){
 if(source===null)return source;
 source=normalize(source);
 const binding=layer.modules[path];
 if(!binding||binding.afterSha256===binding.beforeSha256||hash(source)!==binding.afterSha256)return source;
 const currentRoot=path===root?source:currentSource(root,overrides);
 validate(currentRoot,{...overrides,[path]:source});
 for(const edit of [...binding.edits].reverse()){
  assert.equal(source.split(edit.after).length,edit.count+1,'exact TASK-76 owner inverse hunk: '+path);
  source=source.replaceAll(edit.after,edit.before);
 }
 assert.equal(hash(source),binding.beforeSha256,'complete pre-TASK-76 Battle responsibility recovered: '+path);
 return source;
}
