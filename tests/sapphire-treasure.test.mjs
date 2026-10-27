import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';

const lock=JSON.parse(readFileSync('tests/fixtures/sapphire-treasure-source-contract.json','utf8'));
test('Sapphire source contract pins exact chest/reward/room/effect and hook blobs',()=>{
  assert.equal(lock.sourceRepository,'aeubanks/sts');
  assert.equal(lock.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.deepEqual(lock.sources.map(row=>row.path),[
    'rewards/chests/AbstractChest.java','rewards/RewardItem.java','rooms/TreasureRoom.java',
    'rooms/TreasureRoomBoss.java','vfx/ObtainKeyEffect.java','relics/Matryoshka.java',
    'relics/CursedKey.java','rooms/AbstractRoom.java','rewards/chests/BossChest.java',
  ]);
  for(const row of lock.sources){
    assert.equal(row.url,`https://github.com/aeubanks/sts/blob/${lock.sourceCommit}/${row.path}`);
    assert.match(row.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(row.sha256,/^[a-f0-9]{64}$/);
    assert.ok(Number.isInteger(row.size)&&row.size>0);
  }
  assert.equal(lock.sources[0].gitBlobSha,'72a42aa9cca3b882f9a4a6c77b4e26f2f78df1a8');
  assert.equal(lock.sources[1].gitBlobSha,'a23c192d58c6304acd76505da7365490636f1f31');
  assert.equal(lock.behavior.availability,'Settings.isFinalActAvailable && !Settings.hasSapphireKey');
  assert.deepEqual(lock.behavior.openOrder,['onChestOpen','goldAndCursedChestRewards','baseRelic',
    'sapphireLinkedToLastReward','onChestOpenAfter']);
  assert.equal(lock.behavior.gameplayRngDrawsForChoice,0);
  assert.match(lock.behavior.linkedRelic,/not a Matryoshka-added extra relic/);
  assert.equal(lock.fieldMapping['Settings.isFinalActAvailable'],'run.endingUnlocked == true');
  for(const boundary of ['CORE + LOCAL MOCKED-NATIVE UI','no source full-chest RNG parity','UNIMPLEMENTED',
    'Legacy claimTreasure(run)','not newly token-bound','Local mocked-native Sapphire UI wired through both source-bound choices',
    'actual native acceptance NOT_RUN',
    'history producer/persistence UNWIRED','natural campaign evidence NOT_RUN']){
    assert.ok(lock.implementationBoundary.includes(boundary),boundary);
  }
});

const digest=text=>createHash('sha256').update(text).digest('hex');
function verifyIntegratedLegacyTreasure(code){
  const block=lock.legacyBlocks.find(row=>row.name==='legacyTreasureGeneration');
  assert.equal(block.start,'        local relics = unownedRelics(run)\n');
  const combinedStart=block.start.replace('unownedRelics(run)','unownedRelics(run,node.floor)');
  assert.equal(code.split(combinedStart).length-1,1,'one destination-bound treasure call');
  const start=code.indexOf(combinedStart);
  const end=code.indexOf('        -- Preserve the legacy generation above.',start);
  assert.ok(start>0&&end>start,'bounded original generation fragment');
  const combined=code.slice(start,end);
  assert.equal(combined.split('unownedRelics(run,node.floor)').length-1,1);
  // Reverse exactly the independently reviewed Darkstone argument addition.
  // The ORIGINAL frozen fragment hash remains the oracle; no hash regeneration.
  const original=combined.replace('unownedRelics(run,node.floor)','unownedRelics(run)');
  assert.equal(digest(original),block.sha256,'original generation remainder/RNG/gold unchanged');
}

test('legacy generation changes only reviewed Darkstone destination argument; Boss blocks stay byte-identical',()=>{
  const code=readFileSync('src/lua/abyss_nodes.lua','utf8').replaceAll('\r\n','\n');
  verifyIntegratedLegacyTreasure(code);
  assert.ok(code.includes("local function unownedRelics(run,roomFloor)"));
  assert.ok(code.includes("and ((relic.id~='darkstone_periapt' and relic.sourceId~='Darkstone Periapt') or roomFloor<=48)"));
  for(const block of lock.legacyBlocks.filter(row=>row.name!=='legacyTreasureGeneration')){
    const start=code.indexOf(block.start);assert.ok(start>0,block.name);
    const end=code.indexOf(block.endExclusive,start);assert.ok(end>start,block.name);
    let original=code.slice(start,end);
    if(block.name==='legacyBossClaim'){
      // Remove only the independently tested source chest adapter; the legacy
      // fallback still has its original complete, frozen body and guards.
      const adapter=`    if flow.chest then
        if choice>0 then
            if not flow.chest.opened then local ok,why=openSourceTreasure(run,flow);if not ok then return false,why end end
            local item=flow.reward.items[choice]
            if not item or item.kind~='relic' then return false,'invalid_boss_relic_choice' end
            local ok,why=takeSourceTreasure(run,flow,item.slot);if not ok then return false,why end
            flow.chosenRelic=item.id
        end
    elseif choice > 0 then`;
      assert.equal(original.split(adapter).length-1,1,'one exact source Boss adapter');
      original=original.replace(adapter,'    if choice > 0 then');
    }
    assert.equal(digest(original),block.sha256,block.name);
  }
});

test('original frozen treasure witness rejects stale-floor, RNG and gold drift after exact normalization',()=>{
  const code=readFileSync('src/lua/abyss_nodes.lua','utf8').replaceAll('\r\n','\n');
  for(const [before,after] of [
    ['local relics = unownedRelics(run,node.floor)','local relics = unownedRelics(run,run.floor)'],
    ['relics[Combat.random(random, #relics)]','relics[Combat.random(random, #relics-1)]'],
    ['or { gold = run.data.rules.rewards.normalGold }','or { gold = run.data.rules.rewards.normalGold+1 }'],
  ]){
    const mutant=code.replace(before,after);assert.notEqual(mutant,code,before);
    assert.throws(()=>verifyIntegratedLegacyTreasure(mutant),before);
  }
});

test('same existing eligibility function governs Ruby and Sapphire without adding history',()=>{
  const code=readFileSync('src/lua/abyss_nodes.lua','utf8');
  assert.match(code,/return endingKeyEligible\(run,'ruby'\)/);
  assert.match(code,/flow\.reward\.relicId and endingKeyEligible\(run,'sapphire'\)/);
  assert.doesNotMatch(code,/run\.endingUnlocked\s*=(?!=)/);
});

// The 8–14 process exceeded its unchanged 30s budget. Only registration
// ranges change; the complete original 21-group body and fixture stay frozen.
const sapphireSlices=[
  ['sapphire_treasure.lua',1,7],['sapphire_treasure_slice_2.lua',8,13],
  ['sapphire_treasure_slice_3.lua',15,21],['sapphire_treasure_slice_4.lua',14,14],
];
test('Sapphire budget partition keeps every original body and discovers each of 21 groups exactly once',()=>{
  const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
  assert.equal(digest(read('tests/lua/sapphire_treasure.lua')),
    '1032c2146280eb73011f91d7dad76407cd02d19c9ff7feed44f194ec05ac54ee','all original cases, assertions and variants');
  assert.equal(digest(read('tests/lua/support/sapphire_source_fixture.lua')),
    '6359769726601a70e890bd18fd4f3d631f4586f8c54a6359457bf6883cdc7bac','unchanged source stream/checkpoint fixture');
  assert.deepEqual(readdirSync('tests/lua').filter(file=>/^sapphire_treasure(?:_slice_\d+)?\.lua$/.test(file)).sort(),
    sapphireSlices.map(([file])=>file).sort(),'raw Lua discovery and the JS wrapper execute the same files');
  const covered=[];
  for(const [index,[file,first,last]] of sapphireSlices.entries()){
    if(index===0)assert.ok(read('tests/lua/'+file).includes(`sliceFirst,sliceLast=sliceFirst or ${first},sliceLast or ${last}\n`));
    else assert.equal(read('tests/lua/'+file),`assert(loadfile('tests/lua/sapphire_treasure.lua'))(${first},${last})\n`);
    covered.push(...Array.from({length:last-first+1},(_,i)=>first+i));
  }
  assert.deepEqual(covered.sort((a,b)=>a-b),Array.from({length:21},(_,i)=>i+1),'no omitted or duplicate original group');
});

test('real Nodes chest choice is linked, source-bound, once-only and transactional',t=>{
  let groups=0;
  for(const [file,first,last] of sapphireSlices){
    const started=performance.now();
    const result=runLua(`tests/lua/${file}`);
    t.diagnostic(`${file}: ${Math.round(performance.now()-started)} ms`);
    assert.equal(result.status,0,result.stdout+result.stderr);
    const expected=Array.from({length:last-first+1},(_,i)=>first+i);
    assert.deepEqual([...result.stdout.matchAll(/^ok sapphire treasure (\d+) - /gm)].map(match=>Number(match[1])),expected);
    assert.match(result.stdout,new RegExp(`^SAPPHIRE_TREASURE_PASS ${expected.length}$`,'m'));groups+=expected.length;
  }
  assert.equal(groups,21);
});
