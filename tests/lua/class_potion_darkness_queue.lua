package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,R,P=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_sts_random'),require('abyss_class_potions')
local D=C.copy(require('abyss_data'))
D.enemies.encounters[#D.enemies.encounters+1]={id='darkness_pair_fixture',tier='normal',minFloor=1,maxFloor=16,enemies={'cultist','cultist'}}
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(pair)
 local r=Run.new(D,42,{character='defect',experimental=true});r.relics[#r.relics+1]='toy_ornithopter'
 assert(Run.obtainPotion(r,'essence_of_darkness'));assert(Run.startCombat(r,pair and 'darkness_pair_fixture'or 'cultist_solo'))
 r.hp=r.hp-10;r.combat.player.hp=r.hp;return r
end
local r=fresh();local s=r.combat;local hp,energy,rng=s.player.hp,s.energy,s.cardRandomRng.counter
s.orbs.balls={{kind='lightning'},{kind='frost'},{kind='plasma'}};s.enemies[1].hp=1
assert(Run.usePotion(r,1));eq(r.phase,'reward');eq(r.combat,s);eq(#s.orbs.balls,0);eq(s.orbChannelCounts.dark,0)
eq(s.player.block,5);eq(s.energy,energy+2);eq(s.player.hp,hp+5);eq(s.cardRandomRng.counter,rng+1);eq(r.potions[1],nil)
local order={};for _,e in ipairs(s.events)do
 if e.kind=='orb_effect'then order[#order+1]=e.detail.orb elseif e.kind=='heal'then order[#order+1]='toy'end
end
eq(table.concat(order,','),'lightning,frost,plasma,toy')
print('ok first full-slot evoke kills final enemy: queued DAMAGE evokes remove Frost/Plasma, block/energy survive, channels clear, Toy last')
local pair=fresh(true);local b=pair.combat;b.orbs.balls={{kind='dark',stored=8},{kind='frost'},{kind='lightning'}}
b.enemies[1].hp=10;b.enemies[2].hp=100
A.applyPower(b,b.enemies[1],'lock_on',1,b.player);A.applyPower(b,b.enemies[1],'vulnerable',3,b.player)
A.applyPower(b,b.player,'weak',3,b.player);A.applyPower(b,b.player,'strength',10,b.player)
local counter=b.cardRandomRng.counter;assert(Run.usePotion(pair,1));eq(pair.phase,'combat')
eq(b.enemies[1].hp,0);eq(b.enemies[2].hp,92);eq(b.player.block,5);eq(b.cardRandomRng.counter,counter+1)
eq(#b.orbs.balls,3);eq(b.orbChannelCounts.dark,3);for _,ball in ipairs(b.orbs.balls)do eq(ball.kind,'dark');eq(ball.stored,6)end
print('ok nonfinal death continues source channels, Dark lowest HP/LockOn and fixed orb damage ignores Strength/Weak/Vulnerable')
local p=fresh();local old=p.combat;old.orbs.slots=2;old.orbs.balls={{kind='lightning'},{kind='invalid'}}
local pots,orbs,cardRng=p.potions,old.orbs,old.cardRandomRng
local before={hp=old.enemies[1].hp,life=old.player.hp,energy=old.energy,events=#old.events,nextUid=old.nextUid,card=R.snapshot(cardRng),potion=R.snapshot(old.potionRng)}
local original=P.darkness;local reached=false
P.darkness=function(combat,candidate,effect,queue)
 local ok,why=pcall(original,combat,candidate,effect,queue)
 if not ok then
  eq(candidate.enemies[1].hp,before.hp-8);eq(candidate.cardRandomRng.counter,before.card.counter+1);eq(candidate.orbChannelCounts.dark,1)
  reached=true;error(why)
 end
 return why
end
eq(Run.usePotion(p,1),false);P.darkness=original;eq(reached,true)
eq(p.combat,old);eq(p.potions,pots);eq(p.potions[1],'essence_of_darkness');eq(old.orbs,orbs);eq(old.cardRandomRng,cardRng)
eq(old.enemies[1].hp,before.hp);eq(old.player.hp,before.life);eq(old.energy,before.energy);eq(#old.events,before.events);eq(old.nextUid,before.nextUid)
for i=1,2 do eq(R.snapshot(cardRng).words[i],before.card.words[i]);eq(R.snapshot(old.potionRng).words[i],before.potion.words[i])end
eq(cardRng.counter,before.card.counter);eq(old.potionRng.counter,before.potion.counter);eq(old.orbChannelCounts.dark,0);eq(old.actionQueue,nil)
print('CLASS_POTION_DARKNESS_QUEUE_PASS late second-evoke failure rolls back damage, history, bottle, object owners and RNG words')
