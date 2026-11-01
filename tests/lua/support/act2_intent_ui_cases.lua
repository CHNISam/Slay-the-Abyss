local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C=H.F.Combat
local function details(ui,panel)
 local info,parts=panel:GetChild('statusInfo'),{}
 assert(info.visible and ui.info)
 for page=1,ui.info.pages do
  for i=1,H.F.Theme.layout.statusInfo.rows do
   for _,field in ipairs({'name','text','note','tag'})do
    local part=info:GetChild(field..i);if part.visible then parts[#parts+1]=part.text end
   end
  end
  if page<ui.info.pages then info:GetChild('page').click()end
 end
 return table.concat(parts,'\n')
end
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
local function detail(id,move)
 local members=id=='gremlin_leader' and {'mad_gremlin','sneaky_gremlin',id}
    or id=='bronze_orb' and {'automaton',id} or {id}
 local host,ui,panel,_,tap=H.setup({'defend'},members)
 local index=#members
 local enemy=host.run.combat.enemies[index]
 for i,intent in ipairs(enemy.intents)do if intent.id==move then enemy.intentIndex=i end end
 assert(enemy.intents[enemy.intentIndex].id==move)
 -- Stage the exact source move before initializing its displayed descriptor.
 local before=host.run.combat;host.run.combat=C.copy(before)
 host:refresh();tap('enemy'..index,1)
 same(host.run.combat,before)
 return details(ui,panel),monsterControl(panel,'enemy'..index),require('abyss_battle_intent_view').intentView(host.run.combat,index)
end
local cases={
function()
local heal=detail('mystic','heal')
assert(heal:find('全体',1,true) and heal:find('16',1,true) and not heal:find('未知',1,true),'Mystic group heal intent is missing')

end,
function()
local strength=detail('mystic','buff')
assert(strength:find('全体',1,true) and strength:find('力量',1,true) and strength:find('2',1,true),'Mystic group strength intent is missing')

end,
function()
local cleanse=detail('champ','anger')
assert(cleanse:find('移除',1,true) and cleanse:find('负面',1,true) and cleanse:find('6',1,true) and not cleanse:find('未知',1,true),'Champ cleanse intent is missing')

end,
function()
local vampire,box=detail('shelled_parasite','life_suck')
assert(box:GetChild('intent').text=='10' and vampire:find('实际',1,true) and vampire:find('回复',1,true),'life-drain damage and healing must both be explained')

end,
function()
local wake=detail('lagavulin','lagavulin_stunned')
assert(wake:find('惊醒',1,true))

end,
function()
local stun,stunBox,stunFace=detail('automaton','stunned')
assert(not stun:find('惊醒',1,true) and stun:find('不行动',1,true))
dofile('tests/lua/support/intent_face_assertion.lua')(stunBox,stunFace,'昏眩')
assert(stunFace.kind=='unknown' and stunFace.sourceEnum=='STUN' and not stunBox:GetChild('intentIcon').visible,'source STUN uses particles instead of a world base glyph')

end,
function()
local rally=detail('gremlin_leader','rally')
assert(rally:find('最多 2',1,true) and not rally:find('未知',1,true))

end,
function()
local encourage=detail('gremlin_leader','encourage')
assert(encourage:find('3',1,true) and encourage:find('6',1,true) and encourage:find('队友',1,true))

end,
function()
local spawn=detail('collector','spawn')
assert(spawn:find('2',1,true) and spawn:find('随从',1,true))

end,
function()
local revive=detail('collector','revive')
assert(revive:find('复活',1,true) and revive:find('存活',1,true))

end,
function()
local orbs=detail('automaton','spawn_orbs')
assert(orbs:find('2',1,true) and orbs:find('浮核',1,true),'Automaton summons must be explained')

end,
function()
local support=detail('bronze_orb','support')
assert(support:find('青铜机枢',1,true) and support:find('12',1,true),'orb block must name the actual recipient')

end,
function()
local stasis=detail('bronze_orb','stasis')
assert(stasis:find('扣押',1,true) and stasis:find('击败',1,true),'Stasis custody and return must be explained')

end,
function()
local host,ui,panel=H.setup({'defend','strike','bash','strike','strike','strike'},{'automaton','bronze_orb'})
local battle=host.run.combat
battle.cardRandomRng=require('abyss_sts_random').fromSeed('42')
C.applyEffects(battle,{{op='enemyStasis',value=1}},battle.enemies[2],battle.player)
local held=battle.enemies[2].stasisCardId
assert(held)
host:refresh()
local before=C.copy(battle)
assert(ui:showStatus(2))
local heldName=ui.presentation[held].name
local shown=details(ui,panel)
assert(shown:find(heldName,1,true) and shown:find('击败',1,true),'held card must be visible by name')
same(battle,before)

end,
}
return function(first,last)
 assert(first>=1 and last<=#cases and first<=last)
 for index=first,last do cases[index]() end
 print("ACT2_INTENT_UI_PASS "..(last-first+1))
end
