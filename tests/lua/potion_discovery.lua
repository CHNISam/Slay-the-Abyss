package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Data,R=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local count=0
for _,kind in ipairs({'attack','skill','power'})do
 local r=Run.new(Data,42);assert(Run.obtainPotion(r,kind..'_potion'));assert(Run.startCombat(r,'cultist_solo'))
 local permanent=#r.deck;local before=R.snapshot(r.combat.cardRandomRng).counter
 assert(Run.usePotion(r,1));local s=r.combat;local p=assert(s.pendingChoice)
 eq(p.op,'discover');eq(#p.cards,3);eq(r.potions[1],nil);eq(#r.deck,permanent)
 local used={};for _,card in ipairs(p.cards)do local d=s.catalog.cards[card.cardId];eq(d.type,kind);assert(not d.healing);assert(not used[card.cardId]);used[card.cardId]=true end
 assert(R.snapshot(s.cardRandomRng).counter>before)
 local token=p.token;local chosen=p.cards[2].cardId;local uid=s.nextUid;local hand=#s.hand
 eq(Run.chooseCard(r,token,999),false);eq(s.pendingChoice,p)
 assert(Run.chooseCard(r,token,2));eq(#s.hand,hand+1);eq(s.hand[#s.hand].cardId,chosen);eq(s.hand[#s.hand].uid,uid);eq(s.hand[#s.hand].costForTurn,0)
 eq(Run.chooseCard(r,token,2),false);eq(#r.deck,permanent)
 count=count+1
end
-- Actual source pools retain Feed/Reaper/Regen-related HEALING exclusion,
-- use the complete typed pool without rarity or implementation filtering.
local D=require('abyss_potion_discovery')
local r=Run.new(Data,42);assert(Run.startCombat(r,'cultist_solo'))
local pool=D.pool(r.combat,'attack');local seen={};for _,id in ipairs(pool)do seen[id]=true end
assert(not seen.feed and not seen.reaper and seen.anger and seen.bludgeon)
-- Full hand spills selected zero-cost copy into discard; Bark makes two
-- separate UIDs and never inserts them in the permanent deck.
for _,size in ipairs({9,10})do
 local r=Run.new(Data,42);assert(Run.obtainPotion(r,'attack_potion'));assert(Run.startCombat(r,'cultist_solo'));r.relics[#r.relics+1]='sacred_bark'
 local s=r.combat;while #s.hand<size do s.hand[#s.hand+1]=table.remove(s.draw)end
 local discard=#s.discard;local uid=s.nextUid;assert(Run.usePotion(r,1));local p=s.pendingChoice
 assert(Run.chooseCard(r,p.token,1));eq(#s.hand,10);eq(#s.discard,discard+(size==9 and 1 or 2));eq(s.nextUid,uid+2)
 count=count+1
end
print('LUA_POTION_DISCOVERY_PASS '..count)
