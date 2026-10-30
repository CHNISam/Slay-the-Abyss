local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local View=require('abyss_battle_intent_view')
local function kinds(face,expected)
 local got=View.icons(face)
 assert(#got==#expected)
 for i,id in ipairs(expected)do assert(got[i]==id,'intent icon priority or deduplication changed')end
end
kinds({kind='attack',rows={{icon='debuff'},{icon='defend'},{icon='buff'}}},{'attack','defend','buff'})
kinds({kind='buff',rows={{icon='defend'},{icon='buff'},{icon='defend'}}},{'defend','buff'})
kinds({kind='attack',rows={{icon=105077},{icon='debuff'}}},{'attack','debuff'})
kinds({kind='sleep',rows={}},{'sleep'})
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local host,root=F.fixture()
assert(F.start(host))
assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
F.Combat.addStatus(host.run.combat.enemies[1],'strength',120)
host:refresh()
local panel=root:GetChild('battlePanel')
local power=dofile('tests/lua/support/monster_power_control_fixture.lua')
local actor=monsterControl(panel,'enemy1')
local chip=power(actor,'strength')
assert(chip:GetChild('count').visible and chip:GetChild('count').text=='120','source counts retain all positive digits')
host.run.combat.enemies[1].statuses.strength=-7;host:refresh()
assert(chip:GetChild('count').visible and chip:GetChild('count').text=='-7','source negative Strength retains its sign')
assert(chip:GetChild('count').fontColor.r==255 and chip:GetChild('count').fontColor.g==0,'negative source power count remains red')
for _,name in ipairs({'edge','body','badge'})do assert(not chip:GetChild(name).visible,'source power icons have no backplate')end
assert(chip:GetChild('icon').visible)
-- Use a legal source multi-attack ID while isolating a mixed effect payload.
local C=F.Combat
local battle=C.new(F.Data,{enemies={'guardian'},deck={}})
local enemy=battle.enemies[1]
enemy.ai=nil;enemy.intentIndex=1
enemy.intents={{id='guardian_3',kind='attack',effects={
 {op='damage',value=6,times=2},{op='block',value=3},{op='applyStatus',status='weak',value=1}}}}
host.run.combat=battle;host:refresh();actor=monsterControl(panel,'enemy1')
local face=View.intentView(battle,1)
kinds(face,{'attack','defend','debuff'})
dofile('tests/lua/support/intent_face_assertion.lua')(actor,face)
dofile('tests/lua/support/source_intent_geometry.lua')(actor,enemy)
assert(actor:GetChild('intent').text=='6x2','world source attack retains all hits')
assert(actor:GetChild('intent').y<actor:GetChild('intentIcon').y,'damage sits below its world attack icon')
print('UI_FINAL_PRESENTATION_PASS tooltip icon priority, single world intent, uncapped signed source counts, native controls')
