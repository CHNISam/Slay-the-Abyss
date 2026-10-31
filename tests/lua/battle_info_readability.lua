local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Theme=require('abyss_theme')
local Enemy=require('abyss_battle_enemy_view')
local failures={}
local function check(ok,message)if not ok then failures[#failures+1]=message end end
local cursorX,cursorY
local host,root=F.fixture(nil,nil,nil,nil,nil,nil,{position=function()return cursorX,cursorY end})
assert(F.start(host));assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
local panel=root:GetChild('battlePanel')
for _,floor in ipairs({2,12})do
 host.run.nodeFlow={type='combat',floor=floor};host:refresh()
 check(panel:GetChild('floor').text=='','floor '..floor..' remains a naked potion-overlapping digit')
 check(panel:GetChild('title').text:find('第'..floor..'层',1,true)~=nil,'floor must remain identifiable in scene title')
end
for _,id in ipairs({'jaw_worm','guardian','shelled_parasite','gremlin_nob','sentry','collector','hexaghost','champ'})do
 local battle=F.Combat.new(F.Data,{enemies={id},deck={'strike'},seed=42})
 host.run.combat=battle;host:refresh();host:update(.8)
 local actor=battle.enemies[1]
 local box=require('abyss_monster_surfaces').get(panel):find(actor.id)
 local g=Enemy.geometry(actor)
 local top=math.max(g.portrait/2,g.hitY-g.y+g.hitHeight/2)
 local icon,value=box:GetChild('intentIcon'),box:GetChild('intent')
 check(g.y+icon.y+icon.sizeDeltaY/2<=Theme.layout.topBar.y-Theme.layout.topBar.height/2-4,id..' intent intrudes into topbar')
 check(icon.y-icon.sizeDeltaY/2>=top+4-1e-8,id..' intent icon overlaps body')
 check(value.y-value.sizeDeltaY/2>=top+4-1e-8,id..' intent number overlaps body')
 check(value.x-value.sizeDeltaX/2>=icon.x+icon.sizeDeltaX/2+4-1e-8,id..' intent number overlaps icon')
 cursorX,cursorY=640+g.hitX,360+g.hitY
 host:update(.001)
 check(box:GetChild('name').visible and box:GetChild('name').fontColor.a==255,id..' name replays slow fade on hover')
 cursorX,cursorY=nil,nil
 host:update(1)
 cursorX,cursorY=640+g.hitX,360+g.hitY
 host:update(.001)
 check(box:GetChild('name').fontColor.a==255,id..' repeated hover replays slow fade')
 cursorX,cursorY=nil,nil
 local pool=require('abyss_monster_power_surfaces').get(box:GetChild('statusRow'))
 local powers=0
 pool:each(function(chip)
  powers=powers+1
  local power=chip:GetChild('icon')
  local upper=chip.y+power.y+power.sizeDeltaY/2
  check(upper<=g.healthY-g.healthHeight/2-4,id..' power icon overlaps HP bar')
 end)
 if id=='guardian' then
  check(powers>0,'guardian status-row clearance must exercise actual powers')
  check(pool:find('mode_shift')~=nil,'guardian mode-shift power must be present')
 end
end
host:disable()
assert(#failures==0,table.concat(failures,'\n'))
print('BATTLE_INFO_READABILITY_PASS')
