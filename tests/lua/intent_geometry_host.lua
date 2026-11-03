local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Surfaces=require('abyss_monster_surfaces')
local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local manager=assert(Surfaces.get(root:GetChild('battlePanel')))
local battle=host.run.combat;local id=battle.enemies[1].id
local box=assert(manager:find(id));host:update(1)
local size,position=0,0
local controls={}
for _,name in ipairs({'intentIcon','intent','intentHit'})do
 local c=box:GetChild(name);controls[#controls+1]=c
 local setSize,setPosition=c.SetSizeDelta,c.SetAnchoredPosition
 c.SetSizeDelta=function(self,...)size=size+1;return setSize(self,...)end
 c.SetAnchoredPosition=function(self,...)position=position+1;return setPosition(self,...)end
end
local saved={}
local function remember(value)
 if type(value)~='table' or saved[value]then return end
 local copy={};saved[value]=copy
 for key,item in pairs(value)do copy[key]=item;remember(key);remember(item)end
end
remember(host.run)
local function unchanged()
 for original,copy in pairs(saved)do
  for key,value in pairs(original)do assert(copy[key]==value,'run/RNG graph changed')end
  for key,value in pairs(copy)do assert(original[key]==value,'run/RNG graph entry removed')end
 end
end
local keys={'x','y','sizeDeltaX','sizeDeltaY','visible','raycastTarget','text','click','parent','kind'}
local fields={}
for _,c in ipairs(controls)do
 local values={};fields[c]=values;for _,key in ipairs(keys)do values[key]=c[key]end
end
local function geometryUnchanged()
 for c,values in pairs(fields)do for _,key in ipairs(keys)do assert(c[key]==values[key],'intent field changed: '..key)end end
end
local clock=host.battleUI.feedback.idleClock
-- Drive the actual mounted BattleUI: GameUI:update also advances the run timer.
for _=1,300 do host.battleUI:update(1/60)end
print('INTENT_GEOMETRY_HOST updates=300 size='..size..' position='..position)
assert(host.battleUI.feedback.idleClock>clock,'idle animation must still advance')
unchanged();geometryUnchanged()
for _=1,3 do
 assert(host:openDeck());assert(manager:find(id)==box and box.alive and not box.visible)
 local hiddenClock=host.battleUI.feedback.idleClock;host.battleUI:update(.2)
 assert(host.battleUI.feedback.idleClock==hiddenClock,'hidden UI must not animate')
 host:closeDeck();assert(manager:find(id)==box and box.visible)
 geometryUnchanged();unchanged()
end
assert(size==0 and position==0,'real Host resubmitted stable intent geometry')
host.battleUI:setActive(false);assert(not box.alive)
host.battleUI:setActive(true);local fresh=assert(manager:find(id));assert(fresh~=box and fresh.alive)
for _,name in ipairs({'intentIcon','intent','intentHit'})do
 local before,after=box.children[name],fresh:GetChild(name)
 assert(after.x==before.x and after.y==before.y and after.sizeDeltaX==before.sizeDeltaX and after.sizeDeltaY==before.sizeDeltaY,'new native intent handle not initialized')
end
assert(host:openDeck())
local replacement=F.Combat.new(F.Data,{enemies={'cultist'},deck={'strike'},seed=42})
host.run.combat=replacement;host:refresh();assert(not fresh.alive)
host:closeDeck();local nextBox=assert(manager:find(replacement.enemies[1].id));assert(nextBox~=fresh)
host:disable();assert(not nextBox.alive)
print('INTENT_GEOMETRY_HOST_PASS idle/hidden-return/run-RNG/unmount/new-battle/disable')
