local counts,byPath={},{}
local rawDofile=dofile
local function count(k,path)counts[k]=(counts[k]or 0)+1;if path then byPath[k..':'..path]=(byPath[k..':'..path]or 0)+1 end end
local methods={'SetVisible','SetSizeDelta','SetLocalScale','SetAnchoredPosition','SetImage','SetAsLastSibling','SetLocalRotation'}
local controls=0
_G.dofile=function(path)
 local out=rawDofile(path)
 if path=='tests/lua/support/native_ui_contract.lua' then
  local base=out.control
  out.control=function(box,spec)
   box=base(box,spec);controls=controls+1;count('construct')
   local prev=getmetatable(box);local backing={text=rawget(box,'text'),fontSize=rawget(box,'fontSize')}
   rawset(box,'text',nil);rawset(box,'fontSize',nil)
   local path=box.name or '<root>';local p=box.parent;while p do path=(p.name or '<root>')..'/'..path;p=p.parent end
   local meta={};for k,v in pairs(prev or {})do meta[k]=v end
   meta.__index=function(self,k)if k=='text' or k=='fontSize'then return backing[k]end;if prev and prev.__index then return prev.__index(self,k)end end
   meta.__newindex=function(self,k,v)
    if k=='text' or k=='fontSize'then count(k,path);if backing[k]==v then count(k..'_same',path)end;backing[k]=v;return end
    if prev and prev.__newindex then return prev.__newindex(self,k,v)end;rawset(self,k,v)
   end
   setmetatable(box,meta)
   for _,name in ipairs(methods)do local fn=box[name];if fn then box[name]=function(self,...)count(name,path);local args={...};local key='_audit_'..name;local old=rawget(self,key);local same=old~=nil and #old==#args; if same then for i,v in ipairs(args)do if v~=old[i]then same=false;break end end end;if same then count(name..'_same',path)end;rawset(self,key,args);return fn(self,...)end end end
   return box
  end
 end
 return out
end
local rawRequire=require
_G.require=function(name)count('require');if package.loaded[name]~=nil then count('require_cached')else count('require_cold')end;return rawRequire(name)end
local start=os.clock();local F=dofile('tests/lua/support/game_ui_fixture.lua');print('TIME fixture_module_ms '..((os.clock()-start)*1000))
local RealUI=require('abyss_game_ui');local oldNew=RealUI.new
RealUI.new=function(root,data,presentation,event,platform)
 local api=platform.monsterActors;if api then local oldCreate,oldDestroy=api.instantiate,api.destroy;api.instantiate=function(...)count('actor_instantiate');return oldCreate(...)end;api.destroy=function(...)count('actor_destroy');return oldDestroy(...)end end
 return oldNew(root,data,presentation,event,platform)
end
local function summary(label,fn)
 counts,byPath={},{};local t=os.clock();fn();local elapsed=(os.clock()-t)*1000
 local list={};for k,v in pairs(counts)do list[#list+1]=k..'='..v end;table.sort(list)
 print('SAMPLE '..label..' ms='..elapsed..' '..table.concat(list,' '))
 local paths={};for k,v in pairs(byPath)do if k:match('^text:') or k:match('^fontSize:') or k:match('^SetSizeDelta:')then paths[#paths+1]={k,v}end end
 table.sort(paths,function(a,b)return a[2]>b[2]end);for i=1,math.min(8,#paths)do print('PATH '..label..' '..paths[i][1]..'='..paths[i][2])end
end
local ui,root
summary('construct_ui',function()ui,root=F.fixture()end)
local function wrap(obj,key)local fn=obj[key];obj[key]=function(self,...)count(key);return fn(self,...)end end
wrap(ui,'refresh');wrap(ui.battleUI,'render');wrap(ui.mapUI,'render')
summary('menu_idle_300',function()for i=1,300 do ui:update(1/60)end end)
summary('start_geo',function()assert(F.start(ui,'ironclad'))end)
summary('map_idle_300',function()assert(ui.mode=='map',ui.mode);for i=1,300 do ui:update(1/60)end end)
summary('enter_battle',function()
 assert(require('abyss_run').startCombat(ui.run,'cultist_solo'));ui:refresh()
end)
summary('battle_idle_300',function()assert(ui.mode=='battle');for i=1,300 do ui:update(1/60)end end)
summary('battle_map_preview_10',function()for i=1,10 do assert(ui:openMenu());F.click(root,'runMenu','map');assert(ui:closeExit());assert(ui.mode=="battle")end end)
