import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createRequire} from 'node:module';
import {writePortraitModule,bindPortraitTemplates,portraitRuntimeInventory,portraitModule} from '../scripts/official-portraits.mjs';
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=createRequire(import.meta.url)('fengari');
const off={selectionAvatar:false,battlePortrait:false,cards:false};
const moduleFor=flags=>{const dir=mkdtempSync(join(tmpdir(),'lowpoly-'));try{return writePortraitModule(dir,{...off,...flags});}finally{rmSync(dir,{recursive:true,force:true});}};
test('flags off emit no low-poly data; each flag emits only the asset it owns',()=>{
 assert.equal(moduleFor({}),'-- Disabled optional drawings.\nreturn {imagePrefabId=0,containerPrefabId=0}\n');
 const hero=moduleFor({selectionAvatar:true}),fan=moduleFor({cards:true}),battle=moduleFor({battlePortrait:true});
 assert.match(hero,/lowpolyHero=/);assert.doesNotMatch(hero,/lowpolyCardFan=/);
 assert.match(fan,/lowpolyCardFan=/);assert.doesNotMatch(fan,/lowpolyHero=|avatar96=|battle133=/);
 assert.doesNotMatch(battle,/lowpoly/);
 const land=moduleFor({menuBackground:true});assert.match(land,/lowpolyLand=/);assert.doesNotMatch(land,/lowpolyHero=|lowpolyCardFan=/);
});
function run(assetSource,flags,readyTemplates='{imageTemplateIndex=11,containerTemplateIndex=22}'){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const portraits=readFileSync('src/lua/abyss_traveler_portraits.lua','utf8');
 const code=`
local created,rot3d,loads=0,0,0
local function control(name)
 local c={alive=true,visible=true,sizeDeltaX=200,children={},name=name}
 for _,m in ipairs({'SetAnchorMin','SetAnchorMax','SetPivot','SetSizeDelta','SetLocalScale','SetAnchoredPosition','SetImage','SetAsLastSibling','SetActive'})do c[m]=function()return true end end
 function c.SetVisible(self,v)self.visible=v;return true end
 function c.SetLocalRotation(_,x,y)if x~=0 or y~=0 then rot3d=rot3d+1 end;return true end
 function c.GetChild(self,k)self.children[k]=self.children[k] or control(k);return self.children[k]end
 return c
end
Enum={ImageSource={StaticReference=1},ImageType={Stretch=1}};Color={FromRGBA=function()return 0 end}
game={InstantiateClientUIControl=function(id,parent)assert(id==11 or id==22,'bound template required');created=created+1;return control('dyn')end,DestroyClientUIControl=function()return true end}
package.preload.abyss_traveler_portrait_assets=function()loads=loads+1;return (function() ${assetSource} end)()end
local M=(function() ${portraits} end)()
local stage=control('stage')
local owner=M.new(stage,nil,${flags},${readyTemplates})
if not owner then return 'nil|'..loads..'|'..created end
owner:sync('menu',true,false,'ironclad')
for _=1,400 do owner:tick()end
return 'owner|'..loads..'|'..created..'|'..rot3d..'|'..owner:status().batchSize`;
 const fail=()=>{throw Error(to_jsstring(lua.lua_tostring(L,-1)));};
 if(lauxlib.luaL_loadstring(L,to_luastring(code))!==0)fail();
 if(lua.lua_pcall(L,0,1,0)!==0)fail();
 return to_jsstring(lua.lua_tostring(L,-1));
}
test('all art flags off: owner is never created and no asset module is loaded',()=>{
 assert.equal(run('return {}','{cards=false,selectionAvatar=false,battlePortrait=false}'),'nil|0|0');
});
test('cards flag builds the premium low-poly card fan with squashed triangles from ready-card templates',()=>{
 const [kind,loads,created,rot]=run(moduleFor({cards:true}),'{cards=true,selectionAvatar=false,battlePortrait=false}').split('|');
 assert.equal(kind,'owner');assert.equal(loads,'1');
 assert.ok(Number(created)>1585,'every frame + illustration row becomes a native control');
 assert.ok(Number(rot)>1000,'triangles use rotX/rotY squash');
});
test('pure UI palette preserves rarity and dark art wells with premium highlights and explicit legacy reset',()=>{
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const code=`package.path='build/lua/?.lua;src/lua/?.lua;'..package.path
local Skin=require('abyss_card_skin');local Theme=require('abyss_theme')
local function node()local c={children={}};function c.GetChild(self,k)self.children[k]=self.children[k] or node();return self.children[k]end
 function c.SetVisible(self,v)self.visible=v end;function c.SetLocalScale()end;function c.SetSizeDelta()end;function c.SetAnchoredPosition()end;return c end
local function rgb(c)return c.r..','..c.g..','..c.b end
local platform={color=function(r,g,b)return r..','..g..','..b end}
local face=node()
assert(rgb(Theme.cardSkin.premium.selected)~=rgb(Theme.color.goldBright),'fixture must distinguish premium and legacy highlights')
for _,rarity in ipairs({'basic','common','uncommon','rare','curse'})do
 local def={id='x',type='attack',rarity=rarity,cost=1}
 local palette=Theme.cardSkin.rarities[rarity]
 -- Recycle the same face through explicit legacy -> premium -> legacy, not fresh controls.
 for _,mode in ipairs({'legacy','premium','legacy'})do
  Skin.configure(mode=='premium' and mode or nil)
  assert(Skin.premium()==(mode=='premium'),'palette mode did not reset')
  for _,selected in ipairs({false,true,false})do
   Skin.apply(face,def,platform,{cost=1,baseCost=1,selected=selected})
   local edge=selected and (mode=='premium' and Theme.cardSkin.premium.selected or Theme.color.goldBright) or palette[1]
   assert(face:GetChild('border').imageColor==rgb(edge),'border lost rarity or selection highlight')
   assert(face:GetChild('roundFrame'):GetChild('vertical').imageColor==rgb(edge),'visible frame lost rarity or selection highlight')
   assert(face:GetChild('nameRule').imageColor==rgb(palette[4]),'title rule lost rarity')
   assert(face:GetChild('skin'):GetChild('band1').imageColor==rgb(palette[2]),'title band lost rarity')
   assert(face:GetChild('costDisc').imageColor==rgb(Theme.cardSkin.roles.traveler.accent),'traveler cost chrome lost')
   assert(face:GetChild('roleMark'):GetChild('traveler').visible,'traveler emblem lost')
   local well=face:GetChild('skin'):GetChild('attack'):GetChild('well'):GetChild('upper').imageColor
   local r,g,b=well:match('(%d+),(%d+),(%d+)')
   assert(tonumber(r)<100 and tonumber(g)<100 and tonumber(b)<100,'official icon dark well lost')
  end
 end
end
return 'RARITY_PREMIUM_LEGACY_RESET_PASS'`;
 if(lauxlib.luaL_loadstring(L,to_luastring(code))!==0||lua.lua_pcall(L,0,1,0)!==0)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
 assert.equal(to_jsstring(lua.lua_tostring(L,-1)),'RARITY_PREMIUM_LEGACY_RESET_PASS');
});

