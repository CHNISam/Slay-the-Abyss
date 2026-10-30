import test from 'node:test';import assert from 'node:assert/strict';import{readFileSync}from'node:fs';import{createHash}from'node:crypto';
import{phaseFourRunnerProof as runner,prePhaseFourRunnerSource}from'./helpers/phase-four-runner-source.mjs';
import{deathAudioSourceProof as audio,preDeathAudioSource}from'./helpers/death-audio-source.mjs';
import{preDeliveryTargetSource}from'./helpers/delivery-source-composition.mjs';
const read=p=>readFileSync(p,'utf8'),hash=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
for(const [name,entries,project,owners]of [
 ['runner',[[runner.path,runner]],prePhaseFourRunnerSource,Object.keys(runner.linkedSources)],
 ['audio',Object.entries(audio.files),preDeathAudioSource,Object.keys(audio.files)]
]){
 test(name+' exact source layer preserves every old byte and rejects caller-owned drift after warm projection',()=>{
  for(const[p,b]of entries){
   const raw=read(p),prior=project(p,raw);assert.equal(hash(raw),b.afterSha256);assert.equal(hash(prior),b.beforeSha256);
   assert.equal(project(p,prior),prior);assert.equal(project(p,raw.replaceAll('\n','\r\n')),prior);assert.equal(project('foreign',raw),raw);
   for(const bad of [raw+'\n',raw.slice(1),raw+raw])assert.equal(project(p,bad),bad);
   for(const h of b.hunks)for(const replacement of [[],h.before,[...h.after,...h.after],['-- unknown']]){
    const lines=raw.replaceAll('\r\n','\n').split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');if(bad!==raw)assert.equal(project(p,bad),bad);
   }
   preDeliveryTargetSource(p,raw,'legacyMulti');
   for(const q of owners)for(const bad of [undefined,read(q)+'\n-- drift']){
    const readSource=r=>r===q?bad:read(r);
    assert.throws(()=>project(p,raw,{readSource}),/linked source/);
    assert.throws(()=>preDeliveryTargetSource(p,raw,'legacyMulti',{readSource}),/linked source/);
   }
  }
 });
}
