// Exact historical-only bridge for independently reviewed current test migrations.
// Current test execution never imports this adapter. Unknown bytes remain exposed.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const blob=s=>createHash('sha1').update('blob '+Buffer.byteLength(s)+'\0').update(s).digest('hex');
const bytes=readFileSync(new URL('../fixtures/beta-current-test-source.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(hash(bytes),'328420af7cb0032006855db94814f97ea94c3dcee8e024eef1367b424d6f47da','complete reviewed current-test migration archive');
export const betaCurrentTestProof=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(betaCurrentTestProof.beforeCommit,'98fef95d047652aa6a8880241ddff28ef320a484');
assert.equal(betaCurrentTestProof.afterCommit,'ed2251d7c538b94d13ce10a809b626f1e60be5a6');
for(const path of Object.keys(betaCurrentTestProof.files)){
 assert.match(path,/^(?:tests\/lua\/(?:support\/)?[a-z0-9_]+\.lua|tests\/ui-layout\.test\.mjs)$/);
}
export function preBetaCurrentTestSource(path,source){
 const b=betaCurrentTestProof.files[path];
 if(!b||typeof source!=='string')return source;
 const text=source.replaceAll('\r\n','\n');
 if(text.length!==b.afterLength||hash(text)!==b.afterSha256)return source;
 assert.equal(blob(text),b.afterGitBlob,'complete current test Git blob: '+path);
 const lines=text.split('\n');
 for(const h of [...b.hunks].reverse()){
  assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after,'exact current test reverse hunk: '+path);
  lines.splice(h.at,h.after.length,...h.before);
 }
 const prior=lines.join('\n');
 assert.equal(hash(prior),b.beforeSha256,'complete develop98 test: '+path);
 assert.equal(blob(prior),b.beforeGitBlob,'complete develop98 Git blob: '+path);
 for(const h of [...b.hunks].reverse()){
  assert.deepEqual(lines.slice(h.beforeAt,h.beforeAt+h.before.length),h.before,'exact current test forward hunk: '+path);
  lines.splice(h.beforeAt,h.before.length,...h.after);
 }
 assert.equal(lines.join('\n'),text,'complete bidirectional current test equivalence: '+path);
 return prior;
}