test('menuBackground fills the bottom-most select/combat scene slots with the low-poly land',()=>{
 const [kind,,created,rot]=run(moduleFor({menuBackground:true}),'{menuBackground=true}').split('|');
 assert.equal(kind,'owner');assert.ok(Number(created)>=362,'select scene land built');assert.ok(Number(rot)>100);
});

test('menu-only bound module creates scenes without unrelated ready-card templates',()=>{
 const dir=mkdtempSync(join(tmpdir(),'lowpoly-bound-'));
 try {
  const source=bindPortraitTemplates(dir,{image:{templateIndex:11},container:{templateIndex:22}},{...off,menuBackground:true});
  const [kind,,created]=run(source,'{menuBackground=true,cards=false,selectionAvatar=false,battlePortrait=false}','nil').split('|');
  assert.equal(kind,'owner');assert.ok(Number(created)>=362,'bound portrait templates instantiate the menu-only land');
 }finally{rmSync(dir,{recursive:true,force:true});}
});

test('runtime inventory counts every cached scene and fan host, and refuses mismatched literal rows',()=>{
 const dir=mkdtempSync(join(tmpdir(),'lowpoly-inventory-'));
 try {
  writePortraitModule(dir,{...off,cards:true});
  assert.equal(portraitRuntimeInventory(dir).peakDynamicControls,1614,'fan images, groups, page and its dynamic host');
  writePortraitModule(dir,{...off,selectionAvatar:true});
  const hero=portraitRuntimeInventory(dir);
  assert.equal(hero.selectionUses,'lowpolyHero');
  assert.equal(hero.assets.some(a=>a.asset.endsWith('/selection133')),false,'unused selection data is not instantiated');
  const source=writePortraitModule(dir,{...off,menuBackground:true});
  const land=portraitRuntimeInventory(dir);
  assert.equal(land.instances,3);assert.equal(land.peakDynamicControls,1110);
  assert.deepEqual(land.assets.map(a=>[a.asset,a.images,a.instances]),[['lowpolyLand',362,3]]);
  const broken=source.replace('["count"]=362','["count"]=363');assert.notEqual(broken,source);
  writeFileSync(join(dir,portraitModule+'.lua'),broken);
  assert.throws(()=>portraitRuntimeInventory(dir),/Invalid low-poly inventory count/);
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('layout attaches scene slots only with the flag, as first drawn children',async()=>{
 const {attachLowpolyScenes}=await import('../scripts/official-portraits.mjs');
 const tree=()=>({controls:[{name:'stage',children:[{name:'characterPanel',children:[{name:'veil'},{name:'border'},{name:'face'}]},{name:'battlePanel',children:[{name:'playArea'}]}]}]});
 const off=tree();attachLowpolyScenes(off,{menuBackground:false});assert.doesNotMatch(JSON.stringify(off),/lowpolyScene/);
 const on=tree();attachLowpolyScenes(on,{menuBackground:true});const [select,battle]=on.controls[0].children;
 assert.equal(battle.children[0].name,'lowpolyScene');assert.deepEqual(select.children.map(c=>c.name),['veil','lowpolyScene','border','face']);
});
