import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const source=JSON.parse(readFileSync(new URL('./fixtures/spheric-guardian-source.json',import.meta.url),'utf8'));
const enemy = data => data.enemies.enemies.find(entry => entry.id === 'spheric_guardian');

test('SphericGuardian source contract is pinned with explicit retrieved-text provenance and unresolved old byte lock',()=>{
  assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.match(source.provenance,/not authenticated PC binary/);
  for(const record of source.sources){
    assert.equal(record.url,`https://github.com/aeubanks/sts/blob/${source.sourceCommit}/${record.path}`);
    assert.match(record.retrievedTextSha256,/^[0-9a-f]{64}$/);
    for(const [start,end] of Object.values(record.lines)) assert.ok(start>0 && end>=start);
  }
  assert.equal(source.sources[0].retrievedTextSha256,'8f7c8e3ac1ac52b8f2d50dd83aaed6af96a7cf9e0fb125804611efcfcd31f6dc');
  const prior=JSON.parse(readFileSync(new URL('./fixtures/cross-act-source-lock.json',import.meta.url),'utf8'));
  assert.equal(prior.files['helpers/MonsterHelper.java'],'7a6b20e5b115b6deaea1b8d1bb65d11295aa1d03513f2a592de298fc3fc914eb');
  assert.match(source.sources[2].byteAttestation,/Unresolved/);
});

test('source A0 HP20, prebattle powers and all four ordered move effects enter validated data',()=>{
  const data=loadContent('data'),e=enemy(data);
  assert.equal(e.hp,source.a0.hp);assert.equal(e.hpRange,undefined);
  assert.equal(e.sourceId,source.a0.sourceId);assert.equal(e.name,source.a0.sourceId,'technical source ID, no guessed localization');
  assert.deepEqual(e.ai,{kind:'spheric_guardian',activateIntent:'spheric_guardian_2',frailIntent:'spheric_guardian_4',
    slamIntent:'spheric_guardian_1',hardenIntent:'spheric_guardian_3',artifactStacks:3,startingBlock:40,rollRange:100});
  assert.deepEqual(e.intents.map(move=>move.effects),source.a0.moves.map(move=>move.effects));
  assert.deepEqual(source.a0.preBattle,[{status:'barricade',present:true},{status:'artifact',amount:3},{block:40}]);
  assert.deepEqual(validateContent(data),[]);
});

test('explicit Act2 mappings use existing source IDs without altering Act1 or copying source weights',()=>{
  const data=loadContent('data');
  const catalog=JSON.parse(readFileSync('data/catalogs/sts1-acts234.json','utf8'));
  const city=catalog.acts.find(act=>act.act===2);
  const ids=new Set([...city.weak,...city.hard].map(entry=>entry.sourceEncounterId));
  assert.deepEqual(data.enemies.act2Encounters,source.encounters);
  for(const [id,roster] of Object.entries(data.enemies.act2Encounters)){
    assert.ok(ids.has(id));assert.ok(Array.isArray(roster));assert.ok(roster.every(id=>typeof id==='string'));
  }
  assert.equal(data.enemies.encounters.length,18);
  assert.ok(data.enemies.encounters.every(entry=>entry.maxFloor<=16 && !entry.enemies?.includes('spheric_guardian')));
  assert.equal(data.enemies.enemies.find(e=>e.id==='sentry').tier,'elite','a normal mixed encounter does not reclassify the Sentry');
});

for(const [name,mutate,path] of [
  ['unknown AI field',e=>e.ai.guess=1,/ai.guess/],
  ['wrong HP',e=>e.hp=21,/\.hp/],
  ['random HP',e=>e.hpRange={min:20,max:20},/\.hp/],
  ['wrong starting Block',e=>e.ai.startingBlock=41,/startingBlock/],
  ['missing Artifact',e=>delete e.ai.artifactStacks,/artifactStacks/],
  ['fractional Artifact',e=>e.ai.artifactStacks=3.5,/artifactStacks/],
  ['wrong roll range',e=>e.ai.rollRange=99,/rollRange/],
  ['string roll range',e=>e.ai.rollRange='100',/rollRange/],
  ['unknown move',e=>e.ai.frailIntent='missing',/frailIntent/],
  ['aliased moves',e=>e.ai.slamIntent=e.ai.hardenIntent,/four distinct/],
  ['extra move',e=>e.intents.push({id:'extra',kind:'attack',effects:[{op:'damage',value:10}]}),/four distinct/],
  ['wrong opening type',e=>e.intents[0].kind='buff',/activateIntent/],
  ['wrong opening Block',e=>e.intents[0].effects[0].value=35,/activateIntent/],
  ['wrong hit count',e=>e.intents[2].effects[0].times=3,/slamIntent/],
  ['single-hit replacement',e=>delete e.intents[2].effects[0].times,/slamIntent/],
  ['reversed Frail effects',e=>e.intents[1].effects.reverse(),/frailIntent/],
  ['wrong Frail duration',e=>e.intents[1].effects[1].value=4,/frailIntent/],
  ['reversed harden effects',e=>e.intents[3].effects.reverse(),/hardenIntent/],
  ['ally harden substitution',e=>e.intents[3].effects[0].target='random_ally',/hardenIntent/],
]) test(`rejects SphericGuardian ${name}`,()=>{
  const data=loadContent('data');mutate(enemy(data));assert.match(validateContent(data).join('\n'),path);
});
for(const [name,mutate] of [
  ['reversed source composition',d=>d['Sentry and Sphere'].reverse()],
  ['deleted member',d=>d['Sentry and Sphere'].pop()],
  ['unknown member',d=>d['Spheric Guardian'][0]='missing'],
  ['new source pool',d=>d['Fake Sphere']=['spheric_guardian']],
  ['missing definition',d=>delete d['Spheric Guardian']],
  ['weighted substitute pool',d=>d['Spheric Guardian']={weight:2,enemies:['spheric_guardian']}],
]) test(`rejects explicit Act2 ${name}`,()=>{
  const data=loadContent('data');mutate(data.enemies.act2Encounters);assert.match(validateContent(data).join('\n'),/act2Encounters/);
});

