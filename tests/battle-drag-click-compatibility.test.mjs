import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua,shardLuaScripts} from '../scripts/test-lua.mjs';
import {discoverJs,jsShard,timings} from '../scripts/ci-shards.mjs';
import {p0Presentation,preAcceptedPresentation,preCardDragClickSource} from './helpers/p0-presentation-inverse.mjs';
import {acceptedPresentationSource} from './helpers/presentation-m3-integration.mjs';
import {preRetirementSource} from './helpers/presentation-announcement-retirement.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
import {preBattleRefactorSource} from './helpers/battle-refactor-projection.mjs';
import {task76BattleModuleLayer} from './helpers/task76-drag-click-inverse.mjs';
const path='src/lua/abyss_battle_ui.lua';
const source=readFileSync(path,'utf8').replaceAll('\r\n','\n');
const hash=value=>createHash('sha256').update(value).digest('hex');

const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const entry='tests/lua/battle_ui_drag_click_compatibility.lua';
const slices=[{path:entry,first:1,last:7},{path:'tests/lua/battle_ui_drag_click_compatibility_slice_2.lua',first:8,last:15}];
const prefix="local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 7\nlocal sliceRegistered,sliceExecuted=0,0\n";
const before="local test, finish = dofile('tests/lua/support/battle_action_fixture.lua').suite('LUA_DRAG_CLICK_COMPATIBILITY')\n";
const after="local originalTest, finish = dofile('tests/lua/support/battle_action_fixture.lua').suite('LUA_DRAG_CLICK_COMPATIBILITY')\nlocal function test(name,fn)\n    sliceRegistered=sliceRegistered+1\n    if sliceRegistered>=sliceFirst and sliceRegistered<=sliceLast then\n        originalTest(name,fn);sliceExecuted=sliceExecuted+1\n        print(\"DRAG_CLICK_COMPATIBILITY_CASE \"..sliceRegistered)\n    end\nend\n";
const footer="\nassert(sliceRegistered==15,\"all 15 original cases must register\")\nassert(sliceExecuted==sliceLast-sliceFirst+1,\"every selected original case must execute\")\nprint(\"DRAG_CLICK_COMPATIBILITY_SLICE \"..sliceFirst..\" \"..sliceLast..\" \"..sliceExecuted)\n";
function originalDragClickSource(value){
  assert.equal(hash(value),'90e9f3a97ebb1be55ca2f8e37239bf996a9bf93fca97f21f47abad5eb3756978','only the exact reviewed bounded registrar and original cases are accepted');
  assert.ok(value.startsWith(prefix));assert.ok(value.endsWith(footer));
  value=value.slice(prefix.length,-footer.length);
  assert.equal(value.split(after).length,2,'one exact original registrar');
  value=value.replace(after,before);
  assert.equal(hash(value),'5068b6d65349a5c8d4a20ffa2cae05a83a9edb224dd9880e9497f25bc7717fcf','all original setup, cases, assertions, seeds and statement order survive');
  const bytes=Buffer.from(value);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),'b3af07866d92841699bd3ee436a9506e0884a620');
  return value;
}
for(const slice of slices){
  test(`real drag release preserves independent Click-only actions and original card ownership, cases ${slice.first}–${slice.last}`,t=>{
    const started=Date.now(),result=runLua(slice.path,{timeout:30000});
    assert.equal(result.status,0,result.stdout+result.stderr);
    const expected=Array.from({length:slice.last-slice.first+1},(_,i)=>slice.first+i);
    assert.match(result.stdout,new RegExp(`LUA_DRAG_CLICK_COMPATIBILITY ${expected.length} passed; 0 failed`));
    assert.equal([...result.stdout.matchAll(/^PASS /gm)].length,expected.length);
    assert.deepEqual([...result.stdout.matchAll(/^DRAG_CLICK_COMPATIBILITY_CASE (\d+)$/gm)].map(match=>Number(match[1])),expected);
    assert.match(result.stdout,new RegExp(`DRAG_CLICK_COMPATIBILITY_SLICE ${slice.first} ${slice.last} ${expected.length}`));
    t.diagnostic(`Lua fixture ${slice.path}: ${Date.now()-started} ms; original cases ${expected.join(',')}`);
    t.diagnostic(result.stdout.split('\n').filter(line=>line.startsWith('PASS ')||line.startsWith('LUA_DRAG_CLICK_COMPATIBILITY ')).join('\n'));
  });
}
test('bounded drag registrar preserves every original byte and rejects case, range or execution drift',()=>{
  const bounded=read(entry),original=originalDragClickSource(bounded);
  assert.equal(read(slices[1].path),`assert(loadfile("${entry}"))(8,15)\n`);
  assert.deepEqual(slices.flatMap(({first,last})=>Array.from({length:last-first+1},(_,i)=>first+i)),Array.from({length:15},(_,i)=>i+1));
  const mutants=[bounded.replace(prefix,''),bounded.replace('sliceLast or 7','sliceLast or 8'),
    bounded.replace(after,after.replace('originalTest(name,fn);','')),bounded.replace(after,after+after),
    bounded.replace(footer,''),bounded+footer,
    bounded.replace('assert(b.energy==2','assert(b.energy ==2')];
  for(const mutant of mutants){assert.notEqual(mutant,bounded);assert.throws(()=>originalDragClickSource(mutant),/exact reviewed/);}
  assert.ok(original.endsWith('finish()\n'));
  assert.equal(hash(read('scripts/test-lua.mjs')),'7866bfbb9888417087a669dd20f524de32ccb1efe1d035a283fc1b148d26ed33','all original runner deadlines and worker limits remain unchanged');
});
test('raw and Node discovery retain both drag slices exactly once in every hosted scheduling plan',()=>{
  const raw=readdirSync('tests/lua').filter(name=>name.endsWith('.lua')).map(name=>'tests/lua/'+name);
  const expected=slices.map(slice=>slice.path);
  const verifyFamily=files=>assert.deepEqual(files.filter(path=>path.startsWith('tests/lua/battle_ui_drag_click_compatibility')&&path.endsWith('.lua')).sort(),[...expected].sort());
  verifyFamily(raw);
  for(const missing of expected)
    assert.throws(()=>verifyFamily(raw.filter(path=>path!==missing)),'missing raw family entry must fail');
  for(const extra of [
    'tests/lua/battle_ui_drag_click_compatibility_slice_3.lua',
    'tests/lua/battle_ui_drag_click_compatibility_noncanonical_disabled.lua',
    'tests/lua/battle_ui_drag_click_compatibility_slice_wrong.lua',
  ])
    assert.throws(()=>verifyFamily([...raw,extra]),'extra canonical or noncanonical family entry must fail');
  assert.throws(()=>verifyFamily([...raw,expected[0]]),'duplicate raw family entry must fail');
  assert.throws(()=>verifyFamily(raw.map(path=>path===expected[1]?'tests/lua/battle_ui_drag_click_compatibility_slice_99.lua':path)),
    'a wrong replacement slice cannot stand in for the accepted raw entry');
  for(const workers of [1,2]){
    const actual=Array.from({length:8},(_,i)=>shardLuaScripts(raw,`${i+1}/8`,timings,workers)).flat().filter(path=>expected.includes(path));
    assert.deepEqual(actual.sort(),[...expected].sort(),`all raw shards retain each drag slice exactly once with ${workers} worker(s)`);
  }
  const contract='tests/battle-drag-click-compatibility.test.mjs',js=discoverJs();
  assert.equal(js.filter(path=>path===contract).length,1);
  for(const [platform,count]of [['win32',8],['linux',4]]){
    const actual=Array.from({length:count},(_,i)=>jsShard(js,`${i+1}/${count}`,platform).files).flat();
    assert.equal(actual.filter(path=>path===contract).length,1,`${platform} executes the complete drag regression once`);
  }
});

