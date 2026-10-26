package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local A=require('abyss_actor');local data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local s=C.new(data,{deck={'strike'},enemies={'jaw_worm'},seed=1})
A.addStatus(s.enemies[1],'intangible',1)
eq(C.cardPreview(s,s.hand[1],1)[1].low,1)
local before=s.enemies[1].hp;assert(C.play(s,s.hand[1].uid,1));eq(before-s.enemies[1].hp,1)
A.addStatus(s.player,'intangible',1)
local intent=C.intent(s,1);local attack
for _,effect in ipairs(intent.effects)do if effect.op=='damage'then attack=effect.value end end
assert(attack);eq(C.attackAmount(s,s.enemies[1],s.player,attack),1)
local hp=s.player.hp;assert(C.endTurn(s));eq(hp-s.player.hp,1)
for _,id in ipairs({'no_block','intangible','magnetism','mayhem','panache','sadistic_nature','shackled'})do
 local actor=id=='shackled'and s.enemies[1]or s.player
 A.addStatus(actor,id,id=='panache'and 5 or 2)
 for _,view in ipairs(A.statusView(actor))do if view.id==id then
  assert(view.name:find('[\128-\255]'),id..' needs Chinese name');assert(view.description:find('[\128-\255]'),id..' needs explanation')
 end end
end
local p=C.new(data,{deck={'panache'},enemies={'jaw_worm'},seed=2});assert(C.play(p,p.hand[1].uid))
local view=A.statusView(p.player)[1];assert(view.description:find('10',1,true));assert(view.description:find('5',1,true))
local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local host,ui,panel=H.setup({'strike','defend'},{'jaw_worm'})
A.addStatus(host.run.combat.player,'intangible',1);ui:render()
eq(panel:GetChild('enemy1'):GetChild('intent').text,'1')
local live=host.run.combat;local hpBefore=live.player.hp;assert(C.endTurn(live));eq(hpBefore-live.player.hp,1)
print('ok colorless status explanations and Intangible live preview parity')
