import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const base='data/reference/sts1-card-pools/';
const read=name=>JSON.parse(readFileSync(base+name,'utf8'));
const registration=read('registration.json'), vectors=read('pools.json'), coverage=read('coverage.json');
const rows=registration.registration, pools=vectors.pools;
const byId=new Map(rows.map(row=>[row.id,row]));
const textHash=path=>createHash('sha256').update(readFileSync(path,'utf8').replaceAll('\r\n','\n')).digest('hex');
test('catalogue pins V2.3.4 source and records all 370 original registrations without source bodies',()=>{
 assert.equal(registration.source.commit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
 assert.equal(registration.source.declaredVersion,'[V2.3.4] (12-18-2022)');
 assert.equal(registration.source.extractorSha256,textHash('tools/oracles/sts1_card_catalog_extract.py'));
 assert.equal(rows.length,370);assert.equal(byId.size,370);
 assert.deepEqual(Object.fromEntries(['red','green','blue','purple','colorless','curse'].map(group=>[group,rows.filter(row=>row.registrationGroup===group).length])),
 {red:75,green:75,blue:75,purple:75,colorless:56,curse:14});
 for(const [index,row] of rows.entries()){
  assert.equal(row.registrationIndex,index);
  assert.match(row.sha256,/^[a-f0-9]{64}$/);assert.match(row.sourcePath,/^cards\/[\w/]+\.java$/);
  assert.ok(Number.isInteger(row.cost));assert.ok(!('sourceText' in row));
  for(const id of row.directCardDependencies)assert.ok(byId.has(id));
 }
});
test('raw reward pools preserve full-library HashMap traversal; src snapshots reverse it',()=>{
 assert.equal(vectors.registrationSha256,textHash(base+'registration.json'));
 assert.equal(vectors.generatorSha256,textHash('tools/oracles/sts1_card_pools.py'));
 assert.equal(vectors.hashMap.capacity,512);assert.equal(vectors.hashMap.maximumChainDuringConstruction,4);
 assert.equal(vectors.hashMap.treeification,false);
 assert.deepEqual(Object.fromEntries(Object.entries(pools.redReward).map(([k,v])=>[k,v.length])),{COMMON:20,UNCOMMON:36,RARE:16});
 assert.deepEqual(pools.redReward.COMMON.slice(0,5),['Anger','Cleave','Warcry','Flex','Iron Wave']);
 assert.deepEqual(pools.redReward.RARE.slice(0,4),['Immolate','Offering','Exhume','Reaper']);
 for(const [rarity,ids] of Object.entries(pools.redReward)){
  const raw=pools.libraryHashMapTraversal.filter(id=>byId.get(id).color==='RED'&&byId.get(id).rarity===rarity);
  assert.deepEqual(ids,raw);assert.notDeepEqual(ids,[...ids].sort());
  assert.deepEqual(pools.srcRed[rarity],[...ids].reverse());
 }
});
test('typed shop and colorless pools use exact original ID comparison, not local snake case',()=>{
 for(const [rarity,types]of Object.entries(pools.redShopTyped))
  for(const [type,ids]of Object.entries(types)){
   assert.deepEqual(ids,[...ids].sort());
   assert.deepEqual(new Set(ids),new Set(pools.redReward[rarity].filter(id=>byId.get(id).type===type)));
  }
 assert.deepEqual(pools.redShopTyped.COMMON.POWER,[]);
 assert.equal(pools.colorlessShopByRarity.UNCOMMON.length,20);
 assert.equal(pools.colorlessShopByRarity.RARE.length,15);
 assert.ok(pools.colorlessShopByRarity.UNCOMMON.includes('PanicButton'));
 assert.ok(pools.colorlessShopByRarity.RARE.includes('HandOfGreed'));
 assert.equal(pools.colorlessRaw.length,35);
 assert.deepEqual(pools.srcColorless,[...pools.colorlessRaw].reverse());
});
test('random curse uses a separate library HashMap, not the underground curse pool order',()=>{
 assert.equal(pools.curseRaw.length,10);assert.equal(pools.curseLibrarySelection.length,10);
 assert.deepEqual(pools.curseLibrarySelection,['Regret','Injury','Shame','Parasite','Normality','Doubt','Writhe','Pain','Decay','Clumsy']);
 assert.deepEqual(new Set(pools.curseRaw),new Set(pools.curseLibrarySelection));
 assert.notDeepEqual(pools.curseRaw,pools.curseLibrarySelection);
 for(const id of ['AscendersBane','CurseOfTheBell','Necronomicurse','Pride']){
  assert.ok(pools.curseLibraryHashMapTraversal.includes(id));assert.ok(!pools.curseRaw.includes(id));
 }
 assert.deepEqual(pools.srcCurse,[...pools.curseRaw].reverse());
});
test('full-unlock Prismatic pool includes legal other-color and colorless cards and their direct tokens',()=>{
 assert.deepEqual(Object.fromEntries(Object.entries(pools.allColorRewardByRarity).map(([k,v])=>[k,v.identitySelection.length])),
 {COMMON:76,UNCOMMON:160,RARE:84});
 for(const [rarity,pool]of Object.entries(pools.allColorRewardByRarity)){
  assert.deepEqual(pool.identitySelection,[...pool.identitySelection].sort());
  assert.equal(pool.shuffleStream,'cardRng');assert.equal(pool.identityStream,'cardRng');
  for(const id of pool.identitySelection)assert.equal(byId.get(id).rarity,rarity);
  for(const typed of Object.values(pools.allColorTypedByRarity[rarity])){
   assert.equal(typed.shuffleStream,'cardRandomRng');assert.equal(typed.identityStream,'cardRng');
   for(const id of typed.identitySelection)assert.ok(!byId.get(id).tags.includes('HEALING'));
  }
 }
 assert.ok(pools.allColorRewardByRarity.RARE.identitySelection.includes('Wish'));
 assert.ok(pools.allColorRewardByRarity.RARE.identitySelection.includes('Apotheosis'));
 assert.equal(pools.ordinaryPoolDirectSpecialDependencies.length,12);
 for(const id of pools.ordinaryPoolDirectSpecialDependencies)assert.equal(byId.get(id).rarity,'SPECIAL');
});
test('coverage audit identifies baseline gaps without treating data definitions as playable effects',()=>{
 assert.equal(coverage.localBaselineCommit,'eb4e8af42297abfc806e58835a36b044f728d028');
 assert.equal(coverage.sourceRedAll,75);assert.equal(coverage.sourceRedNonbasic,72);
 for(const row of coverage.redMissingFromRecordedLaunch){
  assert.ok(byId.has(row.sourceId));assert.equal(row.inRecordedLaunch,false);
 }
 assert.equal(coverage.status.length,5);assert.equal(coverage.specialRegistryNotAutomaticallyAct1Reachable.length,16);
 assert.match(coverage.boundary,/no assertion of effect support/);
});
