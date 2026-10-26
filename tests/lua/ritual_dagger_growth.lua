package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run');local C=require('abyss_combat');local data=require('abyss_data')
local Actions=require('abyss_card_actions')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local r=Run.new(data,42);r.deck={{uid=31,cardId='ritual_dagger',upgraded=false}};r.relics={}
assert(Run.startCombat(r,'louse_pair'))
local card=r.combat.hand[1];eq(r.combat.enemies[1].hp,13)
local same=C.copy(card);r.combat.draw[#r.combat.draw+1]=same
assert(Run.play(r,card.uid,1));eq(r.deck[1].misc,18);eq(same.misc,18)
assert(not Run.play(r,card.uid,1));eq(r.deck[1].misc,18)
assert(Run.obtainPotion(r,'smoke_bomb'));assert(Run.usePotion(r,1));eq(r.phase,'map');eq(r.deck[1].misc,18)
assert(Run.startCombat(r,'cultist_solo'));eq(C.cardDefinition(r.combat,r.combat.hand[1]).effects[1].damage,18)
local function chaos(choice)
 local run=Run.new(data,42);run.relics={}
 run.deck={{uid=31,cardId='ritual_dagger',upgraded=false}}
 if choice then
  for i,id in ipairs({'thinking_ahead','good_instincts','defend','defend'})do run.deck[#run.deck+1]={uid=31+i,cardId=id,upgraded=false}end
 end
 assert(Run.startCombat(run,'louse_pair'))
 local byUid={};for _,pile in ipairs({run.combat.hand,run.combat.draw})do for _,c in ipairs(pile)do byUid[c.deckUid]=c end end
 run.combat.hand={}
 run.combat.draw=choice and {byUid[34],byUid[35],byUid[33],byUid[31],byUid[32]}or {byUid[31]}
 assert(Run.obtainPotion(run,'distilled_chaos'));return run
end
r=chaos(false);assert(Run.usePotion(r,1));eq(r.phase,'combat');eq(r.deck[1].misc,18);assert(not r.combat.ritualDaggerGrowth)
r=chaos(true);assert(Run.usePotion(r,1));assert(r.combat.pendingChoice);eq(r.deck[1].misc,nil)
local p=r.combat.pendingChoice;assert(Run.chooseCard(r,p.token,p.uids[1]));eq(r.deck[1].misc,18);assert(not r.combat.ritualDaggerGrowth)
r=chaos(false);local ok=Run.usePotion(r,1,nil,function(candidate)Actions.drain(C,candidate);error('intentional post-use failure')end)
assert(not ok);eq(r.deck[1].misc,nil);eq(r.potions[1],'distilled_chaos');eq(r.combat.enemies[1].hp,13);eq(r.combat.enemies[2].hp,13)
print('ok Ritual Dagger commits at accepted commands, updates same UUID, and survives natural Smoke escape')
