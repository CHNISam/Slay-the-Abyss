import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { toLua } from '../scripts/build-lua-data.mjs';
import { runLua } from '../scripts/test-lua.mjs';

test('independent fixed-source card state vectors regenerate exactly', () => {
  const result = spawnSync('python', ['tools/sts1-card-rng-oracle.py', '--check'], { encoding: 'utf8', timeout: 15000 });
  assert.equal(result.status, 0, result.stderr || result.error?.message || result.stdout);
  assert.match(result.stdout, /CARD_RNG_STATE_VECTORS_MATCH/);
});

test('production card state matches independent words, counters, offsets and wrapper traces', () => {
  const vectors = JSON.parse(readFileSync('tests/fixtures/sts1-card-rng-state-vectors.json', 'utf8'));
  mkdirSync('build/lua', { recursive: true });
  writeFileSync('build/lua/card_random_oracle_fixture.lua', `local V=${toLua(vectors)}
local Cards=require('abyss_card_random')
local R,P=require('abyss_sts_random'),require('abyss_randomxs128')
local calls,rarities=0,0
local function same(a,b)
 assert(type(a)==type(b),'type mismatch')
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'extra field '..tostring(k))end
end
local function trace(step)
 local p=step.primitive;if not p then return end
 local raw=P.restore(p.before.words)
 for _,expected in ipairs(p.rawOutputs)do assert(P.next64Hex(raw)==expected,'raw output')end
 same(P.snapshot(raw),p.after.words)
 local rng=R.restore(p.before)
 if p.method=='randomInt99' then assert(R.randomInt(rng,99)==p.result)
 else
  assert(p.method=='randomBooleanZero')
  local sample=R.cloneState(rng);assert(R.randomFloat(sample)==p.floatSample)
  assert(R.randomBooleanChance(rng,0)==p.result)
 end
 same(R.snapshot(rng),p.after);calls=calls+1
end
local function rarity(owner,step,context,update)
 same(Cards.snapshot(owner),step.before)
 local result=update and Cards.rewardRarity(owner,context)or Cards.rollRarity(owner,context)
 assert(result==step.rarity,'rarity mismatch')
 same(Cards.snapshot(owner),step.after);trace(step);rarities=rarities+1
end
local apply
apply=function(owner,action,saved)
 same(Cards.snapshot(owner),action.before)
 if action.op=='reward'or action.op=='shop'then
  for _,step in ipairs(action.rarities)do rarity(owner,step,action.room,action.op=='reward')end
  for _,step in ipairs(action.upgrades or {})do
   same(Cards.snapshot(owner),step.before)
   assert(Cards.upgrade(owner,step.rarity,0)==step.upgraded)
   same(Cards.snapshot(owner),step.after);trace(step)
  end
 elseif action.op=='checkpoint'then
  saved[action.id]=Cards.snapshot(owner);same(saved[action.id],action.checkpoint)
  apply(Cards.clone(owner),action.cloneProbe,{})
 elseif action.op=='restore'then owner=Cards.restore(assert(saved[action.id]))
 else error('unknown oracle action '..tostring(action.op))end
 same(Cards.snapshot(owner),action.after);return owner
end
for _,case in ipairs(V.seedCases)do
 local owner,saved=Cards.new(case.seed),{}
 same(Cards.snapshot(owner),case.initial)
 for _,action in ipairs(case.actions)do owner=apply(owner,action,saved)end
end
for _,case in ipairs(V.controlledCases)do
 local owner=Cards.restore(case.initial);local step=case.action
 rarity(owner,step,step.room,step.op=='rewardRarity')
end
assert(calls==228 and rarities==148)
print('CARD_RANDOM_ORACLE_PASS '..calls..' wrappers '..rarities..' rarities')
`);
  const result = runLua('build/lua/card_random_oracle_fixture.lua');
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /CARD_RANDOM_ORACLE_PASS 228 wrappers 148 rarities/);
});
