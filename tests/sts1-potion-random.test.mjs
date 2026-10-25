import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const catalog=JSON.parse(readFileSync('data/catalogs/sts1-ironclad-potions.json','utf8'));
const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-ironclad-potion-pool-vectors.json','utf8'));
const current=JSON.parse(readFileSync('data/potions.json','utf8')).potions;
const prelude=`local P=require('abyss_potion_random');local R=require('abyss_sts_random')
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path)
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' extra '..tostring(k))end
end
local function state(n,counter)
 return P.restore({version=1,potionRng={words={'0000000000000000',string.format('%016x',n)},counter=counter or 7}})
end
`;
function lua(body) {
 const dir=mkdtempSync(join(tmpdir(),'sts1-potion-random-'));
 try {
  const path=join(dir,'case.lua');writeFileSync(path,prelude+body);
  const result=runLua(path);assert.equal(result.status,0,result.stderr||result.stdout);
 } finally {rmSync(dir,{recursive:true,force:true});}
}

test('production sampler preserves all33 exact source indices and canonical proposed IDs including pending effects',()=>{
 const expected=catalog.pool.map(p=>({sourceId:p.sourceId,id:p.proposedProjectId,sourceIndex:p.index,rarity:p.rarity}));
 assert.equal(new Set(expected.map(p=>p.id)).size,33);
 assert.deepEqual(expected.map(({sourceId,rarity})=>({sourceId,rarity})),vectors.pool);
 for(const p of catalog.pool) {
  if(p.currentProjectId!==null)assert.equal(p.currentProjectId,p.proposedProjectId);
  const definition=current.find(x=>x.id===p.proposedProjectId);
  if(definition)assert.equal(definition.rarity,p.rarity,p.sourceId);
 }
 lua(`local expected=${toLua(expected)};same(P.pool(),expected)
 for index=0,32 do
  local owner=state(index);local result=P.totallyRandom(owner)
  assert(result.sourceIndex==index and result.sourceId==expected[index+1].sourceId and result.id==expected[index+1].id)
  same(result.attempts,{index});assert(result.rarity==expected[index+1].rarity)
  assert(result.effects==nil and result.acquisitionPending==nil)
  same(P.snapshot(owner).potionRng,{words={string.format('%016x',index),string.format('%016x',index)},counter=8})
 end
 local detached=P.pool();detached[1].id='changed';same(P.pool(),expected)
 print('POTION_RANDOM_CANONICAL_POOL_PASS33')`);
});

test('actual sampler and persistent owner match every draw and snapshot in nine independent source vectors',()=>{
 lua(`local raw=R.randomIntBetween;local trace,action,inDrop
 R.randomIntBetween=function(rng,lo,hi,...)
  local value=raw(rng,lo,hi,...)
  local purpose=inDrop and 'drop' or hi==99 and 'rarity' or action=='totally_random' and 'uniform_candidate' or 'candidate'
  trace[#trace+1]={purpose=purpose,minimum=lo,maximum=hi,value=value,after=R.snapshot(rng)}
  return value
 end
 local function selected(result)return {sourceId=result.sourceId,rarity=result.rarity,attempts=result.attempts}end
 for _,v in ipairs(${toLua(vectors.cases)})do
  local owner=P.new(v.seed);trace={}
  for _,record in ipairs(v.records)do
   action=record.action;local options={}
   if action=='explicit_rare_limited'then options={rarity='rare',limited=true}
   elseif action=='explicit_rare'then options={rarity='rare'}
   elseif action:find('entropic_combat',1,true)then options={limited=true}end
   if action:find('drop',1,true)then
    -- Replay only the external drop draw/context from the fixed vector. Drop
    -- modifiers and acquisition policies are deliberately outside this module.
    inDrop=true;local roll=R.randomIntBetween(owner.potionRng,0,99);inDrop=false
    assert((roll<record.result.chance)==record.result.dropped)
    if record.result.dropped then same(selected(P.sample(owner)),record.result.potion,action)end
   elseif action=='totally_random'then same(selected(P.totallyRandom(owner)),record.result,action)
   else same(selected(P.sample(owner,options)),record.result,action)end
   same(P.snapshot(owner).potionRng,record.after,action..' '..v.seed)
  end
  same(trace,v.trace,'every draw '..v.seed);same(P.snapshot(owner).potionRng,v.after,'final '..v.seed)
 end
 print('POTION_RANDOM_FIXED_VECTORS_PASS9')`);
});