test('catalog-backed Act2 validation cannot overwrite its authoring source or an alias',async()=>{
  const { mkdtempSync, mkdirSync, writeFileSync, rmSync, linkSync, symlinkSync }=await import('node:fs');
  const { tmpdir }=await import('node:os');
  const { join }=await import('node:path');
  const { buildLuaData }=await import('../scripts/build-lua-data.mjs');
  const { contentFiles }=await import('../scripts/validate-data.mjs');
  const directory=mkdtempSync(join(tmpdir(),'abyss-act2-input-'));
  try {
    const data=loadContent('data');
    for(const file of contentFiles) writeFileSync(join(directory,`${file}.json`),JSON.stringify(data[file]));
    mkdirSync(join(directory,'catalogs'));
    const catalog=join(directory,'catalogs/sts1-acts234.json'),text=readFileSync('data/catalogs/sts1-acts234.json','utf8');
    writeFileSync(catalog,text);
    const hard=join(directory,'hard.lua');linkSync(catalog,hard);
    const aliases=[catalog,hard];
    if(process.platform!=='win32') {const symbolic=join(directory,'symbolic.lua');symlinkSync(catalog,symbolic);aliases.push(symbolic);}
    for(const output of aliases) {
      assert.throws(()=>buildLuaData(directory,output),/must not overwrite an input/);
      assert.equal(readFileSync(catalog,'utf8'),text);
    }
  } finally {rmSync(directory,{recursive:true,force:true});}
});

test('alternate bundle builds also protect the canonical catalog actually read by the validator',async()=>{
  const { mkdtempSync, mkdirSync, writeFileSync, rmSync, copyFileSync, linkSync, symlinkSync }=await import('node:fs');
  const { tmpdir }=await import('node:os');
  const { join }=await import('node:path');
  const { pathToFileURL }=await import('node:url');
  const { contentFiles }=await import('../scripts/validate-data.mjs');
  const directory=mkdtempSync(join(tmpdir(),'abyss-act2-canonical-'));
  try {
    mkdirSync(join(directory,'scripts'));mkdirSync(join(directory,'data/catalogs'),{recursive:true});
    for(const file of ['build-lua-data.mjs','build-original-v4.mjs','validate-data.mjs']) copyFileSync(`scripts/${file}`,join(directory,'scripts',file));
    const canonical=join(directory,'data/catalogs/sts1-acts234.json'),text=readFileSync('data/catalogs/sts1-acts234.json','utf8');
    writeFileSync(canonical,text);
    const input=join(directory,'alternate-input');mkdirSync(input);
    const data=loadContent('data');
    for(const file of contentFiles) writeFileSync(join(input,`${file}.json`),JSON.stringify(data[file]));
    const { buildLuaData }=await import(pathToFileURL(join(directory,'scripts/build-lua-data.mjs')).href);
    const hard=join(directory,'canonical-hard.lua');linkSync(canonical,hard);
    const aliases=[canonical,hard];
    if(process.platform!=='win32') {const symbolic=join(directory,'canonical-symlink.lua');symlinkSync(canonical,symbolic);aliases.push(symbolic);}
    for(const output of aliases) {
      assert.throws(()=>buildLuaData(input,output),/must not overwrite an input/);
      assert.equal(readFileSync(canonical,'utf8'),text);
    }
  } finally {rmSync(directory,{recursive:true,force:true});}
});

// Required for the existing all-definition theme gate even while this enemy is unwired.
test('staged SphericGuardian reuses explicit provisional Sentry presentation aliases without weakening coverage',async()=>{
  const { validateTheme }=await import('../scripts/build-ui-theme.mjs');
  const theme=JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8'));
  assert.equal(theme.icon.enemy.spheric_guardian,112027);
  assert.equal(theme.icon.enemy.spheric_guardian,theme.icon.enemy.sentry);
  assert.equal(theme.sound.action_spheric_guardian,50421);
  assert.equal(theme.sound.action_spheric_guardian,theme.sound.action_sentry);
  assert.match(theme.note,/SphericGuardian.*暂复用 Sentry.*不代表新美术批准或原生验收/);
  const data=loadContent('data');
  assert.deepEqual(validateTheme(theme,data),[]);
  const noIcon=structuredClone(theme);delete noIcon.icon.enemy.spheric_guardian;
  assert.ok(validateTheme(noIcon,data).includes('icon.enemy has no picture for spheric_guardian'));
  const noSound=structuredClone(theme);delete noSound.sound.action_spheric_guardian;
  assert.ok(validateTheme(noSound,data).includes('sound.action_spheric_guardian has no actor action sound'));
});
