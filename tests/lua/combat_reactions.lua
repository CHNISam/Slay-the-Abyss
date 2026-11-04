local Cards=require('abyss_card_actions')
local Queue=require('abyss_action_queue')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
-- This fixture runs against both the original implementation and its extraction.
for _,typed in ipairs({false,true})do
 local player,source,target,instance={},{},{},{}
 local state={player=player};local old={op='draw',value=1}
 if typed then Queue.start(state,{{kind='effect',effect=old}})end
 local effect={op='draw',value=2}
 eq(Cards.enqueue(state,effect,source,target,instance),nil)
 local item=state.cardActions[1]
 eq(item.effect,effect);eq(item.source,source);eq(item.target,target);eq(item.instance,instance)
 eq(Cards.enqueueReaction(state,effect,true),nil)
 eq(Cards.enqueueReaction(state,old,false),nil)
 if typed then
  eq(#state.cardActions,1);eq(state.actionQueue.actions[1].effect,effect)
  eq(state.actionQueue.actions[2].effect,old);eq(state.actionQueue.actions[3].effect,old)
  eq(state.actionQueue.paused,false)
  local bad={op='draw',callback=function()end};local n=#state.actionQueue.actions
  assert(not pcall(Cards.enqueueReaction,state,bad));eq(#state.actionQueue.actions,n)
 else
  eq(#state.cardActions,3);eq(state.cardActions[1].effect,effect)
  eq(state.cardActions[1].source,player);eq(state.cardActions[2],item);eq(state.cardActions[3].effect,old)
 end
end
local old=Cards.enqueue;local called=0
Cards.enqueue=function(...)called=called+1;return old(...)end
Cards.enqueueReaction({player={}},{op='draw',value=1});eq(called,1);Cards.enqueue=old
print('COMBAT_REACTIONS_PASS')
