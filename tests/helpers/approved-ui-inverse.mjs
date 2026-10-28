import {preIntegratedNodeUiSource} from './approved-node-ui-refactor.mjs';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=value=>value===null?null:createHash('sha256').update(value).digest('hex');
const bytes=readFileSync(new URL('../fixtures/approved-ui-latest-to-53fa.json',import.meta.url));
assert.equal(hash(bytes),'39f651e8ec7a3037947d1a76123c2d03a521dd4a05168565f80f7222590ec89a','complete reviewed current UI source binding');
export const approvedUi=JSON.parse(bytes);
// Invert only this test registrar before the immutable approved-UI witness.
// Every original statement must recover the accepted cec source byte-for-byte.
export function preBoundedPotionFailuresSource(path,source){
 if(path!=='tests/lua/battle_ui_potion_target_failures.lua'||source===null)return source;
 source=source.replaceAll('\r\n','\n');
 const prefix="local first,last=...\nfirst,last=first or 1,last or 4\nassert(type(first)=='number'and type(last)=='number'and first%1==0 and last%1==0 and first>=1 and last<=7 and first<=last,'invalid potion failure slice')\nlocal registered,executed=0,0\n";
 if(!source.startsWith(prefix))return source;
 const footer="assert(registered==7,'all original potion failure cases must register')\nassert(executed==last-first+1,'all selected potion failure cases must execute')\nprint('POTION_TARGET_FAILURES_PART '..first..' '..last..' '..executed)\n";
 assert.ok(source.endsWith(footer),'exact bounded potion failure footer');
 const before='local test,finish = H.suite("LUA_POTION_TARGET_FAILURES")\n';
 const after=before+"local originalTest=test\ntest=function(name,fn)\n registered=registered+1\n if registered<first or registered>last then return end\n executed=executed+1\n originalTest(name,fn)\n print('POTION_TARGET_FAILURES_CASE '..registered)\nend\n";
 let original=source.slice(prefix.length,-footer.length);
 assert.equal(original.split(after).length,2,'one exact bounded potion registration inverse');
 original=original.replace(after,before);
 assert.equal(hash(original),'47565faaad06cbf34edf208a30d922ab4975b19a5025dc751c379ff6ed2d83a9',
  'complete accepted potion failure body before the frozen UI guard');
 return original;
}
// One additional test-only layer, never a replacement for PR302's frozen 26
// sources or the original 79543/79757/81392 write proofs and runner budgets.
export function preApprovedUiSource(path,source){
 source=preBoundedPotionFailuresSource(path,source);
 source=preIntegratedNodeUiSource(path,source);
 const binding=approvedUi.files[path];
 if(!binding)return source;
 source=source===null?null:source.replaceAll('\r\n','\n');
 if(hash(source)===binding.beforeSha256)return source;
 assert.equal(hash(source),binding.afterSha256,
  'unreviewed integrated presentation source drift; unreviewed integrated retirement source drift: '+path);
 const lines=source.split('\n');
 for(const hunk of [...binding.hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact approved UI source hunk and position: '+path);
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=binding.beforeSha256===null?null:lines.join('\n');
 if(previous===null)assert.equal(lines.length,0,'only a fully bound added source may disappear from a temporary historical tree');
 assert.equal(hash(previous),binding.beforeSha256,'complete PR302 source recovered: '+path);
 return previous;
}
