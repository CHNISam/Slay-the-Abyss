-- Isolated interface probe, NOT a merge result or production patch.
package.path='source196/src/lua/?.lua;source196/build/lua/?.lua;source197/src/lua/?.lua;'..package.path
local C,Run,Map,Nodes196=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local E,Cap,R=require('abyss_effects'),require('abyss_card_capability'),require('abyss_sts_random')
local data=require('abyss_data')
local Shop196=require('abyss_shop')
local Shop197=dofile('source197/src/lua/abyss_shop.lua')
package.loaded.abyss_shop=Shop197
local Nodes197=dofile('source197/src/lua/abyss_nodes.lua')
package.loaded.abyss_shop=Shop196
local seeds=dofile('source196/tests/fixtures/warrior75-shop-seeds.lua')
local Routes=dofile('source196/tests/lua/support/map_routes.lua')
local function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function find(rows,id) for _,v in ipairs(rows)do if v.id==id then return v end end end
local function enter(run,map,kind,nodes)
 if run.nodeFlow and run.nodeFlow.complete then run.nodeFlow=nil end
 local path=Routes.to(map,function(node)return node.type==kind end)
 for i=1,#path-1 do assert(Map.choose(map,path[i]))end
 assert(nodes.enter(run,map,path[#path]))
end
local accepted,rejected=0,{}
for _,card in ipairs(data.cards.cards)do
 if card.type=='attack' or card.type=='skill' or card.type=='power' then
  if Cap.isImplemented(card)then accepted=accepted+1 else rejected[#rejected+1]=card.id end
 end
end
eq(accepted,73);eq(table.concat(rejected,','),'clash,whirlwind')
print('CAPABILITY cross196x197: 73/75 accepted; rejected='..table.concat(rejected,','))

for _,id in ipairs({'clash','whirlwind'})do
 local definition=find(data.cards.cards,id)
 eq(E.supported(definition.effects),true,id..' supported effects')
 for _,up in ipairs({false,true})do
  local state=C.new(data,{deck={{uid=1,cardId=id,upgraded=up}},enemies={'cultist'},seed=17})
  state.energy=3;state.enemies[1].hp=100;state.enemies[1].block=0;state.enemies[1].statuses={}
  eq(#state.hand,1);eq(C.canPlay(state,state.hand[1].uid,1),true)
  eq(C.play(state,state.hand[1].uid,1),true)
  local damage=id=='clash' and (up and 18 or 14) or (up and 24 or 15)
  eq(state.enemies[1].hp,100-damage);eq(state.energy,id=='clash' and 3 or 0)
  print('COMBAT196 '..id..(up and '+' or '')..': damage='..damage..', energy='..state.energy..'; Capability197=false')
 end
 local seed,slot=seeds[id].seed,seeds[id].slot
 local run,map=Run.new(data,seed),Map.generate(data,seed)
 enter(run,map,'shop',Nodes196)
 local offer=run.nodeFlow.cards[slot];eq(offer.id,id);eq(offer.unavailable,false)
 run.gold=offer.price -- Explicit funding fixture. Neither pool nor offer edited.
 eq(Nodes196.buyCardSlot(run,slot),true);local card=run.deck[#run.deck];eq(card.cardId,id)
 eq(Nodes196.leaveShop(run),true)
 enter(run,map,'camp',Nodes196)
 local cross=C.copy(run)
 local ok,why=Nodes197.upgrade(cross,card.uid)
 eq(ok,false);eq(why,'card_not_upgradeable');eq(cross.deck[#cross.deck].upgraded,false)
 local baseOk=Nodes196.upgrade(run,card.uid);eq(baseOk,true);eq(card.upgraded,true)
 print('PUBLIC SHOP196 -> CAMP '..id..': seed='..seed..', slot='..slot..', price='..offer.price..', uid='..card.uid..'; Nodes196=upgraded; Nodes197='..why)
end

-- One-variable diagnostic control only: it is not written to any source file
-- and is not a proposed production fix. Unknown conditions/cost modes are not enabled.
local original=Cap.isImplemented
local function provenCrossCard(card)
 if card and card.id=='clash' and card.condition=='only_attacks_in_hand' and not card.costMode then return E.supported(card.effects)==true end
 if card and card.id=='whirlwind' and card.costMode=='all_energy' and not card.condition then return E.supported(card.effects)==true end
 return original(card)
end
local found={}
for seed=1,100 do
 Cap.isImplemented=provenCrossCard
 local control=Shop197.prepare(Run.new(data,seed))
 Cap.isImplemented=original
 for _,offer in ipairs(control.cards)do
  if (offer.id=='clash' or offer.id=='whirlwind') and not found[offer.id] then
   local stock=Shop197.prepare(Run.new(data,seed))
   for _,x in ipairs(stock.cards)do assert(x.id~=offer.id)end
   found[offer.id]={seed=seed,slot=offer.slot,observed=stock.cards[offer.slot].id}
  end
 end
 if found.clash and found.whirlwind then break end
end
for _,id in ipairs({'clash','whirlwind'})do
 local f=assert(found[id],id..' missing diagnostic seed')
 -- Execute the public shop entry/purchase with the sole diagnostic difference.
 Cap.isImplemented=provenCrossCard
 local run,map=Run.new(data,f.seed),Map.generate(data,f.seed)
 enter(run,map,'shop',Nodes197)
 eq(run.nodeFlow.cards[f.slot].id,id);run.gold=run.nodeFlow.cards[f.slot].price
 eq(Nodes197.buyCardSlot(run,f.slot),true);eq(run.deck[#run.deck].cardId,id)
 Cap.isImplemented=original
 local blocked,blockedMap=Run.new(data,f.seed),Map.generate(data,f.seed)
 enter(blocked,blockedMap,'shop',Nodes197)
 for _,x in ipairs(blocked.nodeFlow.cards)do assert(x.id~=id)end
 print('PUBLIC SHOP197 causal control '..id..': seed='..f.seed..', slot='..f.slot..'; unchanged gate offers '..blocked.nodeFlow.cards[f.slot].id..'; proven-card-only diagnostic offers/buys '..id)
end
eq(Cap.isImplemented,original)
-- Gate's prototype safety remains explicit rather than deleting checks wholesale.
local unknown=C.copy(find(data.cards.cards,'strike'));unknown.condition='unknown_condition'
eq(Cap.isImplemented(unknown),false)
unknown.condition=nil;unknown.costMode='unknown_cost_mode';eq(Cap.isImplemented(unknown),false)
unknown.costMode=nil;unknown.effects={{op='not_implemented'}};eq(Cap.isImplemented(unknown),false)
for _,id in ipairs({'regret','dazed','slimed'})do eq(Cap.isImplemented(find(data.cards.cards,id)),true,id)end
print('SAFETY: unknown condition, unknown cost mode, unknown effect rejected; registered regret/dazed/slimed remain accepted')
print('RESULT: cross-PR capability incompatibility reproduced; no single-PR, merged-head or platform claim.')
