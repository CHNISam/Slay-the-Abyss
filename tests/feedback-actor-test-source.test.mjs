import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {preFeedbackActorTestSource as project,feedbackActorTestSource as proof} from './helpers/feedback-actor-test-source.mjs';
const hash=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('feedback actor fixture recovers only the complete fixed historical identity and never hides unknown edits',()=>{
 const source=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n'),before=project(proof.path,source);
 assert.equal(hash(source),proof.afterSha256);assert.equal(hash(before),proof.beforeSha256);
 assert.equal(project(proof.path,source.replaceAll('\n','\r\n')),before);
 assert.equal(project(proof.path,before),before);assert.equal(project('unrelated',source),source);
 for(const h of proof.hunks){
  for(const replacement of [[],h.before,[...h.after,...h.after],['-- unreviewed fixture']]){
   const lines=source.split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');
   if(bad!==source)assert.equal(project(proof.path,bad),bad);
  }
 }
 for(const bad of [source+'\n',source.slice(1),source+source])assert.equal(project(proof.path,bad),bad);
});
