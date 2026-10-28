import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=value=>value===null?null:createHash('sha256').update(value).digest('hex');
const bytes=readFileSync(new URL('../fixtures/approved-ui-latest-to-53fa.json',import.meta.url));
assert.equal(hash(bytes),'3869eb21dfcf67e323291ea6e31d0700fad044f2e316a2f948c2ef867d6b3be8','complete reviewed current UI source binding');
export const approvedUi=JSON.parse(bytes);
// One additional test-only layer, never a replacement for PR302's frozen 26
// sources or the original 79543/79757/81392 write proofs and runner budgets.
export function preApprovedUiSource(path,source){
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
