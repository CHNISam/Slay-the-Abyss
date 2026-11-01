package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local ids={'regret','injury','doubt','pain','decay','shame','writhe','clumsy','normality','parasite'}
local host,ui,panel,emit,tap,drain,_,root=H.setup(ids,{'cultist'})
local C=H.F.Combat
local s=host.run.combat
C.draw(s,10);host:refresh()
assert(#s.hand==10)
for i,c in ipairs(s.hand)do
 local box=panel:GetChild('card'..i);local d=s.catalog.cards[c.cardId]
 assert(box:GetChild('name').text==d.name,c.cardId..' name')
 assert(box:GetChild('type').text=='诅咒',c.cardId..' type')
 assert(box:GetChild('cost').text=='',c.cardId..' blank cost')
 assert(box:GetChild('label').text==d.text,c.cardId..' rendered text')
 local hp,energy=s.player.hp,s.energy
 tap('card'..i,1);tap('card'..i,2);drain()
 assert(s.player.hp==hp and s.energy==energy and #s.hand==10,c.cardId..' unplayable')
end
print('BASIC_CURSES_UI_PASS 10 Chinese card faces, text, type, blank costs and unplayability')
