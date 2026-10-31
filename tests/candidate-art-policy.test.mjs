import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync,existsSync,rmSync,mkdirSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {assertCandidateArtPolicy,assertCandidateArtReceipt} from '../scripts/candidate-art-policy.mjs';
import {artFeatureReceipt} from '../scripts/art-features.mjs';
import {sourceInputs,payloadDigest} from '../scripts/build-native-candidate.mjs';

for(const entry of ['build-native-candidate.mjs','build-native-audio-game.mjs'])
 for(const [name,args] of [
  ['explicit flag',['--art-cards=true']],
  ['legacy count',['--native-card-art-registry=missing.json','--native-card-art-count=1']],
  ['legacy host',['--native-card-art-registry=missing.json','--native-card-art-host=battlePanel/card1']],
  ['release flag',['--release-candidate','--art-cards=true']],
 ])test(`${entry} rejects deferred card art via ${name} before SDK or save writes`,t=>{
  const dir=mkdtempSync(join(tmpdir(),'candidate-policy-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
  const output=join(dir,'output');
  const result=spawnSync(process.execPath,[`scripts/${entry}`,'missing.gil',output,'--work-key=alpha-test',...args],{
   encoding:'utf8',timeout:10000,env:{...process.env,MILIASTRA_MCP_ROOT:join(dir,'absent-sdk')},windowsHide:true,
  });
  assert.equal(result.error,undefined);
  assert.equal(result.status,1);
  assert.match(result.stderr,/CANDIDATE_ART_DISABLED: cards/);
  assert.equal(existsSync(output),false,'policy must reject before creating candidate output');
 });

test('policy allows disabled cards without disabling independent portrait features',()=>{
 assert.doesNotThrow(()=>assertCandidateArtPolicy({cards:false,selectionAvatar:true,battlePortrait:true}));
 assert.doesNotThrow(()=>assertCandidateArtReceipt({artFeatures:artFeatureReceipt({cards:false})}));
 assert.throws(()=>assertCandidateArtReceipt({artFeatures:artFeatureReceipt({cards:true})}),/CANDIDATE_ART_DISABLED: cards/);
 for(const extra of [{readyCardArt:{enabled:true}},{nativeCardArt:{registry:'stale'}}])
  assert.throws(()=>assertCandidateArtReceipt({artFeatures:artFeatureReceipt({cards:false}),...extra}),/payload conflicts/);
});

for(const entry of ['build-native-candidate.mjs','build-native-audio-game.mjs'])
 test(`${entry} permits default-off and explicit-off configurations past the policy`,t=>{
  const dir=mkdtempSync(join(tmpdir(),'candidate-policy-off-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
  for(const args of [[],['--art-cards=false','--no-ready-card-art']]){
   const result=spawnSync(process.execPath,[`scripts/${entry}`,'missing.gil',join(dir,'output'),...args],{
    encoding:'utf8',timeout:10000,env:{...process.env,MILIASTRA_MCP_ROOT:join(dir,'absent-sdk')},windowsHide:true,
   });
   assert.equal(result.status,1);assert.match(result.stderr,/Cannot find module/);
   assert.doesNotMatch(result.stderr,/CANDIDATE_ART_DISABLED/);
  }
 });

test('standalone BGM cannot repackage forbidden or untracked input before SDK startup',t=>{
 const dir=mkdtempSync(join(tmpdir(),'candidate-policy-bgm-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const base=join(dir,'base.gil'),receipt=join(dir,'candidate.json'),output=join(dir,'output');writeFileSync(base,'base');
 writeFileSync(receipt,JSON.stringify({artFeatures:artFeatureReceipt({cards:true})}));
 for(const [args,expected]of [[[receipt],/CANDIDATE_ART_DISABLED: cards/],[[],/requires a full source receipt/]]){
  const result=spawnSync(process.execPath,['scripts/build-native-bgm-candidate.mjs',base,output,...args],{encoding:'utf8',timeout:10000,windowsHide:true});
  assert.equal(result.status,1);assert.match(result.stderr,expected);assert.equal(existsSync(output),false);
 }
});

test('missing or malformed policy fails closed and policy changes alter candidate input digest',t=>{
 const root=mkdtempSync(join(tmpdir(),'candidate-policy-input-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
 assert.throws(()=>assertCandidateArtPolicy({},{root}),/ENOENT/);
 mkdirSync(join(root,'data/release'),{recursive:true});
 const path=join(root,'data/release/candidate-art-policy.json');
 for(const value of [{schemaVersion:2,disabledFeatures:{}},{schemaVersion:1,disabledFeatures:{typo:'deferred'}},{schemaVersion:1,disabledFeatures:{cards:''}}]){
  writeFileSync(path,JSON.stringify(value));assert.throws(()=>assertCandidateArtPolicy({},{root}),/Invalid candidate artwork policy/);
 }
 writeFileSync(path,JSON.stringify({schemaVersion:1,disabledFeatures:{cards:'deferred'}}));
 const inputs=sourceInputs(root),before=payloadDigest(inputs);
 assert.ok(inputs.some(row=>row.path==='data/release/candidate-art-policy.json'));
 writeFileSync(path,JSON.stringify({schemaVersion:1,disabledFeatures:{}}));
 assert.notEqual(payloadDigest(sourceInputs(root)),before,'changing product policy must invalidate candidate provenance');
});
