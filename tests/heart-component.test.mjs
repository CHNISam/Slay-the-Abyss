import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
const sha=path=>createHash('sha256').update(readFileSync(path,'utf8').replaceAll('\r\n','\n')).digest('hex');
test('Heart source-only component owns exact AI and action plans without claiming integrated damage',()=>{
 const result=runLua('tests/lua/heart_component.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/HEART_COMPONENT_PASS 8 groups; 0 failed; callback\/source-plan evidence only/);
});
test('Heart source and independent oracle retain pinned identity and complete A0 constants',()=>{
 const lock=JSON.parse(readFileSync('tests/fixtures/heart-source.json','utf8'));
 assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(lock.files['monsters/ending/CorruptHeart.java'].sha256,'dbb4fedf22a0a68ab1a8b365af7022c61d12c2a3f7d1b60b3662cd49dd64a7db');
 assert.equal(lock.files['powers/InvinciblePower.java'].sha256,'867243138178bfae4ed506bab3c4e013734efd96756b7e21ee347f3b576e9bb1');
 assert.deepEqual(lock.contracts,{hp:750,hpDraws:1,invincible:300,beat:1,multiDamage:2,multiHits:12,singleDamage:40,
  debuffs:2,invinciblePriority:99,reset:'owner atStartOfTurn before queued poison',firstMove:'debilitate',
  primaryEveryRoll:true,booleanEveryAttackPair:true,painfulStabsAmount:-1,integratedBattle:false});
 for(const [path,hash]of Object.entries(lock.authoredInputs))assert.equal(sha(path),hash,path);
 const vectors=JSON.parse(readFileSync('tests/fixtures/heart-vectors.json','utf8'));
 assert.equal(vectors.length,6);for(const v of vectors){assert.equal(v.steps.length,24);assert.equal(v.finalAi.counter,33);}
});
