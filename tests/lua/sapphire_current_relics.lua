-- Current production only: real obtain, explicit open and linked key commands.
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local C,D,R=require('abyss_combat'),require('abyss_data'),require('abyss_sts_random')
local function same(a,b)
 if a==b then return end;assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local r=Run.new(D,'42',{experimental=true,campaign=true});r.endingUnlocked=true
assert(Run.obtainRelic(r,'Matryoshka'));assert(Run.obtainRelic(r,'Cursed Key'))
assert(r.relicCounters.matryoshka==2)
r.treasureRng=R.fromSeed('39') -- source Small/Common, no gold
local map=Map.generate(r.data,'42');local n=Map.available(map)[1]
for _,node in ipairs(map.nodes)do if node.id==n.id then node.type='treasure'end end
local deck,held=#r.deck,#r.relics
local cardBefore,poolBefore=C.copy(r.cardRng),C.copy(r.relicPool)
assert(Nodes.enter(r,map,n.id));assert(not r.nodeFlow.chest.opened)
same(r.cardRng,cardBefore);same(r.relicPool,poolBefore);assert(#r.deck==deck and r.relicCounters.matryoshka==2)
assert(Nodes.openTreasure(r));assert(#r.deck==deck+1 and #r.relics==held)
local curse=r.deck[#r.deck];local def
for _,d in ipairs(r.data.cards.cards)do if d.id==curse.cardId then def=d end end
assert(def and def.type=='curse');assert(r.cardRng.counter==cardBefore.counter+1)
assert(r.relicPool.rng.counter==poolBefore.rng.counter+1 and r.relicCounters.matryoshka==1)
local extra,base,key
for _,item in ipairs(r.nodeFlow.reward.items)do
 if item.origin=='matryoshka'then extra=item elseif item.origin=='base'then base=item elseif item.kind=='sapphire'then key=item end
end
assert(extra and base and key and #r.nodeFlow.reward.items==3)
assert(key.linkedSlot==base.slot and base.linkedSlot==key.slot and extra.linkedSlot==nil)
local token=assert(Nodes.treasureSource(r,map));local opened=C.copy(r)
local ok=Nodes.openTreasure(r);assert(not ok);same(r,opened)
assert(Nodes.chooseTreasure(r,map,token,'sapphire'));assert(r.keys.sapphire and not r.keys.ruby and not r.keys.emerald)
assert(#r.nodeFlow.reward.items==1 and r.nodeFlow.reward.items[1].slot==extra.slot)
same(r.cardRng,opened.cardRng);same(r.relicPool,opened.relicPool);same(r.treasureRng,opened.treasureRng)
assert(#r.deck==deck+1 and #r.relics==held and r.relicCounters.matryoshka==1)
local afterKey=C.copy(r);assert(not Nodes.chooseTreasure(r,map,token,'relic'));same(r,afterKey)
local reward=assert(Nodes.treasureRewardSource(r,extra.slot));assert(Nodes.claimTreasureReward(r,reward))
assert(#r.relics==held+1 and r.relics[#r.relics]==extra.id)
assert(#r.deck==deck+1 and r.keys.sapphire and r.relicCounters.matryoshka==1)
print('SAPPHIRE_CURRENT_RELICS_PASS')
