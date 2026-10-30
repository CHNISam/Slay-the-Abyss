local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
-- Actual generated controls: visible Large Spike intent, two cards, and Frail.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local inspectDetails=dofile('tests/lua/support/status_detail_fixture.lua')
local C=H.F.Combat
local host,ui,panel,emit,tap,drain=H.setup({'defend'},{'spike_slime_l'})
local s=host.run.combat;s.enemies[1].intentIndex=1
s=C.copy(s);host.run.combat=s;host:refresh()
assert(monsterControl(panel,'enemy1'):GetChild('intent').text=='16')
local before=C.copy(s);tap('enemy1',1);local detail=inspectDetails(ui,panel)
assert(detail:find('16',1,true) and detail:find('将 2 张「黏滞」放入你的弃牌堆',1,true))
dofile('tests/lua/support/intent_face_assertion.lua')(monsterControl(panel,'enemy1'),require('abyss_battle_intent_view').intentView(s,1))
assert(s.seed==before.seed and s.player.hp==before.player.hp and s.enemies[1].hp==before.enemies[1].hp,'inspect does not mutate combat')
tap('endTurn',2);drain();assert(s.player.hp==64)
local found={};for i,c in ipairs(s.hand)do if c.cardId=='slimed' then found[#found+1]={slot=i,uid=c.uid} end end
assert(#found==2 and found[1].uid~=found[2].uid,'two real distinct generated cards')
local card=panel:GetChild('card'..found[1].slot);assert(card:GetChild('name').text=='黏滞' and card:GetChild('cost').text=='1')
tap('card'..found[1].slot,3);tap('playArea',4);drain();assert(s.energy==2 and #s.exhaust==1)
s.enemies[1].intentIndex=2;host:refresh();tap('enemy1',5);local frail=inspectDetails(ui,panel)
assert(frail:find('使你获得 2 回合脆弱',1,true),'upcoming debuff is not an already applied status')
print('LARGE_SPIKE_UI_PASS intent16/detail2/read-only/two-generated-cards/real-exhaust/frail2')
