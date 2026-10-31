-- TEST_ADDED: public command coverage of already implemented source mechanics.
-- Controlled deck/HP and map-room inputs, not natural acquisition/play evidence.
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local D=require('abyss_data')
local function deck(r,id,count)
 r.deck={};for i=1,count do r.deck[i]={uid=i,cardId=id,upgraded=false}end;r.nextDeckUid=count+1
end
local function camp(r,m)
 local first=assert(Nodes.available(r,m)[1]);for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='camp' end end
 assert(Nodes.enter(r,m,first.id));return first.id
end
-- EternalFeather.onEnterRoom: integer groups of five master cards heal three.
-- Literal boundary expectations are independent of the production formula.
for _,case in ipairs({{0,0},{4,0},{5,3},{9,3},{10,6},{14,6},{15,9}})do
 local r,m=Run.new(D,42),Map.generate(D,42)
 assert(Run.obtainRelic(r,'Eternal Feather'));deck(r,'defend',case[1]);r.hp=20
 local id=camp(r,m);assert(r.hp==20+case[2],'Feather camp-entry amount')
 Nodes.view(r,m);Nodes.view(r,m);assert(r.hp==20+case[2],'view must not heal')
 assert(not Nodes.enter(r,m,id) and r.hp==20+case[2],'re-enter current camp must not heal')
 assert(Nodes.rest(r));assert(r.hp==44+case[2],'rest heals24 without repeating Feather')
 assert(not Nodes.rest(r) and r.hp==44+case[2],'repeat rest must refuse')
end
local r,m=Run.new(D,42),Map.generate(D,42)
assert(Run.obtainRelic(r,'Eternal Feather'));assert(Run.obtainRelic(r,'Mark of the Bloom'));r.hp=20
camp(r,m);assert(r.hp==20);assert(Nodes.rest(r) and r.hp==20,'Bloom blocks entry and rest healing')
print('M3_RELIC_PUBLIC_FEATHER_PASS 8')
-- LetterOpener.onUseCard: every third actual skill queues fixed5 to all;
-- atTurnStart resets partial count and fresh combat cannot inherit it.
r=Run.new(D,42);assert(Run.obtainRelic(r,'Letter Opener'));deck(r,'defend',10)
assert(Run.obtainPotion(r,'explosive_potion'));assert(Run.startCombat(r,'louse_pair'))
local function playSkill()
 local uid;for _,c in ipairs(r.combat.hand)do if c.cardId=='defend'then uid=c.uid;break end end
 assert(uid,'controlled all-skill deck must supply a card');assert(Run.play(r,uid))
end
local function hp()local t={};for i,e in ipairs(r.combat.enemies)do t[i]=e.hp end;return t end
local function unchanged(before)for i,e in ipairs(r.combat.enemies)do assert(e.hp==before[i])end end
local function minusFive(before)for i,e in ipairs(r.combat.enemies)do assert(e.hp==before[i]-5,'third skill must damage every enemy by5')end end
local before=hp();playSkill();unchanged(before);playSkill();unchanged(before);playSkill();minusFive(before)
assert(Run.endTurn(r));before=hp();playSkill();unchanged(before);playSkill();unchanged(before)
assert(r.combat.relicCounters.letter_opener==2)
-- Two skills on preceding turn must not turn the next turn's first into third.
assert(Run.endTurn(r));before=hp();playSkill();unchanged(before)
-- Kill through real potion command, preserving the partial skill counter as input.
assert(Run.usePotion(r,1));assert(r.phase=='reward')
assert(Run.claimCardReward(r,0));dofile('tests/lua/support/finish_combat_rewards.lua')(r)
assert(Run.startCombat(r,'louse_pair'));before=hp();playSkill();unchanged(before);playSkill();unchanged(before);playSkill();minusFive(before)
print('M3_RELIC_PUBLIC_LETTER_PASS turn-and-combat-reset')