test('drag-only historical inverse preserves complete old identities and rejects other drift',()=>{
  const original=preCardDragClickSource(path,source);
  assert.equal(hash(source),task76BattleModuleLayer.files[path].afterSha256);
  assert.equal(hash(original),task76BattleModuleLayer.files[path].beforeSha256);
  assert.equal(hash(preBattleRefactorSource(path,source)),'a1d68a1fcba74fff54fb22cb4641cd400e4c76e2d3a7e22d69e352efeb8e7d91');
  assert.equal(hash(preApprovedUiSource(path,original)),p0Presentation.files[path].afterSha256);
  assert.equal(preApprovedUiSource(path,source),preApprovedUiSource(path,original));
  assert.equal(preCardDragClickSource(path,source.replaceAll('\n','\r\n')),original);
  assert.equal(preCardDragClickSource(path,original),original);
  assert.equal(hash(preAcceptedPresentation(path,preApprovedUiSource(path,source))),p0Presentation.files[path].beforeSha256);
  assert.equal(preRetirementSource(path,source),preRetirementSource(path,original));
  const popupPath='src/lua/abyss_battle_potion_popup.lua';
  const popup=readFileSync(popupPath,'utf8').replaceAll('\r\n','\n');
  assert.equal(hash(popup),'c530888e8afe4c98120fa51b459b1724c7be93fa76f48334ac368031806e08bd');
  assert.equal(hash(preCardDragClickSource(popupPath,popup)),'d50f03654abd678719f610bce920f67c5b7bc45656103231fae04f3c3761ceba');
  assert.equal(preApprovedUiSource(popupPath,popup),null,'only the complete approved added popup disappears in historical replay');
  for(const mutant of [popup+'\n-- drift\n',
    popup.replace('            if actions.pointerClick and not actions.pointerClick(event)then return false end\n',''),
    popup.replace('                    if actions.pointerDown then actions.pointerDown(event)end\n','')]){
    assert.notEqual(mutant,popup);
    assert.throws(()=>preApprovedUiSource(popupPath,mutant),/unreviewed integrated/);
  }
  const fixturePath='tests/lua/support/battle_ui_cases.lua';
  const fixture=readFileSync(fixturePath,'utf8').replaceAll('\r\n','\n');
  assert.equal(hash(fixture),'6adf9566320c60e8b68fb8854ccbf9dffb0eb34f7510d5a32309d4a3461d7590');
  const originalFixture=preCardDragClickSource(fixturePath,fixture);
  assert.equal(hash(originalFixture),'874ad3cf102493953104fe3d556e6839b5599a249d37679b5a2fad862517375d');
  assert.equal(preApprovedUiSource(fixturePath,fixture),preApprovedUiSource(fixturePath,originalFixture));
  const namedGhost='    event("enemy1","click",stage.children.enemy1.x,stage.children.enemy1.y,0) -- queued same-origin release click\n';
  for(const mutant of [fixture+'\n-- drift\n',fixture.replace(namedGhost,''),fixture.replace(namedGhost,namedGhost+namedGhost)]){
    assert.notEqual(mutant,fixture);
    assert.throws(()=>preApprovedUiSource(fixturePath,mutant),/unreviewed integrated/);
  }
  // The same semantic mutations now target their real PR311 owners. The
  // complete composition guard still rejects every missing/unknown/partial module.
  const gesturePath='src/lua/abyss_battle_card_gestures.lua';
  const inputPath='src/lua/abyss_battle_input_state.lua';
  const potionBindingPath='src/lua/abyss_battle_potion_bindings.lua';
  const gesture=read(gesturePath),input=read(inputPath),potionBinding=read(potionBindingPath);
  const token="        owner.suppressClick,owner.selected = g,action ~= 'cancel' and g.uid or nil\n";
  const mutants=[
    [path,source+'\n-- unrelated drift\n'],
    [gesturePath,gesture.replace(token,token+token)],
    [gesturePath,gesture.replace(token,token.replace(' = g,',' = true,'))],
    [inputPath,input.replace('        owner.suppressClick = nil\n','')],
    [inputPath,input.replace('        if touch ~= nil and touch == ownership.releasedDragTouch then return true end\n','')],
    [potionBindingPath,potionBinding.replace('then return owner:openPotionMenu(slot) end','then return owner:usePotion(slot) end')],
  ];
  for(const [file,mutant]of mutants){
    assert.notEqual(mutant,read(file));
    assert.throws(()=>preBattleRefactorSource(path,file===path?mutant:source,{[file]:mutant}),/unreviewed integrated/);
    if(file===path){
      assert.throws(()=>preAcceptedPresentation(path,preApprovedUiSource(path,mutant)),/unreviewed integrated/);
      assert.throws(()=>preApprovedUiSource(path,mutant),/unreviewed integrated/);
      assert.throws(()=>acceptedPresentationSource(path,mutant),/unreviewed integrated/);
    }
  }
});

