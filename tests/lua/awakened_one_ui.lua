local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
-- Generated-control fixture with explicit boundary HP. Not a natural route,
-- native candidate import, or live game/desktop evidence.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,A=H.F.Combat,require('abyss_actor')
local View=require('abyss_battle_intent_view')
local host,ui,panel,_,tap,drain,_,root=H.setup({'bludgeon'},{'awakened_one'})
local s,e=host.run.combat,host.run.combat.enemies[1]
local function has(text,part)assert(text:find(part,1,true),text..' missing '..part)end
local function click(control,touch)
 assert(control.visible,'control must be visible')
 assert(control.listeners and control.listeners.click,'real control needs click listener')
 return control.listeners.click({touchId=touch})
end
local unawakened
for i,entry in ipairs(C.statusView(e))do if entry.id=='unawakened'then unawakened=i end end
assert(unawakened and dofile('tests/lua/support/monster_power_control_fixture.lua')(monsterControl(panel,'enemy1'),'unawakened'):GetChild('count').text=='')
e.hp=1;host:refresh()
tap('card1',101);tap('enemy1',102);drain()
assert(host.run.phase=='combat'and e.hp==0 and e.halfDead)
assert(monsterControl(panel,'enemy1').visible)
assert(monsterControl(panel,'enemy1'):GetChild('hp').text=='0/300')
-- This full-source enemy currently retains legacy rendering, outside the
-- Act1/2 source-enum registry. Presence keeps its world glyph and detail hit.
local rebirth=View.intentView(s,1)
assert(rebirth.sourceEnum==nil and rebirth.label=='未知')
dofile('tests/lua/support/intent_face_assertion.lua')(monsterControl(panel,'enemy1'),rebirth,'未知')
assert(monsterControl(panel,'enemy1'):GetChild('intentIcon').visible and monsterControl(panel,'enemy1'):GetChild('intentIcon').imageId==H.F.Theme.icon.intent.unknown,'legacy Rebirth keeps its unknown world glyph')
assert(monsterControl(panel,'enemy1'):GetChild('intentHit').visible,'present half-dead actor retains its intent detail target')
assert(not ui.feedback.deaths[e.id],'halfDead must not animate a terminal death')
for _,event in ipairs(ui.feedback.queue or {})do
 assert(not(event.kind=='death'and event.detail.target==e.id),'no first-form death collapse')
end
assert(not A.isActive(e)and A.isPresent(e))
has(rebirth.text,'300');has(rebirth.text,'第二形态')
click(monsterControl(panel,'enemy1'):GetChild('intentHit'),103)
local info=panel:GetChild('statusInfo')
assert(info.visible);has(info:GetChild('text1').text,'300');has(info:GetChild('text1').text,'第二形态')
click(info:GetChild('hit'),104)
assert(not info.visible)
click(monsterControl(panel,'enemy1'):GetChild('intentHit'),105)
-- This hit opens the next-action card, whose subtitle describes timing.
assert(info.visible and ui.info.kind=='intent')
has(info:GetChild('summary').text,'尚未执行');has(info:GetChild('text1').text,'300')
click(info:GetChild('hit'),106)
tap('endTurn',107);drain()
assert(host.run.phase=='combat'and e.hp==300 and not e.halfDead)
assert(monsterControl(panel,'enemy1').visible)
assert(monsterControl(panel,'enemy1'):GetChild('hp').text=='300/300')
assert(monsterControl(panel,'enemy1'):GetChild('intent').text=='40')
-- The revived actor is now eligible for its real body/status entry point.
tap('enemy1',110)
assert(info.visible and ui.info.kind==nil);has(info:GetChild('summary').text,'生命 300/300')
click(info:GetChild('hit'),111)
assert(not info.visible and e.hp==300 and not e.halfDead)
-- Project the source mixed intent without mutating it during preview.
for i,intent in ipairs(e.intents)do if intent.id=='sludge'then e.intentIndex=i end end
local sludge=View.intentView(s,1)
assert(sludge.kind=='attack'and sludge.badge=='debuff'and sludge.value=='18')
has(sludge.text,'虚空');has(sludge.text,'抽牌堆');host:refresh()
e.hp=1;host:refresh();tap('card1',108);tap('enemy1',109);drain()
assert(host.run.phase=='reward'and host.run.victories==1)
assert(ui.feedback.deaths[e.id],'second form must receive a real death')
assert(root:GetChild('battlePanel').visible)
print('AWAKENED_ONE_UI_PASS real-controls/zero-HP/rebirth-tooltip/status-tooltip/no-first-collapse/second-form/void-intent/reward-once')
