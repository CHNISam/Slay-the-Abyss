import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {runLua} from '../scripts/test-lua.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';

test('source descriptors cover every pinned move without evaluating future effects or spending Artifact',()=>{
 const evidence=JSON.parse(readFileSync('docs/art/source-monster-intents.json','utf8'));
 const cases=[...evidence.act1.rows.map(row=>[row.enemyId,row.runtimeMoveId,row.variants[0].sourceIntent]),
  ...evidence.act2.mappings.map(row=>[row.enemy_id,row.runtime_move_id,row.intent_enum])];
 assert.equal(cases.length,130);assert.equal(new Set(cases.map(row=>row[0])).size,42);
 const directory=mkdtempSync('build/source-intent-descriptor-');
 try {
  const script=join(directory,'case.lua').replaceAll('\\','/');
  writeFileSync(script,`SOURCE_DESCRIPTOR_CASES=${toLua(cases)}\ndofile('tests/lua/source_intent_descriptor.lua')\n`);
  const result=runLua(script);
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/SOURCE_INTENT_DESCRIPTOR_PASS 130/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