test('every ported Battle responsibility restores accepted PR311 bytes and rejects drift before historical replay',()=>{
  assert.equal(task76BattleModuleLayer.base,'8a36c0d59781302944feb03c4ce9a2f304c62ac8');
  assert.equal(task76BattleModuleLayer.reviewedMonolithSha256,'067b6761d5f02477ec2aeb848b2a00eb2b4191517d30096f7cb8dc84e3f0b382');
  assert.equal(Object.keys(task76BattleModuleLayer.files).length,6);
  const baseline=preBattleRefactorSource(path,source);
  for(const [file,binding]of Object.entries(task76BattleModuleLayer.files)){
    const current=read(file),before=preCardDragClickSource(file,current);
    assert.equal(hash(current),binding.afterSha256,'complete ported source: '+file);
    assert.equal(hash(before),binding.beforeSha256,'complete accepted PR311 source: '+file);
    assert.equal(preCardDragClickSource(file,current.replaceAll('\n','\r\n')),before);
    assert.equal(preCardDragClickSource(file,before),before);
    assert.equal(preCardDragClickSource('unrelated.lua',current),current,'a different path cannot borrow the port inverse');
    const foreign=read(file===path?'src/lua/abyss_battle_input_state.lua':path);
    assert.throws(()=>preBattleRefactorSource(path,source,{[file]:foreign}),'another complete known module cannot substitute for this owner');
    assert.equal(preBattleRefactorSource(path,source,{[file]:before}),baseline);
    for(const mutant of [null,current+'\n-- unknown module drift\n',current.slice(1)])
      assert.throws(()=>preBattleRefactorSource(path,source,{[file]:mutant}));
    for(const hunk of binding.hunks){
      // Remove/duplicate every known addition, not just one convenient guard.
      if(!hunk.after.length)continue;
      const lines=current.split('\n');
      for(const replacement of [hunk.before,[...hunk.after,...hunk.after]]){
        const mutated=[...lines];mutated.splice(hunk.at,hunk.after.length,...replacement);
        const mutant=mutated.join('\n');assert.notEqual(mutant,current);
        if(hash(mutant)===binding.beforeSha256)
          assert.equal(preBattleRefactorSource(path,source,{[file]:mutant}),baseline,'the complete accepted pre-port module remains a legal historical witness');
        else assert.throws(()=>preBattleRefactorSource(path,source,{[file]:mutant}));
      }
    }
  }
});


test('complete Battle composition rejects missing or unknown unchanged responsibilities before projection',()=>{
  const layer=JSON.parse(read('tests/fixtures/battle-ui-approved-responsibility-layer.json'));
  assert.equal(Object.keys(layer.modules).length,16,'accepted coordinator and all fifteen owners stay bound');
  for(const file of Object.keys(layer.modules))
    for(const mutant of [null,read(file)+'\n-- unknown responsibility drift\n'])
      assert.throws(()=>preBattleRefactorSource(path,source,{[file]:mutant}));
});