test('source rarity boundaries and actual limited initial/Fruit rejections retain exact RNG consumption',()=>{
 lua(`for _,case in ipairs({{0,'common'},{64,'common'},{65,'uncommon'},{89,'uncommon'},{90,'rare'},{99,'rare'}})do
  assert(P.rarity(case[1])==case[2])
 end
 -- Hand-derived XS128 (0,3): first bounded33 index3; next is10.
 -- First Block is valid but always discarded by limited; Weak is accepted.
 local owner=state(3);local result=P.sample(owner,{rarity='common',limited=true})
 same(result.attempts,{3,10});assert(result.sourceId=='Weak Potion')
 same(P.snapshot(owner).potionRng,{words={'0000000000000003','00000000018000c0'},counter=9})
 owner=state(28);result=P.sample(owner,{rarity='rare'})
 same(result.attempts,{28});assert(result.sourceId=='Fruit Juice' and owner.potionRng.counter==8)
 -- XS128 (0,8): index8 then28. Fruit matches rare but must be rejected
 -- after the wasted initial candidate in the limited overload.
 owner=state(8);result=P.sample(owner,{rarity='rare',limited=true})
 assert(result.attempts[1]==8 and result.attempts[2]==28 and #result.attempts>=3)
 assert(result.sourceId~='Fruit Juice' and result.rarity=='rare')
 assert(owner.potionRng.counter==7+#result.attempts)
 owner=state(2);result=P.sample(owner,{rarity='rare',limited=true})
 assert(result.attempts[1]==2 and #result.attempts>=2,'valid initial Heart must also be discarded')
 owner=state(3,2147483647);result=P.sample(owner,{rarity='common'})
 assert(result.sourceIndex==3 and owner.potionRng.counter==-2147483648)
 print('POTION_RANDOM_BOUNDARIES_PASS')`);
});

test('owner snapshots, staged commit and invalid arguments preserve state without sampling side effects',()=>{
 lua(`local owner=P.new('2780424839485660359');local saved=P.snapshot(owner)
 local restored=P.restore(saved);local staged=P.clone(owner)
 P.sample(staged);same(P.snapshot(owner),saved);same(P.snapshot(restored),saved)
 P.commit(owner,staged);same(P.snapshot(owner),P.snapshot(staged))
 P.totallyRandom(staged);assert(P.snapshot(owner).potionRng.counter~=P.snapshot(staged).potionRng.counter)
 local before=P.snapshot(owner)
 for _,options in ipairs({false,3,'rare',{rarity='missing'},{limited=1},{rarity=false},{extra=true},setmetatable({},{})})do
  assert(not pcall(P.sample,owner,options));same(P.snapshot(owner),before)
 end
 for _,roll in ipairs({-1,100,64.5,math.huge})do assert(not pcall(P.rarity,roll))end
 assert(not pcall(P.sample,owner,{},true));same(P.snapshot(owner),before)
 assert(not pcall(P.totallyRandom,owner,true));same(P.snapshot(owner),before)
 assert(not pcall(P.commit,owner,staged,true));same(P.snapshot(owner),before)
 assert(not pcall(P.commit,owner,{}));same(P.snapshot(owner),before)
 local bad=P.snapshot(owner);bad.version=2;assert(not pcall(P.restore,bad))
 bad=P.snapshot(owner);bad.extra=true;assert(not pcall(P.restore,bad))
 bad=P.snapshot(owner);bad.potionRng.counter=1.5;assert(not pcall(P.restore,bad))
 same(P.snapshot(owner),before)
 print('POTION_RANDOM_OWNER_ATOMIC_PASS')`);
});
