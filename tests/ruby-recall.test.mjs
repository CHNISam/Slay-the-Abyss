import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';

const source=JSON.parse(readFileSync('tests/fixtures/ruby-recall-source-contract.json','utf8'));
test('Recall source contract pins actual tree paths, exact blobs and the existing history gate',()=>{
  assert.equal(source.sourceRepository,'aeubanks/sts');
  assert.equal(source.sourceCommit,'319009d5df0a82d9fb0f23cc22322286c6a87ec0');
  assert.deepEqual(source.sources.map(row=>row.path),['rooms/CampfireUI.java','rooms/RestRoom.java',
    'ui/campfire/RecallOption.java','vfx/ObtainKeyEffect.java','vfx/campfire/CampfireRecallEffect.java']);
  for(const row of source.sources){
    assert.equal(row.url,`https://github.com/aeubanks/sts/blob/${source.sourceCommit}/${row.path}`);
    assert.match(row.gitBlobSha,/^[a-f0-9]{40}$/);assert.match(row.sha256,/^[a-f0-9]{64}$/);
    assert.ok(Number.isInteger(row.size)&&row.size>0);
  }
  assert.equal(source.behavior.availability,'Settings.isFinalActAvailable && !Settings.hasRubyKey');
  assert.deepEqual(source.behavior.appendOrder,['rest','smith','relicOptions','recall']);
  assert.equal(source.behavior.gameplayRngDraws,0);assert.equal(source.behavior.restHeal,false);
  assert.equal(source.behavior.smithUpgrade,false);assert.equal(source.behavior.restRelicHooks,false);
  assert.equal(source.behavior.completion.keyColor,'RED');
  assert.equal(source.fieldMapping['Settings.isFinalActAvailable'],'run.endingUnlocked == true');
  assert.equal(source.behavior.localization.textAvailableInMirror,false);
  assert.match(source.implementationBoundary,/Local existing-footer NodeUI Recall route implemented with mock-native tests/);
  assert.match(source.implementationBoundary,/native-client acceptance NOT_RUN/);
  assert.match(source.implementationBoundary,/history producer and persistence UNWIRED/);
  assert.match(source.implementationBoundary,/natural full-campaign evidence NOT_RUN/);
  assert.match(source.implementationBoundary,/Tests explicitly stage endingUnlocked=true/);
  assert.doesNotMatch(source.implementationBoundary,/Fixed two-button NodeUI.*pending/);
});

test('real Nodes map/camp Recall command is once-only, source-bound and resource-pure',()=>{
  const result=runLua('tests/lua/ruby_recall.lua');
  assert.equal(result.status,0,result.stderr||result.stdout);
  assert.match(result.stdout,/RUBY_RECALL_PASS 15/);
});

test('three original camp commands retain frozen bodies around the reviewed Toxic Egg adapter',()=>{
  const code=readFileSync('src/lua/abyss_nodes.lua','utf8').replaceAll('\r\n','\n');
  const start=code.indexOf(source.legacyCampCommands.start);
  const end=code.indexOf(source.legacyCampCommands.endExclusive,start);
  assert.ok(start>0&&end>start);
  assert.deepEqual(source.legacyCampCommands.names,['rest','claimRestReward','upgrade']);
  let original=code.slice(start,end);
  // Reverse only the source-verified Toxic Egg preview adapter. Preserve the
  // frozen original rest/claim/upgrade block hash, including every old guard.
  for(const [before,after] of [
    ['local cards,rng,offset,upgrades=CardPool.prepareRewards(context)', 'local cards,rng,offset=CardPool.prepareRewards(context)'],
    ['local reward={cards=cards,resolved=false,cardUpgrades=upgrades}\n            RelicHooks.previewCardReward(owner,reward,true)\n            return reward', 'return {cards=cards,resolved=false}'],
    ['Run.obtainCard(staged,reward.cards[choice],\n                {upgraded=reward.cardUpgrades and reward.cardUpgrades[choice]==true})', 'Run.obtainCard(staged,reward.cards[choice])'],
  ]){
    assert.equal(original.split(before).length-1,1,'one exact reviewed preview adapter');
    original=original.replace(before,after);
  }
  assert.equal(createHash('sha256').update(original).digest('hex'),
    source.legacyCampCommands.unchangedBlockSha256);
});
