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
host.run.combat.enemies[1].statuses.strength=120
host:refresh()
local panel=root:GetChild('battlePanel')
local row=panel:GetChild('enemy1'):GetChild('statusRow')
local capped=false
for i=1,10 do
 local count=row:GetChild('count'..i)
 if count and count.visible and count.text=='99+' then capped=true end
end
assert(capped,'large positive status stack must remain readable as 99+')
host.run.combat.enemies[1].statuses.strength=-7;host:refresh()
local signed=false
for i=1,10 do
 local count=row:GetChild('count'..i)
 if count and count.visible and count.text=='−7' then signed=true end
end
assert(signed,'negative Strength must retain its sign')
local actor=panel:GetChild('enemy1')
assert(not actor:GetChild('intentLabel').visible,'only attack intent has a compact numeric caption')
assert(actor:GetChild('intentExtra'),'native pool must support the third simultaneous intent')
local enemy=host.run.combat.enemies[1]
enemy.statuses.strength=0
enemy.intents[enemy.intentIndex]={id='ui_fixture',kind='attack',effects={
 {op='damage',value=6,times=2},{op='block',value=3},{op='applyStatus',status='weak',value=1}}}
host:refresh()
local first,second,third=actor:GetChild('intentIcon'),actor:GetChild('intentBadge'),actor:GetChild('intentExtra')
assert(first.visible and second.visible and third.visible)
assert(first.x+first.sizeDeltaX/2<second.x-second.sizeDeltaX/2)
assert(second.x+second.sizeDeltaX/2<third.x-third.sizeDeltaX/2)
assert(first.y==second.y and second.y==third.y,'simultaneous intents must share one horizontal row')
assert(actor:GetChild('intent').text=='6×2','compact attack must retain final multi-hit damage')
assert(actor:GetChild('intent').y<first.y,'damage number must sit below its attack icon')
local plates=row:GetChild('backplates')
assert(plates,'status counts and buff/debuff borders require native backplates')
print('UI_FINAL_PRESENTATION_PASS icon priority, three-icon cap, stack cap, negative stacks, native controls')
