import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {originalLuaRunner} from './helpers/ci-lua-runner-inverse.mjs';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=source=>createHash('sha256').update(source).digest('hex');
const support='tests/lua/support/battle_ui_cases.lua';
const runnerHash='63ec149511d52b9e362f2c9210d092e4d97bd815c5b8c16e7009ade146d5d55b';
const original={bytes:72926,sha256:'5e82cabcd77e594c88d97b655237e661e7298ee1d25e9030c0025f9011625b2a',blob:'b5ea264cdc63b7971e27b9189b9cca1c20d94479'};
const slices=[['battle_ui.lua',1,26],['battle_ui_slice_2.lua',27,33],['battle_ui_slice_6.lua',34,34,1,3],
  ['battle_ui_slice_7.lua',34,38,4,6],['battle_ui_slice_3.lua',39,44],['battle_ui_slice_4.lua',45,47],
  ['battle_ui_slice_5.lua',48,53]];
const originalFunction='return function(first,last)\n';
const slicedFunction='return function(first,last,seedFirst,seedLast)\n';
const originalParams='first,last=assert(first),assert(last)\n';
const seedSetup="seedFirst,seedLast=seedFirst or 1,seedLast or 6\nassert(type(seedFirst)=='number'and type(seedLast)=='number'and seedFirst%1==0 and seedLast%1==0 and seedFirst>=1 and seedLast<=6 and seedFirst<=seedLast,'invalid UI playback seed slice')\n";
const originalLoop='    for seed = 1, 6 do\n';
const slicedLoop='    for seed = seedFirst, seedLast do\n';
const seedMarker='        print("UI_PLAYBACK_SEED " .. seed)\n';
const sequence=(first,last)=>Array.from({length:last-first+1},(_,i)=>first+i);
const wrapper=(row)=>`dofile('${support}')(${row.slice(1).join(',')})`;
const cleanWrapper=source=>{
  assert.doesNotMatch(source,/--\[=*\[/,'no block-commented executable wrapper');
  return source.split('\n').filter(line=>!line.startsWith('--')).join('\n').trim();
};

function restoreSupport(source){
  const guarded='    return NativeContract.control(c,definition)\n';
  assert.equal(source.split(guarded).length,2,'one exact cursor capability guard in the fixture factory');
  assert.equal(source.split(slicedFunction).length,2,'one exact seed-aware function header');
  assert.equal(source.split(originalParams+seedSetup).length,2,'one exact validated seed-range setup');
  assert.equal(source.split(slicedLoop).length,2,'one exact playback seed loop');
  assert.equal(source.split(seedMarker).length,2,'one completion marker per playback seed');
  assert.ok(source.includes('            same(ui.run,direct,"idle")\n        end\n'+seedMarker+'    end\n'),
    'seed completion marker follows the unchanged twenty-command loop');
  const restored=source.replace(guarded,'    return c\n').replace(slicedFunction,originalFunction).replace(seedSetup,'').replace(slicedLoop,originalLoop).replace(seedMarker,'');
  const bytes=Buffer.from(restored);
  assert.equal(bytes.length,original.bytes,'full original support byte count');
  assert.equal(sha(bytes),original.sha256,'all original recursive assertions, commands, fixtures and seed inputs');
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),original.blob,'full original support Git blob');
  return restored;
}
function validateUniverse(indices,seeds){
  assert.deepEqual(indices,[...sequence(1,34),...sequence(34,53)],'every other 52 logical cases once; playback case34 twice');
  assert.deepEqual(seeds,sequence(1,6),'all six original playback seeds exactly once');
}
function validatePartitions(rows,wrappers){
  assert.deepEqual(rows,slices,'only the seven reviewed case and seed ranges');
  for(const row of rows)assert.equal(cleanWrapper(wrappers[row[0]]),wrapper(row),'complete executable original-budget wrapper');
  validateUniverse(rows.flatMap(([,first,last])=>sequence(first,last)),
    rows.filter(([,first,last])=>first<=34&&last>=34).flatMap(([,first,last,seedFirst=1,seedLast=6])=>sequence(seedFirst,seedLast)));
}
function validateRunner(source){
  assert.equal(sha(originalLuaRunner(source)),runnerHash,'unchanged runner and original deadlines');
  for(const [file]of slices)assert.ok(source.includes(`'tests/lua/${file}'`),'all seven entries retain the existing fixture deadline');
  assert.match(source,/fixture \|\| composedHost \? 60000 : 30000;/,'battle UI keeps its existing 60-second fixture budget');
}
function validateLegacyBody(source){
  const body=source.slice(source.indexOf('\ntest('),source.lastIndexOf('\nassert(registered')).trim();
  // Review-specific migrations are inverse-normalized; all other frozen cases stay intact.
  const legacyDeath='    assert(poison == 1 and death == 1 and intent == 1 and not stage.children.enemy1.visible)';
  const migratedDeath=[
    '    assert(poison == 1 and death == 1 and intent == 1)',
    '    assert(battle.enemies[1].hp == 0 and battle.enemies[2].hp > 0)',
    '    local survivor = stage.children.enemy1',
    '    assert(survivor.visible and survivor.children.name.text == battle.enemies[2].name)',
    '    assert(survivor.children.hp.text == battle.enemies[2].hp .. "/" .. battle.enemies[2].maxHp)',
    '    for i = 2, 5 do assert(not stage.children["enemy" .. i].visible) end',
  ].join('\n');
  assert.equal(body.split(migratedDeath).length,2,'the exact reviewed migration must occur once');
  assert.equal(body.includes(legacyDeath),false,'the old raw-slot assertion must be replaced');
  const legacyAim='    assert(battle.energy == 3 and #battle.hand == 1 and ui.selected == nil)';
  const migratedAim='    assert(battle.energy == 3 and #battle.hand == 1 and ui.selected == battle.hand[1].uid and ui.carry.aiming)';
  assert.equal(body.split(migratedAim).length,2,'the source persistent-target migration must occur once');
  const motionFrames=[
    '    assert(stage.children.card1.localScaleX == 1, "selection must preserve the current pose before interpolation")',
    '    for _ = 1, 80 do ui:update(1 / 60) end',
    '',
  ].join('\n');
  assert.equal(body.split(motionFrames).length,2,'the source hand interpolation advance must occur once');
  // Latest user instruction adopts AbstractPlayer's persistent target mode on empty release.
  // Inverse-normalize exactly these reviewed migrations, retaining PR206's original frozen hash.
  // Every other case body and intervening helper must remain byte-for-byte unchanged.
  assert.equal(createHash('sha256').update(body.replace(migratedDeath,legacyDeath).replace(migratedAim,legacyAim).replace(motionFrames,'')).digest('hex'),
    'd97b7f1b44cb4c4655f9ae06ec429f88f40bfd322ddb1aa8ab30e4c2d08b9678');
}
const readWrappers=()=>Object.fromEntries(slices.map(([file])=>[file,read('tests/fixtures/js-owned/tests/lua/'+file)]));

