import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const sha=s=>createHash('sha256').update(s).digest('hex');
const proof=JSON.parse(readFileSync(new URL('../fixtures/main-potion-fixture-inverse.json',import.meta.url),'utf8'));
export function originalMainPotionFixture(source,path){
 source=source.replaceAll('\r\n','\n');
 const row=proof.files[path];if(!row)return source;
 for(const {after,before}of row.edits){
  assert.equal(source.split(after).length,2,'original source byte count: complete reviewed explicit-Use migration');
  source=source.replace(after,before);
 }
 return source;
}
export function assertMainPotionActionHelper(){
 const path='tests/lua/support/confirm_potion_popup.lua';
 assert.equal(sha(readFileSync(path,'utf8').replaceAll('\r\n','\n')),proof.actionHelperSha256,
  'explicit potion action helper must continue dispatching real native button events');
}
