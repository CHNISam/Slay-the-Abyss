import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {prepareMonsterArt,attachMonsterArt,monsterActorTemplate} from '../scripts/monster-art.mjs';
import {nativeArtPool} from '../scripts/card-art-samples.mjs';
import {battleLayout} from '../scripts/ui-layout.mjs';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {buildUI,assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
import {monsterEnabledLua,fullMonsterArtFixture} from './helpers/monster-enabled-ui.mjs';
import {runLua as rawRunLua} from '../scripts/test-lua.mjs';
const runFullCatalogLua=monsterEnabledLua({fullCatalog:true});
const monsterBuild=mkdtempSync(join(tmpdir(),'abyss-monster-only-'));
buildUI(monsterBuild,undefined,{artFeatures:{monsters:true}});
after(()=>rmSync(monsterBuild,{recursive:true,force:true}));
let wrapperIndex=0;
function runLua(script){
 const wrapper=join(monsterBuild,`case-${wrapperIndex++}.lua`);
 writeFileSync(wrapper,`package.path=${toLua(monsterBuild+'/?.lua;')}..package.path\ndofile(${toLua(script)})\n`);
 return rawRunLua(wrapper);
}
const slot={image:100002,imageType:'basic',position:[1,2],size:[8,7],pivot:[.5,.5],anchorMin:[.5,.5],anchorMax:[.5,.5],scale:[1,1],rotation:[12,-30,40],colour:[120,180,90,128]};
const fixture=()=>({schemaVersion:1,enabled:true,canvas:[106,106],asset:{enemyId:'acid_slime_m',luaSha256:'a'.repeat(64),jsonSha256:'b'.repeat(64),slots:Array.from({length:597},()=>structuredClone(slot))}});
function all(tree){return [tree,...(tree.controls??tree.children??[]).flatMap(all)];}
test('native primitive template leaves real battle/game scene geometry unchanged',()=>{
 for(const factory of [battleLayout,gameLayout]) {
  const tree=factory(),before=structuredClone(tree),art=prepareMonsterArt(fixture());
  attachMonsterArt(tree,art);assertNativeUiCapacity(tree);assert.deepEqual(tree,before);
  const actor=monsterActorTemplate(art);assertNativeUiCapacity(actor);
  const host=actor.children[0];assert.equal(host.name,'monsterArt');assert.equal(all(host).length,609);
  assert.equal(host.visible,false);assert.equal(actor.visible,false);
  for(const name of ['impact','shield','floating','hp','intentIcon','hit'])
   assert(actor.children.findIndex(c=>c.name===name)>0,'original '+name+' must remain above native portrait');
 }
});
test('production enables only labelled test prototype; malformed/count/unbounded primitive data rejected',()=>{
 const production=prepareMonsterArt();assert.equal(production.status,'test-prototype');assert.equal(production.approval.nativeFinalApproved,false);assert.equal(production.asset.capacity,600);assert.equal(production.asset.slots.length,597);assert.equal(production.surfaceAllocation,'per-drawable-actor-instance');
 assert.equal(prepareMonsterArt({schemaVersion:1,enabled:false}),null);
 for(const change of [r=>r.asset.enemyId='cultist',r=>r.asset.slots.push(...Array(4).fill(slot)),r=>r.canvas=[0,106],r=>r.asset.slots[0].image='source.png',r=>r.asset.slots[0].image=106056,r=>r.asset.slots[0].image=100004,r=>r.asset.slots[0].image=999999,r=>r.asset.slots[0].rotation=[0,NaN,0]]) {
  const registry=fixture();change(registry);assert.throws(()=>prepareMonsterArt(registry));
 }
});
test('native drawing any-slot binding, duplicates, dim/pose/death/rebind/reset and fail-closed fallback',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-monster-test-'));
 try {
  const data=prepareMonsterArt(fixture());data.asset.slots=data.asset.slots.slice(0,2);data.asset.capacity=2;
  const pool=nativeArtPool(2);pool.name='monsterSamples';pool.position=[0,0];
  const path=join(directory,'case.lua');
  writeFileSync(path,`
package.preload.abyss_monster_art_data=function()return {}end
local Art=require('abyss_monster_art')
local function control(node)
 local c={name=node.name,visible=node.visible~=false,children={},writes=0}
 for _,n in ipairs(node.children or {})do c.children[n.name]=control(n)end
 function c:GetChild(n)return assert(self.children[n],'missing '..n)end
 function c:SetVisible(v)self.visible=v end
 function c:SetImage(source,id)self.image=id;self.writes=self.writes+1 end
 function c:SetAnchorMin(...)self.anchorMin={...}end
 function c:SetAnchorMax(...)self.anchorMax={...}end
 function c:SetPivot(...)self.pivot={...}end
 function c:SetSizeDelta(...)self.size={...}end
 function c:SetLocalScale(...)self.scale={...}end
 function c:SetLocalRotation(...)self.rotation={...};return self.reject~=true end
 function c:SetAnchoredPosition(...)self.position={...}end
 return c
end
local stage=control({name='stage',children={{name='topBar',children={{name='monsterArt',children={${toLua(pool)}}}}},
 {name='enemy1',children={{name='portrait'}}},{name='enemy2',children={{name='portrait'}}},{name='enemy3',children={{name='portrait'}}}}})
local platform={imageSource=1,imageTypes={basic=1,stretch=2},color=function(...)return {...}end}
local view=Art.new(stage,platform,${toLua(data)})
local function row(id,kind)return {id=id,actor={definitionId=kind}}end
local rows={row('other','cultist'),row('acid-a','acid_slime_m'),row('acid-b','acid_slime_m')}
local a,b=stage:GetChild('enemy2'),stage:GetChild('enemy3')
local root=stage:GetChild('topBar'):GetChild('monsterArt');local tone={r=255,g=255,b=255,a=255}
view:select(rows);assert(not view:write(stage:GetChild('enemy1'),0,0,106,tone))
assert(view:write(a,300,20,106,tone));assert(not a:GetChild('portrait').visible);assert(b:GetChild('portrait').visible)
assert(not view:write(b,500,20,106,tone));assert(root.visible)
local shape=root:GetChild('monsterSamples'):GetChild('group000'):GetChild('shape0000')
assert(shape.image==100002 and shape.rotation[1]==12 and shape.rotation[2]==-30 and shape.rotation[3]==40)
Art.pose(a,5,-2,1.1,.9,{r=255,g=128,b=255,a=102},.5)
assert(root.position[1]==305 and root.position[2]==18 and root.scale[1]==1.1 and root.scale[2]==.9)
assert(shape.imageColor[1]==120 and shape.imageColor[2]==90 and shape.imageColor[4]==25)
Art.pose(a,0,0,1,1,tone,0);assert(not root.visible,'finished death must hide pool')
view:select({row('other','cultist'),row('other2','cultist'),row('acid-b','acid_slime_m')})
assert(a:GetChild('portrait').visible);assert(view:write(b,450,10,127,tone));assert(root:GetChild('monsterSamples').scale[1]==127/106)
Art.pose(a,99,99,2,2,tone,1);assert(root.position[1]==450,'old slot must not move rebound drawing')
Art.clearBox(b);assert(not root.visible and b:GetChild('portrait').visible)
view:select(rows);assert(view:write(a,1,2,106,tone));view:select({});assert(not root.visible and a:GetChild('portrait').visible)
view:select(rows);shape.reject=true;assert(not view:write(a,0,0,106,tone));assert(a:GetChild('portrait').visible and not root.visible)
local writes=shape.writes;assert(not view:write(a,0,0,106,tone));assert(shape.writes==writes,'failed metadata must not retry writes each frame')
view:clear();shape.reject=false;view:select(rows);assert(view:write(a,1,2,106,tone));view:clear()
print('native monster lifecycle passed')
`);
  const result=runLua(path);assert.equal(result.status,0,result.stderr);assert.match(result.stdout,/native monster lifecycle passed/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
test('actual r02 exported literal equals every primitive API write; tiny XYZ mutation is rejected',()=>{
 const folder=mkdtempSync(join(tmpdir(),'abyss-monster-source-'));
 try {
  const metadata=prepareMonsterArt().asset;
  const source=readFileSync('art/monsters/acid_slime_m/native-art-r02/native-art.lua','utf8');
  const path=join(folder,'source.lua');
  const body=()=>`ABYSS_EXPECTED_GALLERY_COUNT=0\nABYSS_EXPORTED_ART=${toLua(source)}\nABYSS_NATIVE_POOL=${toLua(nativeArtPool(metadata.capacity))}\nABYSS_METADATA=${toLua(metadata)}\ndofile('tests/lua/support/native_card_art_source_equivalence.lua')\n`;
  writeFileSync(path,body());let result=runLua(path);assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/shapes=597/);
  metadata.slots[21].rotation[0]+=.125;writeFileSync(path,body());result=runLua(path);assert.notEqual(result.status,0);assert.match(result.stderr,/native source mismatch rotation/);
 }finally{rmSync(folder,{recursive:true,force:true});}
});
test('explicit monster-only generated GameUI binds actual new r02 into real combat and feedback lifecycle',()=>{
 const result=runFullCatalogLua('tests/lua/support/native_monster_art_host.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/NATIVE_MONSTER_HOST_PASS/);
});
test('real host regression rejects missing reset cleanup instead of accepting visible ghosts',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-monster-mutation-'));
 try {
  const path=join(directory,'mutant.lua');
  writeFileSync(path,"require('abyss_monster_art').clearBox=function()end\ndofile('tests/lua/support/native_monster_art_host.lua')\n");
  const result=runFullCatalogLua(path);assert.notEqual(result.status,0);assert.match(result.stderr,/explicit reset must clear the pool/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('real native entry draws grass with monsters ON and other four categories OFF without activating their assets',()=>{
 const result=runLua('tests/lua/support/native_monster_only_entry.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_MONSTER_ONLY_ENTRY_PASS/);
});

test('explicit four-category ON build retains the same actual grass drawing lifecycle',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-monster-all-on-'));
 try {
  buildUI(directory,undefined,{artFeatures:{cards:true,menuBackground:true,selectionAvatar:true,battlePortrait:true,monsters:true},monsterArt:fullMonsterArtFixture()});
  const path=join(directory,'host.lua');
  writeFileSync(path,`package.path=${toLua(directory+'/?.lua;')}..package.path
dofile('tests/lua/support/native_monster_art_host.lua')
`);
  const result=runLua(path);assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_MONSTER_HOST_PASS/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});

test('new grass drawing preserves merged Runic Dome intent suppression in the actual host',()=>{
 const result=runLua('tests/lua/support/native_monster_relic_dome.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/NATIVE_MONSTER_RELIC_DOME_PASS/);
});

test('default production whitelist falls back for unselected definitions and clears same-id prior art',()=>{
 const result=runLua('tests/lua/support/monster_candidate_fallback.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);assert.match(result.stdout,/MONSTER_CANDIDATE_FALLBACK_PASS/);
});
