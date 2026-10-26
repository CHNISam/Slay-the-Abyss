-- Independent fixed 319009d5 DiscoveryAction: src pools, duplicate rejection,
-- HEALING exclusion, one choice and zero-cost stat-equivalent temporary copies.
local M={}
function M.pool(state,kind,exclude)
 local groups={}
 if kind=='colorless' then
  if state.sourcePools.srcColorless then groups={state.sourcePools.srcColorless}
  else groups={state.sourcePools.colorless.uncommon,state.sourcePools.colorless.rare}end
 else
  for _,rarity in ipairs({'common','uncommon','rare'})do groups[#groups+1]=state.sourcePools.src[rarity]end
 end
 local result={}
 for _,ids in ipairs(groups)do for _,id in ipairs(ids)do
  local d=assert(state.catalog.cards[id],'missing discovery card '..id)
  if not d.healing and (kind==nil or kind=='colorless' or d.type==kind) and id~=exclude then result[#result+1]=id end
 end end
 assert(#result>=3,'incomplete discovery source pool')
 return result
end
local function generate(combat,state,e)
 local pool=M.pool(state,e.kind,e.exclude)
 local cards,used={},{}
 while #cards<3 do
  local id=pool[combat.cardRandom(state,#pool)]
  if not used[id]then used[id]=true;cards[#cards+1]={uid=#cards+1,cardId=id,upgraded=false}end
 end
 return cards
end
function M.begin(combat,state,e)
 assert(e.value==1 or e.value==2,'invalid discovery count')
 assert(not state.pendingChoice,'discovery choice already pending')
 state.choiceSerial=(state.choiceSerial or 0)+1
 state.pendingChoice={op='discover',token=state.choiceSerial,uids={1,2,3},cards=generate(combat,state,e),effect=e,turn=state.turn}
 require('abyss_events').emit(state,'card_choice',{op='discover',token=state.choiceSerial})
end
function M.choose(combat,state,token,index,actions)
 local p=state.pendingChoice
 if not p or p.op~='discover' or p.token~=token or p.turn~=state.turn then return false,'stale_card_choice'end
 if type(index)~='number' or index%1~=0 or not p.cards[index] then return false,'invalid_card_choice'end
 -- The action constructs another (unused) group on its retrieval update.
 generate(combat,state,p.effect)
 for _=1,p.effect.value do
  local card=actions.fresh(combat,state,p.cards[index].cardId)
  if (state.player.statuses.master_reality or 0)>0 and combat.canUpgrade(state,card)then combat.upgrade(state,card)end
  card.costForTurn=0
  actions.toHand(state,card)
 end
 state.pendingChoice=nil
 require('abyss_events').emit(state,'card_choice_resolved',{op='discover',cardId=p.cards[index].cardId})
 return true
end
return M
