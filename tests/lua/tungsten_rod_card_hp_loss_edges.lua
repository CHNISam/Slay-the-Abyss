package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,E,H,D=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_effects'),require('abyss_relic_hooks'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
local function battle(id,hp,fairy)
 return C.new(D,{seed=42,hp=hp,deck={id},beforeFirstTurn=function(s)
  s.relics={'tungsten_rod'}
  if fairy then s.potionInventory={'fairy_in_a_bottle'}end
  return true
 end})
end
do
 local s=battle('bloodletting');local hp=s.player.hp
 s.player.block=50;assert(A.applyPower(s,s.player,'intangible',1,s.player))
 assert(C.play(s,s.hand[1].uid));eq(s.player.hp,hp);eq(s.player.block,50)
 eq(s.player.damagedThisCombat or 0,0);eq(s.energy,5)
 print('PASS HP_LOSS bypasses block; Intangible then Rod yields zero and no HP notification')
end
do
 local s=battle('bloodletting');local hp=s.player.hp
 -- Explicit Power boundary; normal Ironclad source pools are unchanged.
 s.player.statuses.buffer=1
 assert(C.play(s,s.hand[1].uid));eq(s.player.hp,hp);eq(s.player.statuses.buffer,nil)
 eq(s.player.damagedThisCombat or 0,0);eq(s.energy,5)
 print('PASS Buffer consumes before Rod, while the card still gains energy')
end
do
 local s=battle('bloodletting');local hp=s.player.hp
 E.apply(C,s,{{op='loseHp',value=0}},s.player,s.player)
 eq(s.player.hp,hp);eq(s.player.damagedThisCombat or 0,0)
 local enemy=s.enemies[1];local before=enemy.hp
 E.apply(C,s,{{op='loseHp',value=3}},enemy,enemy)
 eq(enemy.hp,before-3);eq(s.player.hp,hp)
 print('PASS zero loss stays zero and enemy-owned HP_LOSS never borrows player Rod')
end
do
 local s=battle('bloodletting',3,true)
 assert(C.play(s,s.hand[1].uid));eq(s.player.hp,1)
 eq(s.potionInventory[1],'fairy_in_a_bottle');eq(s.player.damagedThisCombat,1)
 print('PASS one final Rod reduction prevents fatal payment and preserves physical Fairy')
end
do
 local s=battle('bloodletting',2,true)
 assert(C.play(s,s.hand[1].uid));eq(s.player.hp,24);eq(s.potionInventory[1],nil)
 eq(s.player.damagedThisCombat,1);eq(s.energy,5)
 print('PASS actual fatal remainder uses one Fairy then continues the card')
end
do
 local r=Run.new(D,42);local uids={}
 for _,c in ipairs(r.deck)do uids[#uids+1]=c.uid end
 for _,uid in ipairs(uids)do assert(Run.removeCard(r,uid))end
 assert(Run.obtainCard(r,'bloodletting'));assert(Run.obtainRelic(r,'tungsten_rod'))
 assert(Run.startCombat(r,'cultist_solo'))
 local s=r.combat;local card=s.hand[1];local before=C.copy(r)
 local player,hand,rng,misc,deck=s.player,s.hand,s.cardRandomRng,r.miscRng,r.deck
 local hook,observed=H.hpChanged,false
 H.hpChanged=function(state,actor,hp)
  hook(state,actor,hp)
  if state==s and actor==player then
   eq(hp-actor.hp,2);observed=true;error('ROD_CARD_LATE_FAILURE')
  end
 end
 local ok,why=pcall(Run.play,r,card.uid);H.hpChanged=hook
 assert(not ok and observed and tostring(why):find('ROD_CARD_LATE_FAILURE',1,true))
 same(r,before);eq(r.combat,s);eq(s.player,player);eq(s.hand,hand)
 eq(s.hand[1],card);eq(s.cardRandomRng,rng);eq(r.miscRng,misc);eq(r.deck,deck)
 assert(Run.play(r,card.uid));eq(s.player.hp,before.combat.player.hp-2)
 print('PASS public Run late failure restores values and original owners, then same UID retries')
end
print('TUNGSTEN_ROD_CARD_HP_LOSS_EDGES_PASS 6')
