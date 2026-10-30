import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runLua} from '../scripts/test-lua.mjs';
test('original world intent selector is separate from tooltip art and damage rules',()=>{
 const r=runLua('tests/lua/original_monster_intents.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/SOURCE_MONSTER_INTENTS_PASS/);
});
test('all 42 current species and 130 runtime moves bind to exact inspected setMove metadata',()=>{
 const evidence=JSON.parse(readFileSync('docs/art/source-monster-intents.json','utf8'));
 const source=readFileSync('src/lua/abyss_monster_source_intents.lua','utf8');
 const rows=[...evidence.act1.rows.map(r=>[r.enemyId,r.runtimeMoveId,r.variants[0].sourceIntent]),
 ...evidence.act2.mappings.map(r=>[r.enemy_id,r.runtime_move_id,r.intent_enum])];
 assert.equal(new Set(rows.map(r=>r[0])).size,42);assert.equal(rows.length,130);
 for(const [enemy,move,intent]of rows){
  const line=source.split('\n').find(line=>line.startsWith(` [${JSON.stringify(enemy)}]={`));
  assert.ok(line?.includes(`[${JSON.stringify(move)}]=${JSON.stringify(intent)}`),`${enemy}/${move}`);
 }
 assert.equal(evidence.act1.pinnedCommit,evidence.act2.source_commit);
});
