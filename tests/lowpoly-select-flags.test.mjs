import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createRequire} from 'node:module';
import {writePortraitModule} from '../scripts/official-portraits.mjs';
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=createRequire(import.meta.url)('fengari');
const off={selectionAvatar:false,battlePortrait:false,cards:false};
const moduleFor=flags=>{const dir=mkdtempSync(join(tmpdir(),'lowpoly-'));try{return writePortraitModule(dir,{...off,...flags});}finally{rmSync(dir,{recursive:true,force:true});}};
test('flags off emit no low-poly data; each flag emits only the asset it owns',()=>{
 assert.equal(moduleFor({}),'-- Disabled optional drawings.\nreturn {imagePrefabId=0,containerPrefabId=0}\n');
 const hero=moduleFor({selectionAvatar:true}),fan=moduleFor({cards:true}),battle=moduleFor({battlePortrait:true});
 assert.match(hero,/lowpolyHero=/);assert.doesNotMatch(hero,/lowpolyCardFan=/);
 assert.match(fan,/lowpolyCardFan=/);assert.doesNotMatch(fan,/lowpolyHero=|avatar96=|battle133=/);
 assert.doesNotMatch(battle,/lowpoly/);
});
function run(assetSource,flags){
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
local owner=M.new(stage,nil,${flags},{imageTemplateIndex=11,containerTemplateIndex=22})
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
