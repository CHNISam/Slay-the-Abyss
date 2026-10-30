local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local A=require('abyss_actor');local data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local Run=require('abyss_run');local Display=require('abyss_card_display')
local catalog=Run.new(data,42)
local battle=C.new(catalog.data,{deck={},enemies={'jaw_worm'},seed=42})
local presentation=require('abyss_character_presentation').prepare(require('abyss_presentation'),catalog.data)
local rendered=0
for _,definition in ipairs(catalog.data.cards.cards)do if definition.colorlessNative then
 for _,upgraded in ipairs({false,true})do
  local instance={cardId=definition.id,upgraded=upgraded}
  local outside=C.cardDefinition({catalog=battle.catalog},instance)
  assert(outside.id==definition.id,'noncombat definition lookup lost source identity')
  local live=C.cardDefinition(battle,instance)
  local text=Display.permanentText(presentation[definition.id],live,instance)
  assert(type(text)=='string' and text~='' and not text:find('{effects',1,true),definition.id)
  if definition.id=='good_instincts' then eq(text,upgraded and '获得9点格挡。' or '获得6点格挡。') end
  if definition.id=='finesse' then eq(text,upgraded and '获得4点格挡。抽1张牌。' or '获得2点格挡。抽1张牌。') end
  if definition.id=='mind_blast' then
   assert(text:find('抽牌堆张数',1,true));eq(outside.effects[1].value,0)
  end
  rendered=rendered+1
 end
end end
eq(rendered,78)
local mind=C.new(data,{deck={'mind_blast','strike','strike','defend','defend','defend','defend'},enemies={'jaw_worm'},seed=42})
for _,held in ipairs(mind.hand)do if held.cardId=='mind_blast' then
 A.addStatus(mind.player,'strength',2)
 local definition=C.cardDefinition(mind,held);eq(definition.effects[1].value,#mind.draw)
 local preview=C.cardPreview(mind,held,1);eq(preview[1].low,#mind.draw+2)
 assert(Display.combatText(presentation.mind_blast,definition,held,preview):find(tostring(#mind.draw+2),1,true))
end end
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
A.addStatus(host.run.combat.player,'intangible',1)
-- Stage the modified opening state before a fresh presentation instance.
-- Primitive addStatus does not run source ApplyPowerAction display callbacks.
host.run.combat=C.copy(host.run.combat);host:refresh()
eq(monsterControl(panel,'enemy1'):GetChild('intent').text,'1')
local live=host.run.combat;local hpBefore=live.player.hp;assert(C.endTurn(live));eq(hpBefore-live.player.hp,1)
print('ok all 78 colorless display variants, status explanations and Intangible live preview parity')
