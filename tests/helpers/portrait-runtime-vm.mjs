import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createRequire} from 'node:module';
import {runInThisContext} from 'node:vm';
import {writePortraitModule} from '../../scripts/official-portraits.mjs';
import {toLua} from '../../scripts/build-lua-data.mjs';
import {nativeTheme} from '../../scripts/native-ui-theme.mjs';
const require=createRequire(import.meta.url),fengari=require('fengari');
const {lua,lauxlib,lualib,to_luastring}=fengari;
const fixtureBytes=readFileSync('tests/fixtures/image-editor-103025-checker.cjs');
assert.equal(createHash('sha1').update(Buffer.from(`blob ${fixtureBytes.length}\0`)).update(fixtureBytes).digest('hex'),'ced76db25cd9e386d9c2dd683ea8f0aeef1b35aa');
const fixture=fixtureBytes.toString('utf8'),start=fixture.indexOf('function vm(script) {'),end=fixture.indexOf('\nvm(source)(');
const exactVm=runInThisContext('(function(deps){const {assert,lua,lauxlib,lualib,to_luastring,to_jsstring,maskSlots,controlCount}=deps;'+fixture.slice(start,end)+';return vm;})')({...fengari,assert,maskSlots:[],controlCount:4822});
export function withPortraitVm(code,{before='',themePlayer={id:1,status:'native'},runtimeV2=false}={}) {
 const dir=mkdtempSync(join(tmpdir(),'portrait-vm-'));
 let state;const old=lauxlib.luaL_newstate;lauxlib.luaL_newstate=()=>state=old();
 try {
  if(runtimeV2)writeFileSync(join(dir,'art-render-v2.json'),JSON.stringify({profile:'native-v2',hiddenBuild:true,cache:true,revealGroupsPerFrame:4}));
  const asset=writePortraitModule(dir,{selectionAvatar:true,battlePortrait:true,imageTemplateIndex:1234,containerTemplateIndex:5678});
  const run=exactVm(`Asset=(function()\n${asset}\nend)()`);
  run(`
local instantiate=game.InstantiateClientUIControl
local watch={SetImage=true,imageType=true,SetAnchorMin=true,SetAnchorMax=true,SetPivot=true,SetSizeDelta=true,SetLocalScale=true,SetLocalRotation=true,SetAnchoredPosition=true,imageColor=true,SetAsLastSibling=true}
function watchControl(c)
 rawset(c,'trace',{})
 for name in pairs(watch)do if type(c[name])=='function'then
  local original=c[name];c[name]=function(self,...)self.trace[#self.trace+1]={name,...};return original(self,...)end
 end end
 local mt=getmetatable(c);local write=mt.__newindex
 mt.__newindex=function(self,key,value)if watch[key]then self.trace[#self.trace+1]={key,value}end;return write(self,key,value)end
 return c
end
game.InstantiateClientUIControl=function(id,parent)
 assert(id==1234 or id==5678,'real bound template index required')
 local old=script.object;script.object=parent;local c=instantiate(id,parent);script.object=old
 if c then watchControl(c);rawset(c,'isGroup',id==5678)end
 return c
end
function tree(children)
 local c=control('parent');rawset(c,'children',children or {});rawset(c,'GetChild',function(self,key)return self.children[key]end);return c
end
avatar=tree();figure=tree();fallback=control('image');fallback:SetVisible(true)
local states={}
for _,name in ipairs({'normal','hover','pressed','disabled'})do local bust=control('image');rawset(bust,'sizeDeltaX',32);bust:SetVisible(true);states[name]=tree({bust=bust})end
traveler=tree({officialAvatar=avatar,hit=tree(states)});hero=tree({officialFigure=figure,portrait=fallback})
stage=tree({characterPanel=tree({traveler=traveler}),battlePanel=tree({hero=hero})})
function LiveCount()local n=0;for _,c in ipairs(controls)do if c.alive then n=n+1 end end;return n end
function Images()local out={};for _,c in ipairs(controls)do if c.alive and not c.isGroup then out[#out+1]=c end end;return out end
function Equal(a,b)assert(type(a)==type(b),'type mismatch');if type(a)=='table'then assert(#a==#b,'length mismatch');for i,v in ipairs(a)do Equal(v,b[i])end else assert(a==b,tostring(a)..' ~= '..tostring(b))end end
`);
  if(before)run(before);
  run(`Theme=${toLua({...nativeTheme,icon:{...nativeTheme.icon,player:themePlayer}})}
PortraitAssetLoads=0;require=function(name)if name=='abyss_theme' then return Theme end;assert(name=='abyss_traveler_portrait_assets');PortraitAssetLoads=PortraitAssetLoads+1;return Asset end\nPortraits=(function()\n${readFileSync('src/lua/abyss_traveler_portraits.lua','utf8')}\nend)()`);
  run(code);
 } finally {lauxlib.luaL_newstate=old;if(state)lua.lua_close(state);rmSync(dir,{recursive:true,force:true});}
}
