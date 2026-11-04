local R=require('abyss_combat_reactions')
for _,name in ipairs({'abyss_actor','abyss_card_actions','abyss_combat'})do assert(package.loaded[name]==nil,name)end
local Queue=require('abyss_action_queue')
local state={player={}};Queue.start(state,{})
local effect={op='draw',value=1};R.enqueueReaction(state,effect)
assert(state.cardActions==nil);assert(state.actionQueue.actions[1].effect==effect)
local Cards=require('abyss_card_actions')
for _,key in ipairs({'enqueue','enqueueReaction'})do
 local old=Cards[key];assert(old==R[key]);Cards[key]=nil;assert(Cards[key]==nil and R[key]==nil)
 Cards[key]=old;assert(Cards[key]==old and R[key]==old)
end
Cards.probe=42;assert(rawget(Cards,'probe')==42 and R.probe==nil)
Cards.probe=nil;assert(rawget(Cards,'probe')==nil)
local old=Cards.enqueueReaction;local called=0
Cards.enqueueReaction=function(...)called=called+1;return old(...)end
R.enqueueReaction({player={}},{op='draw',value=1});assert(called==1)
Cards.enqueueReaction=old
print('COMBAT_REACTIONS_INDEPENDENCE_PASS')
