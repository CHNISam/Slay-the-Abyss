local Actors=require('abyss_monster_surfaces')
local Powers=require('abyss_monster_power_surfaces')
local Controller=require('abyss_controller')
local function run(kind,trigger)
 local dead=false;local operations=0;local manager;local hook;local retired=0
 local function native(name)
  assert(not dead,'native '..name..' after engine teardown');operations=operations+1
  if hook then hook(name)end
 end
 local function box()
  return setmetatable({},{__index=function(_,name)
   if name=='alive'then assert(not dead,'alive read after engine teardown');return true end
   return function()native(name)end
  end,__newindex=function()assert(not dead,'native property after teardown')end})
 end
 local layer=box();local stage={GetChild=function()return layer end}
 local api={enabled=true,templateIndex=1,containerTemplateIndex=2,powerTemplateIndex=3,
 instantiate=function()native('instantiate');return box()end,destroy=function()native('Destroy')end}
 local owner=kind=='actor'and stage or layer
 local module=kind=='actor'and Actors or Powers
 manager=module.new(owner,{monsterActors=api},nil,function(_,_,engineDestroyed)
  if trigger=='retire' and not dead then dead=true;manager:onEngineDestroy();return end
  assert(engineDestroyed==true or trigger=='clear','teardown retirement mode missing');retired=retired+1
 end)
 if trigger and trigger~='retire' and trigger~='clear' then hook=function(name)if name==trigger then hook=nil;dead=true;manager:onEngineDestroy()end end end
 local rows={{id='one',actor={id='one',definitionId='cultist'}}}
 local ok=pcall(manager.select,manager,rows,{})
 if trigger=='clear' then
  assert(ok);hook=function(name)if name=='SetVisible' then hook=nil;dead=true;manager:onEngineDestroy()end end
  manager:clear()
 elseif trigger=='retire' then assert(ok);manager:clear()
 elseif trigger then assert(not ok,'in-flight operation must abort')else assert(ok);dead=true;manager:onEngineDestroy();assert(retired==1)end
 local count=operations
 manager:onEngineDestroy();manager:clear()
 assert(not pcall(manager.select,manager,rows,{}),'destroyed manager must not allocate again')
 assert(operations==count and module.get(owner)==nil)
 assert(next(manager.records)==nil and next(manager.slots)==nil and next(manager.pages)==nil)
 assert(next(manager.owned or manager.retained)==nil)
end
for _,kind in ipairs({'actor','power'})do
 run(kind);run(kind,'instantiate');run(kind,'SetVisible');run(kind,'SetAsLastSibling');run(kind,'retire');run(kind,'clear')
end
-- Controller retirement must not even inspect an engine-invalid handle.
local invalid=setmetatable({},{__index=function()error('invalid native read')end,__newindex=function()error('invalid native write')end})
local record={control=invalid};local c={byControl={[invalid]=record},records={record},memory={battle=invalid}}
assert(Controller.unbind(c,invalid,true));assert(#c.records==0 and next(c.byControl)==nil and next(c.memory)==nil)
-- View ownership forget traverses the existing manager objects without native operations.
local pv=require('abyss_monster_power_view').new({},function()error('picture')end,function()error('tint')end,function()error('ink')end)
local iv=require('abyss_monster_intent_particle_view').new({},function()error('picture')end,function()error('tint')end)
local n=0;local pool={onEngineDestroy=function()n=n+1 end,clear=function()error('ordinary native cleanup')end}
pv.pools[invalid]=pool;iv.outputs[invalid]={behind=pool,after=pool};iv.states.one={}
pv:onEngineDestroy();iv:onEngineDestroy();assert(n==3 and next(pv.pools)==nil and next(iv.outputs)==nil and next(iv.states)==nil)
assert(not pcall(pv.render,pv,invalid,1,{},{}));assert(not pcall(iv.paint,iv,invalid,'one',{},true))
local art=require('abyss_monster_art').new({}, {nativeMonsterArtEnabled=false},{}, {})
art.pools[invalid]=pool;art:onEngineDestroy();assert(n==4 and next(art.pools)==nil)
require('abyss_monster_art').forgetBox(invalid)
print('MONSTER_ENGINE_TEARDOWN_PASS strict no-native forget / actor+power allocate+setter reentry / controller / view ownership')
