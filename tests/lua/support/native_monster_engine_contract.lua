local F=dofile('tests/lua/support/game_ui_fixture.lua')
local install=dofile('tests/lua/support/native_monster_engine.lua')
local original=require('abyss_monster_actor_binding')
assert(original.enabled==false and original.templateIndex==0,'offline producer must remain unbound')
local panel=F.control({children=F.Layout}):GetChild('stage'):GetChild('battlePanel')
local ok,why=pcall(require('abyss_monster_surfaces').new,panel,{monsterActors=original})
assert(not ok and tostring(why):find('monster actor template is not bound',1,true),'real consumer must still reject offline preview bindings')
local fallbackCalls=0
local sentinel={}
local engine={InstantiateClientUIControl=function(index,parent)assert(index==987654);fallbackCalls=fallbackCalls+1;return sentinel end,
 DestroyClientUIControl=function(box)assert(box==sentinel);fallbackCalls=fallbackCalls+1 end}
local oldCreate,oldDestroy=engine.InstantiateClientUIControl,engine.DestroyClientUIControl
local restore=install(engine)
local binding=require('abyss_monster_actor_binding')
assert(binding.enabled and binding.templateIndex~=binding.powerTemplateIndex and binding.templateIndex~=binding.containerTemplateIndex)
local root=F.control({kind='container',name='root'})
local group=engine.InstantiateClientUIControl(binding.containerTemplateIndex,root)
local actor=engine.InstantiateClientUIControl(binding.templateIndex,group)
local power=engine.InstantiateClientUIControl(binding.powerTemplateIndex,actor)
assert(group.kind==F.Templates.AbyssReadyCardGroup.kind and actor:GetChild('portrait') and power.alive)
local function count(box)local n=1;for _,child in pairs(box.children)do n=n+count(child)end;return n end
assert(count(actor)==35+count(power),'real default-OFF actor template must be cloned in full')
engine.DestroyClientUIControl(group)
assert(not group.alive and not actor.alive and not power.alive,'parent destruction must invalidate descendants')
assert(not pcall(engine.DestroyClientUIControl,group),'double destroy must fail')
assert(engine.InstantiateClientUIControl(987654,root)==sentinel)
engine.DestroyClientUIControl(sentinel);assert(fallbackCalls==2,'other native artwork retains its engine')
restore();assert(package.loaded.abyss_monster_actor_binding==original)
assert(engine.InstantiateClientUIControl==oldCreate and engine.DestroyClientUIControl==oldDestroy)
print('NATIVE_MONSTER_ENTRY_ENGINE_PASS')
