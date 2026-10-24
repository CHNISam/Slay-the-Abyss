-- Real generated controls, not a model of the new status card UI.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C=H.F.Combat
local host,ui,panel,emit,tap,drain=H.setup({'defend'},{'spike_slime_m'})
local s=host.run.combat;s.enemies[1].intentIndex=1;host:refresh()
assert(panel:GetChild('enemy1'):GetChild('intent').text=='8')
tap('enemy1',1);local detail=panel:GetChild('notice').text
assert(detail:find('8',1,true) and detail:find('黏滞',1,true) and detail:find('弃牌堆',1,true))
tap('endTurn',2);drain();assert(s.player.hp==72)
local slot,uid;for i,c in ipairs(s.hand)do if c.cardId=='slimed' then slot=i;uid=c.uid end end;assert(slot,'real enemy must generate drawn Slimed')
local box=panel:GetChild('card'..slot)
assert(box:GetChild('cost').text=='1','visible energy cost')
assert(box:GetChild('name').text=='黏滞','custom name')
assert(box:GetChild('label').text:find('1',1,true),'rendered cost in explanation')
tap('card'..slot,3);assert(ui.selected==uid);tap('card'..slot,4);drain()
assert(s.energy==2 and #s.exhaust==1 and s.exhaust[1].uid==uid,'two-tap status play exhausts once')
-- Repeated stale Up/Click cannot play the moved-out card or charge energy twice.
emit('card'..slot,'up',4);emit('card'..slot,'click',4);drain();assert(s.energy==2 and #s.exhaust==1)
print('SLIMED_GENERATED_UI_PASS intent/detail/generated-draw/cost/two-tap/exhaust/repeat')