test('frozen battle UI metadata preserves all 53 case bodies and six playback seeds across seven original-budget slices',()=>{
  const restored=restoreSupport(read(support));
  validateLegacyBody(restored);
  validatePartitions(slices,readWrappers());
  const discovered=readdirSync('tests/fixtures/js-owned/tests/lua').filter(file=>/^battle_ui(?:_slice_\d+)?\.lua$/.test(file)).sort();
  assert.deepEqual(discovered,slices.map(([file])=>file).sort(),'raw discovery includes exactly the seven original-budget entries');
  validateRunner(read('scripts/test-lua.mjs'));
});

test('battle UI seed-slice guards reject skipped/overlapping seeds, lost recursive assertions, missing markers and inert wrappers',()=>{
  const source=read(support);
  const assertion='assert(a == b, path)';
  const lost=source.replace(assertion,'assert(true)');
  assert.notEqual(lost,source,'negative control removes a real recursive rule/RNG assertion');
  assert.throws(()=>restoreSupport(lost),/original support byte count|original recursive assertions/);
  assert.throws(()=>restoreSupport(source.replace(seedMarker,'')),/completion marker/);
  const earlyMarker=source.replace(seedMarker,'').replace(slicedLoop,slicedLoop+seedMarker);
  assert.throws(()=>restoreSupport(earlyMarker),/completion marker follows/);
  const skipped=slices.map(row=>[...row]);skipped[2][3]=2;
  const overlap=slices.map(row=>[...row]);overlap[3][3]=3;
  assert.throws(()=>validatePartitions(skipped,readWrappers()),/reviewed case and seed ranges/);
  assert.throws(()=>validatePartitions(overlap,readWrappers()),/reviewed case and seed ranges/);
  assert.throws(()=>validateUniverse([...sequence(1,34),...sequence(34,53)],[1,2,4,5,6]),/six original playback seeds/);
  assert.throws(()=>validateUniverse([...sequence(1,34),...sequence(34,53)],[1,2,3,3,4,5,6]),/six original playback seeds/);
  const inert=readWrappers();inert['battle_ui_slice_6.lua']='-- '+inert['battle_ui_slice_6.lua'];
  assert.throws(()=>validatePartitions(slices,inert),/executable original-budget wrapper/);
  const blocked=readWrappers();blocked['battle_ui_slice_6.lua']='--[[\n'+blocked['battle_ui_slice_6.lua']+']]\n';
  assert.throws(()=>validatePartitions(slices,blocked),/block-commented executable wrapper/);
  const longer=read('scripts/test-lua.mjs').replace('60000 : 30000','120000 : 30000');
  assert.notEqual(longer,read('scripts/test-lua.mjs'),'negative control raises the actual battle fixture deadline');
  assert.throws(()=>validateRunner(longer),/unchanged runner and original deadlines/);
});

test('the frozen battle UI cases execute across seven slices with all six playback seeds exactly once',()=>{
  const seen=[],seeds=[];
  for(const [file,first,last,seedFirst=1,seedLast=6] of slices){
    const result=runLua('tests/fixtures/js-owned/tests/lua/'+file);
    assert.equal(result.status,0,result.stdout+result.stderr);
    const indices=[...result.stdout.matchAll(/^ok UI (\d+) - /gm)].map(row=>Number(row[1]));
    assert.deepEqual(indices,sequence(first,last));
    const markers=[...result.stdout.matchAll(/^UI_PLAYBACK_SEED (\d+)$/gm)].map(row=>Number(row[1]));
    assert.deepEqual(markers,first<=34&&last>=34?sequence(seedFirst,seedLast):[],'each entry completes only its assigned playback seeds');
    seen.push(...indices);seeds.push(...markers);
  }
  validateUniverse(seen,seeds);
});
