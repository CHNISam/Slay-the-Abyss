// Small shared primitive for explicitly reviewed test-fixture migrations only.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const hash=value=>createHash('sha256').update(value).digest('hex');
export function restoreExactFixtureHunks(proof,path,source){
 if(path!==proof.path||typeof source!=='string')return source;
 const normalized=source.replaceAll('\r\n','\n');
 if(hash(normalized)!==proof.afterSha256)return source;
 let delta=0,previousEnd=0;
 const hunks=proof.hunks.map(hunk=>{
  const before=hunk.before.split('\n'),after=hunk.after.split('\n');
  assert.ok(Number.isSafeInteger(hunk.at)&&hunk.at>=previousEnd,'ordered exact fixture hunk coordinates');
  const beforeAt=hunk.at-delta;assert.ok(beforeAt>=0);
  delta+=after.length-before.length;previousEnd=hunk.at+after.length;
  return {...hunk,before,after,beforeAt};
 });
 const lines=normalized.split('\n');
 for(const hunk of [...hunks].reverse()){
  assert.deepEqual(lines.slice(hunk.at,hunk.at+hunk.after.length),hunk.after,'exact positioned current fixture bytes');
  lines.splice(hunk.at,hunk.after.length,...hunk.before);
 }
 const previous=lines.join('\n');assert.equal(hash(previous),proof.beforeSha256,'complete original fixture identity');
 const forward=previous.split('\n');
 for(const hunk of [...hunks].reverse()){
  assert.deepEqual(forward.slice(hunk.beforeAt,hunk.beforeAt+hunk.before.length),hunk.before,'exact positioned original fixture bytes');
  forward.splice(hunk.beforeAt,hunk.before.length,...hunk.after);
 }
 assert.equal(hash(forward.join('\n')),proof.afterSha256,'complete forward fixture identity');
 return previous;
}
