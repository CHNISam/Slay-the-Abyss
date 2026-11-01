local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Surfaces=require('abyss_monster_surfaces')
local creates,destroys=0,0
local original=F.GameUI.new
F.GameUI.new=function(root,data,presentation,event,platform)
 local api=platform.monsterActors
 local create,destroy=api.instantiate,api.destroy
 api.instantiate=function(index,...)if index==api.templateIndex then creates=creates+1 end;return create(index,...)end
 api.destroy=function(box)if box.name=='AbyssMonsterActor'then destroys=destroys+1 end;return destroy(box)end
 return original(root,data,presentation,event,platform)
end
local host,root=F.fixture();F.GameUI.new=original
assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local manager=assert(Surfaces.get(root:GetChild('battlePanel')))
local battle=host.run.combat;local id=battle.enemies[1].id
local box=assert(manager:find(id));local beforeCreate,beforeDestroy=creates,destroys
-- Preserve the entire run graph, including identity, all RNG streams and event queues.
local saved={}
local function remember(value)
 if type(value)~='table' or saved[value]then return end
 local copy={};saved[value]=copy
 for key,item in pairs(value)do copy[key]=item;remember(key);remember(item)end
end
remember(host.run)
local function unchanged()
 for original,copy in pairs(saved)do
  for key,value in pairs(original)do assert(copy[key]==value,'run graph value changed')end
  for key,value in pairs(copy)do assert(original[key]==value,'run graph entry removed')end
 end
end
for _=1,10 do
 assert(host:openMenu());F.click(root,'runMenu','map')
 assert(manager:find(id)==box and box.alive,'temporary overlay must retain actor identity')
 assert(not box.visible and not host.battleUI.active,'retained actor must be hidden and inactive')
 assert(host:closeExit());assert(host.mode=='battle')
 assert(manager:find(id)==box and box.visible,'return must reuse and show the same actor')
end
assert(creates==beforeCreate and destroys==beforeDestroy,'overlay must not allocate or destroy actors')
unchanged()
print('OVERLAY_COUNTS 10 cycles creates='..(creates-beforeCreate)..' destroys='..(destroys-beforeDestroy))
-- Explicit unmount retains its old destruction contract.
host.battleUI:setActive(false);assert(not box.alive and not manager:find(id))
host.battleUI:setActive(true);box=assert(manager:find(id));assert(box.alive)
assert(host:openDeck());local old=box
local nextBattle=F.Combat.new(F.Data,{enemies={'cultist'},deck={'strike'},seed=42})
host.run.combat=nextBattle;host:refresh();assert(not old.alive,'new battle cannot retain old actor')
host:closeDeck();box=assert(manager:find(nextBattle.enemies[1].id));assert(box~=old)
assert(host:openDeck());host.battleUI:setActive(false)
assert(not box.alive,'plain false while already suspended must unmount')
host:closeDeck();box=assert(manager:find(nextBattle.enemies[1].id))
-- Settling is not a resumable overlay, even while the core still reports combat.
assert(host:openMenu());host.settlementRequested=true;host:refresh()
assert(not box.alive,'settlement request must release the suspended actor')
host.settlementRequested=false;assert(host:closeExit());box=assert(manager:find(nextBattle.enemies[1].id))
assert(host:openDeck());host:disable();assert(not box.alive,'disable must release retained actor')
print('BATTLE_OVERLAY_SURFACE_RETENTION_PASS')
