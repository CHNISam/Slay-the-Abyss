-- Discovery.use adds DiscoveryAction before the later UseCardAction. Both
-- existing action owners must pause without exhausting or generating early.
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local count=0
for _,kind in ipairs({'native','shared'})do
 local r=Run.new(D,'42',kind=='shared'and {character='watcher',experimental=true}or nil)
 local uids={};for _,card in ipairs(r.deck)do uids[#uids+1]=card.uid end
 for _,uid in ipairs(uids)do assert(Run.removeCard(r,uid))end
 assert(Run.obtainCard(r,'discovery'));assert(Run.startRoomCombat(r,'normal'))
 local s=r.combat;eq(s.enemies[1].hp,52)
 -- Source PureWater.atBattleStartPreDraw preserves the Watcher's Miracle.
 local initialHand=kind=='shared'and 2 or 1;eq(#s.hand,initialHand)
 local card,miracle;for _,c in ipairs(s.hand)do if c.cardId=='discovery'then card=c elseif c.cardId=='miracle'then miracle=c end end
 assert(card);eq(miracle~=nil,kind=='shared');local permanent=#r.deck;local energy=s.energy
 assert(Run.play(r,card.uid));eq(r.phase,'combat');eq(s.enemies[1].hp,52)
 local p=assert(s.pendingChoice);eq(p.op,'discover');eq(#p.cards,3)
 eq(#s.exhaust,0);eq(s.cardInUse,card);eq(s.nextUid,initialHand+1);eq(s.energy,energy-1)
 local owner=s.actionQueue;eq(owner~=nil,kind=='shared')
 if owner then eq(owner.paused,true);eq(s.cardActions,nil)else assert(s.cardActions)end
 local hand,draw,discard,rng=s.hand,s.draw,s.discard,s.cardRandomRng
 local nextUid=s.nextUid;local chosen=p.cards[2].cardId
 eq(Run.chooseCard(r,p.token,999),false);eq(s.pendingChoice,p);eq(s.actionQueue,owner)
 eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard);eq(s.cardRandomRng,rng);eq(s.nextUid,nextUid)
 assert(Run.chooseCard(r,p.token,2));eq(r.phase,'combat');eq(s.enemies[1].hp,52)
 eq(#s.exhaust,1);eq(s.exhaust[1],card);eq(#s.hand,initialHand);local generated=s.hand[#s.hand];eq(generated.cardId,chosen)
 eq(generated.uid,nextUid);eq(generated.costForTurn,0);if miracle then eq(s.hand[1],miracle)end;eq(#r.deck,permanent)
 eq(s.actionQueue,nil);eq(s.cardActions,nil);eq(s.pendingChoice,nil);eq(s.pendingPlay,nil);eq(s.cardInUse,nil)
 eq(Run.chooseCard(r,p.token,2),false);eq(#s.hand,initialHand);eq(#s.exhaust,1)
 count=count+1;print('PASS Discovery '..kind..' actual Run play/choice pauses before disposal and resumes once')
end
print('DISCOVERY_ACTION_OWNER '..count..' passed')
