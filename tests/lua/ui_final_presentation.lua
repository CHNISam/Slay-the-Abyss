local actorControl=dofile('tests/lua/support/game_ui_fixture.lua').actorControl
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
local Native=dofile('tests/lua/support/current_monster_controls.lua')
local C=F.Combat
local host,root=F.fixture()
assert(F.start(host))
assert(require('abyss_run').startCombat(host.run,'cultist_solo'))
C.addStatus(host.run.combat.enemies[1],'strength',120)
host:refresh()
local panel=root:GetChild('battlePanel')
local actor=Native.actor(panel,host.run.combat.enemies[1])
local chip=Native.power(actor,'strength')
assert(chip:GetChild('count').text=='120','source monster amount is uncapped, not player 99+')
C.addStatus(host.run.combat.enemies[1],'strength',-127);host:refresh()
assert(chip:GetChild('count').text=='-7','negative source Strength retains sign')
assert(chip:GetChild('count').fontColor.r==255 and chip:GetChild('count').fontColor.g==0,'negative Power amount is red')
assert(not chip:GetChild('edge').visible and not chip:GetChild('badge').visible,'source row has no invented backplates')
assert(not actor:GetChild('intentLabel').visible,'only attack intent has a compact numeric caption')
assert(actor:GetChild('intentExtra'),'native adapter retains compatibility controls, without extra world intents')
-- Isolated arithmetic fixture uses a real mapped multi-hit constructor/move.
local battle=C.new(F.Data,{deck={'defend'},enemies={'guardian'}})
local enemy=battle.enemies[1];enemy.ai=nil;enemy.intentIndex=1
enemy.intents={{id='guardian_3',kind='attack',effects={
 {op='damage',value=6,times=2},{op='block',value=3},{op='applyStatus',status='weak',value=1}}}}
host.run.combat=battle;host:refresh();actor=Native.actor(panel,enemy)
local first,second,third=actor:GetChild('intentIcon'),actor:GetChild('intentBadge'),actor:GetChild('intentExtra')
assert(first.visible and not second.visible and not third.visible,'world intent renders one original source texture')
local face=View.intentView(battle,1)
local icons=View.icons(face)
assert(#icons==3 and icons[1]=='attack' and icons[2]=='defend' and icons[3]=='debuff','detail projection retains every mixed effect')
assert(actor:GetChild('intent').text=='6x2','compact attack retains final source multi-hit damage')
assert(actor:GetChild('intent').y<first.y,'damage number stays below attack icon')
print('UI_FINAL_PRESENTATION_PASS detail priority, single world intent, uncapped source stacks, native controls')
