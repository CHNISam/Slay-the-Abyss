package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Actions,R,Flow=require('abyss_run'),require('abyss_combat'),require('abyss_card_actions'),require('abyss_sts_random'),require('abyss_flow_actions')
local D=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh()
 local r=Run.new(D,42,{character='watcher',experimental=true})
 -- The real Run catalogue already owns foreign Fire Breathing; do not apply
 -- the historical raw-red adapter a second time to an adapted full catalogue.
 assert(r.data.runCardCatalog)
 r.relics[#r.relics+1]='toy_ornithopter';assert(Run.obtainPotion(r,'stance_potion'));assert(Run.startCombat(r,'cultist_solo'))
 r.hp=r.hp-30;r.combat.player.hp=r.hp;return r
end
local function play(r,id)
 local c=Actions.fresh(C,r.combat,id);Actions.toHand(r.combat,c);assert(Run.play(r,c.uid))
end
local function use(r,stance)
 assert(Run.usePotion(r,1));local p=r.combat.pendingPotionChoice
 assert(Run.choosePotionStance(r,{stance},p.token,r.combatGeneration,r.combat));return p
end
local r=fresh();play(r,'mental_fortress');play(r,'rushdown');use(r,'Calm')
assert(Run.obtainPotion(r,'stance_potion'));assert(Run.usePotion(r,1))
local s=r.combat;local flurry=Actions.fresh(C,s,'flurry_of_blows');s.discard[#s.discard+1]=flurry
local p,queue,hand,draw,discard=s.pendingPotionChoice,s.actionQueue,s.hand,s.draw,s.discard
local hp,energy,block,events,counter,master,handCount=s.player.hp,s.energy,s.player.block,#s.events,R.snapshot(s.cardRandomRng),#r.deck,#s.hand
local original=Flow.enqueue;local reached=false
Flow.enqueue=function(candidate,plan,q)
 original(candidate,plan,q)
 if plan.move and plan.move.cardId=='flurry_of_blows'then
  eq(candidate.player.stance,'Wrath');eq(candidate.player.hp,hp+5);eq(candidate.energy,energy+2);eq(candidate.player.block,block+4)
  reached=true;error('INJECTED_LATE_POTION_FLURRY')
 end
end
eq(Run.choosePotionStance(r,{'Wrath'},p.token,r.combatGeneration,s),false);Flow.enqueue=original;eq(reached,true)
eq(r.combat,s);eq(s.pendingPotionChoice,p);eq(s.actionQueue,queue);eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard)
eq(s.player.hp,hp);eq(r.hp,hp);eq(s.energy,energy);eq(s.player.block,block);eq(#s.events,events);eq(r.potions[1],nil);eq(s.player.stance,'Calm')
eq(s.cardRandomRng.counter,counter.counter);for i=1,2 do eq(R.snapshot(s.cardRandomRng).words[i],counter.words[i])end
assert(Run.choosePotionStance(r,{'Wrath'},p.token,r.combatGeneration,s));eq(s.pendingPotionChoice,nil);eq(s.actionQueue,nil);eq(#r.deck,master)
eq(s.player.hp,hp+5);eq(s.energy,energy+2);eq(s.player.block,block+4);eq(#s.hand,handCount+3)
local heal,stance;for i=events+1,#s.events do
 local event=s.events[i];if event.kind=='heal'then heal=i;eq(event.frame.player.stance,'Calm')elseif event.kind=='stance'then stance=i end
end
assert(heal and stance and heal<stance)
local found=false;for _,card in ipairs(s.hand)do if card.uid==flurry.uid then found=true end end;eq(found,true)
eq(Run.choosePotionStance(r,{'Wrath'},p.token,r.combatGeneration,s),false)
print('ok actual Calm/Rushdown/MentalFortress/Flurry, Toy before change, complete Run late rollback preserves consumed-bottle choice and retry')
local kill=fresh();play(kill,'rushdown');play(kill,'fire_breathing');local b=kill.combat
for _=1,2 do b.draw[#b.draw+1]=Actions.fresh(C,b,'burn')end
b.enemies[1].hp=5 -- Local death-order fixture, not a natural encounter claim.
assert(Run.usePotion(kill,1));local pending=b.pendingPotionChoice;local prior=C.copy(kill)
local finish=Run.finishCombat;local rewardReached=false
Run.finishCombat=function(candidate)
 local ok,why=finish(candidate);assert(ok,why);eq(candidate.phase,'reward');rewardReached=true;error('INJECTED_AFTER_POTION_REWARDS')
end
eq(Run.choosePotionStance(kill,{'Wrath'},pending.token,kill.combatGeneration,b),false);Run.finishCombat=finish;eq(rewardReached,true)
local function same(a,z)
 eq(type(a),type(z));if type(a)~='table'then eq(a,z);return end
 for k,v in pairs(a)do same(v,z[k])end;for k in pairs(z)do assert(a[k]~=nil)end
end
same(kill,prior);eq(kill.combat,b);eq(b.pendingPotionChoice,pending);eq(kill.potions[1],nil)
assert(Run.choosePotionStance(kill,{'Wrath'},pending.token,kill.combatGeneration,b))
eq(kill.phase,'reward');eq(b.pendingPotionChoice,nil);eq(b.pendingPlay,nil);eq(b.actionQueue,nil)
eq(b.enemies[1].hp,0);eq(b.player.statuses.fire_breathing,6);eq(b.player.stance,'Wrath')
if kill.rewards.potion then assert(Run.skipPotionReward(kill))end
assert(Run.claimCardReward(kill,0));dofile('tests/lua/support/finish_combat_rewards.lua')(kill)
eq(kill.phase,'map');eq(Run.choosePotionStance(kill,{'Wrath'},pending.token,kill.combatGeneration,b),false)
print('CLASS_POTION_STANCE_QUEUE_PASS real foreign FireBreathing plus Rushdown status draws kill final enemy and settle through public rewards')
