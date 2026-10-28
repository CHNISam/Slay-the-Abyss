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
  const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
  const parts=JSON.parse(read('tests/fixtures/ruby-recall-partitions.json'));
  // Only this exact registration/selection instrumentation may surround the
  // frozen entire Git-base body. No original loop, matrix or assertion changes.
  assert.deepEqual(parts,{
  "base": "c04075c0aef8dba531155157b4a4dd0b67cade01",
  "originalGitBlob": "a057464850df2a8d035265b6f58f8e78558bc6cf",
  "originalSha256LF": "9c381c723a7bf5f3c2eb6f185f43a61f4815082310b1c7354a74a946013af88c",
  "entry": "tests/fixtures/js-owned/tests/lua/ruby_recall.lua",
  "total": 15,
  "timeoutMilliseconds": 30000,
  "prefix": "local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 8\nlocal sliceRegistered,sliceExecuted=0,0\n",
  "before": "local function test(name,fn)fn();count=count+1;print('ok ruby recall '..count..' - '..name)end",
  "after": "local function test(name,fn)\n    sliceRegistered=sliceRegistered+1\n    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n    fn();sliceExecuted=sliceExecuted+1;count=count+1\n    print('ok ruby recall '..count..' - '..name)\n    print('RUBY_RECALL_CASE '..sliceRegistered)\nend",
  "footer": "\nassert(sliceRegistered==15,'all fifteen original Recall groups must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'every selected Recall group must execute')\nprint('RUBY_RECALL_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n",
  "slices": [
    {
      "path": "tests/fixtures/js-owned/tests/lua/ruby_recall.lua",
      "first": 1,
      "last": 8
    },
    {
      "path": "tests/fixtures/js-owned/tests/lua/ruby_recall_slice_2.lua",
      "first": 9,
      "last": 10
    },
    {
      "path": "tests/fixtures/js-owned/tests/lua/ruby_recall_slice_3.lua",
      "first": 11,
      "last": 15
    }
  ]
});
  let body=read(parts.entry);
  assert(body.startsWith(parts.prefix));assert(body.endsWith(parts.footer));
  body=body.slice(parts.prefix.length,-parts.footer.length);
  assert.equal(body.split(parts.after).length,2);body=body.replace(parts.after,parts.before);
  assert.equal(createHash('sha256').update(body).digest('hex'),parts.originalSha256LF);
  const bytes=Buffer.from(body);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),parts.originalGitBlob);
  const covered=[],executed=[];
  for(const [index,part]of parts.slices.entries()){
    if(index)assert.equal(read(part.path),`assert(loadfile('${parts.entry}'))(${part.first},${part.last})\n`);
    const expected=Array.from({length:part.last-part.first+1},(_,n)=>part.first+n);
    covered.push(...expected);
    const started=Date.now(),result=runLua(part.path,{timeout:parts.timeoutMilliseconds});
    assert.equal(result.status,0,result.stderr+result.stdout);
    const actual=[...result.stdout.matchAll(/^RUBY_RECALL_CASE (\d+)$/gm)].map(match=>Number(match[1]));
    assert.deepEqual(actual,expected,part.path);
    assert.match(result.stdout,new RegExp(`^RUBY_RECALL_PASS ${expected.length}$`,'m'));
    assert.match(result.stdout,new RegExp(`^RUBY_RECALL_SLICE ${part.first} ${part.last} ${expected.length}$`,'m'));
    executed.push(...actual);
    console.log(`Recall core ${part.first}-${part.last}: ${Date.now()-started} ms`);
  }
  const all=Array.from({length:15},(_,index)=>index+1);
  assert.deepEqual(covered,all);assert.deepEqual(executed,all);
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
