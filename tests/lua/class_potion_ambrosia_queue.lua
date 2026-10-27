package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Actions,R=require('abyss_run'),require('abyss_combat'),require('abyss_card_actions'),require('abyss_sts_random')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh()
 local r=Run.new(Data,42,{character='watcher',experimental=true})
 r.relics[#r.relics+1]='toy_ornithopter';assert(Run.obtainPotion(r,'ambrosia'));assert(Run.startCombat(r,'cultist_solo'))
 r.hp=r.hp-10;r.combat.player.hp=r.hp;return r
end
local r=fresh();local s=r.combat;local before=#s.events;local hp=s.player.hp;local energy=s.energy
assert(Run.usePotion(r,1));eq(s.player.hp,hp+5);eq(s.energy,energy+3)
local relevant={};for i=before+1,#s.events do
 local e=s.events[i];if e.kind=='stance'or e.kind=='heal'or e.kind=='potion'then relevant[#relevant+1]=e end
end
eq(#relevant,3);eq(relevant[1].kind,'stance');eq(relevant[2].kind,'heal');eq(relevant[3].kind,'potion')
eq(relevant[2].frame.player.stance,'Divinity');eq(relevant[2].frame.energy,energy);eq(relevant[3].frame.player.hp,hp+5);eq(relevant[3].frame.energy,energy+3)
eq(s.pendingPlay,nil);eq(s.actionQueue,nil);eq(s.stanceQueue,nil)
print('ok real Ambrosia transition -> Toy heal -> queued entry energy, no pendingPlay')
-- An invalid hand-cap dependency fails only in the final Flurry movement,
-- after the staged stance transition, Toy heal and entry energy succeeded.
local p=fresh();local b=p.combat;local c=Actions.fresh(C,b,'flurry_of_blows');b.discard[#b.discard+1]=c;b.rules.player.maxHand='invalid'
local potion,events,life,power,uid,phase=p.potions,#b.events,b.player.hp,b.energy,b.nextUid,b.player.stance
local rng=R.snapshot(b.potionRng);local resolve=C.resolvePotionActions;local reached=false
C.resolvePotionActions=function(candidate,effects)
 local ok,why=pcall(resolve,candidate,effects)
 if not ok then
  eq(candidate.player.stance,'Divinity');eq(candidate.player.hp,life+5);eq(candidate.energy,power+3);reached=true;error(why)
 end
end
eq(Run.usePotion(p,1),false);C.resolvePotionActions=resolve;eq(reached,true)
eq(p.combat,b);eq(p.potions,potion);eq(p.potions[1],'ambrosia');eq(#b.events,events);eq(b.player.hp,life);eq(b.energy,power)
eq(b.nextUid,uid);eq(b.player.stance,phase);eq(b.discard[1],c);eq(R.snapshot(b.potionRng).counter,rng.counter);eq(b.actionQueue,nil)
print('ok final Flurry failure rolls back preceding stance, Toy healing, energy, events and bottle')
local q=fresh();local battle=q.combat
local candidate=C.copy(battle);require('abyss_action_queue').start(candidate,{})
local busy=candidate.actionQueue;eq(pcall(C.resolvePotionActions,candidate,{{op='changeStance',stance='Divinity'}}),false)
eq(candidate.actionQueue,busy);eq(candidate.player.stance,'Neutral');eq(q.combat,battle);eq(q.potions[1],'ambrosia')
print('CLASS_POTION_AMBROSIA_QUEUE_PASS explicit reentry refusal and entire Run snapshot')
