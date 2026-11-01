import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';

const catalog=JSON.parse(readFileSync('data/catalogs/sts1-ironclad-potions.json','utf8'));
const vectors=JSON.parse(readFileSync('tests/fixtures/sts1-ironclad-potion-pool-vectors.json','utf8'));
test('Ironclad catalog preserves all thirty-three entries in original order and ownership',()=>{
 assert.equal(catalog.productionWired,false);assert.equal(catalog.pool.length,33);
 assert.deepEqual(catalog.pool.map(({sourceId,rarity})=>({sourceId,rarity})),vectors.pool);
 assert.deepEqual(catalog.pool.slice(0,3).map(p=>p.sourceId),['BloodPotion','ElixirPotion','HeartOfIron']);
 assert.equal(catalog.pool.filter(p=>p.owner==='IRONCLAD').length,3);
 assert.equal(catalog.pool.filter(p=>p.owner==='shared').length,30);
 assert.deepEqual(catalog.counts.byRarity,{common:17,uncommon:9,rare:7});
 assert.equal(catalog.pool.find(p=>p.sourceId==='BlessingOfTheForge').rarity,'common');
 assert.equal(new Set(catalog.pool.map(p=>p.sourceId)).size,33);
 for(const excluded of Object.values(catalog.excludedOtherClassPools).flat())assert(!catalog.pool.some(p=>p.sourceId===excluded));
 assert.equal(Object.values(catalog.excludedOtherClassPools).flat().length,9);
 const existing=catalog.pool.filter(p=>p.currentProjectId!==null);
 assert.deepEqual(existing.map(p=>p.currentProjectId).sort(),['block_potion','dexterity_potion','energy_potion','fire_potion','regen_potion','strength_potion']);
 assert.equal(catalog.pool.filter(p=>p.currentProjectId===null).length,27);
 assert.equal(catalog.effectGroups.reduce((n,g)=>n+g.sourceIds.length,0),33);
 assert.equal(new Set(catalog.effectGroups.flatMap(g=>g.sourceIds)).size,33);
});
test('original pool oracle retains its declared fixed source and reproducible canonical text identity',()=>{
 assert.equal(vectors.sourceCommit,catalog.source.commit);
 const normalized=readFileSync('tools/oracles/sts1_potion_pool.py','utf8').replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(normalized).digest('hex'),vectors.generatorCanonicalLfSha256);
 assert.equal(vectors.cases.length,9);
});

function luaCase(body){
 const dir=mkdtempSync(join(tmpdir(),'sts1-potion-pool-'));
 try{const file=join(dir,'case.lua');writeFileSync(file,body);const result=runLua(file,{timeout:60000});assert.equal(result.status,0,result.stderr||result.stdout);}
 finally{rmSync(dir,{recursive:true,force:true});}
}
const sourceInterpreter=`local R=require('abyss_sts_random')
local pool=${toLua(catalog.pool.map(({sourceId,rarity})=>({sourceId,rarity})))}
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path)
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function rarity(roll)return roll<65 and 'common' or roll<90 and 'uncommon' or 'rare'end
local function selectPotion(draw,wanted,limited,uniform)
 if uniform then local n=draw('uniform_candidate',0,32);return {sourceId=pool[n+1].sourceId,rarity=pool[n+1].rarity,attempts={n}}end
 wanted=wanted or rarity(draw('rarity',0,99))
 local index=draw('candidate',0,32);local attempts={index}
 local spam=limited
 while pool[index+1].rarity~=wanted or spam do
  spam=limited;index=draw('candidate',0,32);attempts[#attempts+1]=index
  if pool[index+1].sourceId~='Fruit Juice'then spam=false end
 end
 return {sourceId=pool[index+1].sourceId,rarity=wanted,attempts=attempts}
end
`;
test('complete-pool rejection, persistent shop/drop/refill/Entropic stream and every RNG state match nine independent vectors',()=>{
 luaCase(sourceInterpreter+`
for _,v in ipairs(${toLua(vectors.cases)})do
 local rng=R.fromSeed(v.seed);local trace={};local modifier=0
 local function draw(purpose,minimum,maximum)
  local value=R.randomIntBetween(rng,minimum,maximum)
  trace[#trace+1]={purpose=purpose,minimum=minimum,maximum=maximum,value=value,after=R.snapshot(rng)}
  return value
 end
 for _,record in ipairs(v.records)do
  local action=record.action;local result
  if action:find('drop',1,true)then
   local chance=action=='all_escaped_normal_drop' and 0 or 40+modifier
   if action=='white_beast_statue_drop'then chance=100 end
   if action=='four_rewards_suppress_drop'then chance=0 end
   local dropped=draw('drop',0,99)<chance;result={chance=chance,dropped=dropped}
   if dropped then result.potion=selectPotion(draw);modifier=modifier-10 else modifier=modifier+10 end
   result.modifier=modifier
  elseif action=='explicit_rare_limited'then result=selectPotion(draw,'rare',true)
  elseif action=='explicit_rare'then result=selectPotion(draw,'rare')
  elseif action=='totally_random'then result=selectPotion(draw,nil,false,true)
  else result=selectPotion(draw,nil,action:find('entropic_combat',1,true)~=nil)end
  same(result,record.result,action..' '..v.seed);same(R.snapshot(rng),record.after,action..' after')
  assert(modifier==record.modifier)
 end
 same(trace,v.trace,'all draws '..v.seed);same(R.snapshot(rng),v.after,'final '..v.seed)
end
print('SOURCE_POTION_POOL_VECTORS_PASS 9')`);
});
test('all rarity boundaries, repeated rejection, limited initial discard and Fruit Juice behavior remain source-exact',()=>{
 luaCase(sourceInterpreter+`
for _,v in ipairs({{0,'common'},{64,'common'},{65,'uncommon'},{89,'uncommon'},{90,'rare'},{99,'rare'}})do assert(rarity(v[1])==v[2])end
local function controlled(values)
 local at=0;return function(purpose,lo,hi)at=at+1;local n=assert(values[at]);assert(n>=lo and n<=hi);return n end,function()return at end
end
local draw,calls=controlled({3});local p=selectPotion(draw,'common');assert(p.sourceId=='Block Potion' and calls()==1)
draw,calls=controlled({0,19,2,3});p=selectPotion(draw,'common',true)
assert(p.sourceId=='Block Potion' and calls()==4) -- initial matching Blood is discarded, then wrong rarities rejected
draw,calls=controlled({28});p=selectPotion(draw,'rare');assert(p.sourceId=='Fruit Juice' and calls()==1)
draw,calls=controlled({2,28,27});p=selectPotion(draw,'rare',true)
assert(p.sourceId=='CultistPotion' and calls()==3) -- valid initial Heart discarded; Fruit excluded only inside limited loop
for i=0,32 do draw,calls=controlled({i});p=selectPotion(draw,nil,false,true);assert(p.sourceId==pool[i+1].sourceId and calls()==1)end
print('SOURCE_POTION_POOL_BOUNDARIES_PASS')`);
});
