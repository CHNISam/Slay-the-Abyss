local Nob=require('abyss_gremlin_nob_ai')
local Cards=require('abyss_card_actions')
local Queue=require('abyss_action_queue')
for _,typed in ipairs({false,true})do
 local first={hp=10,statuses={enrage=2}}
 local second={hp=20,statuses={enrage=3}}
 local dead={hp=0,statuses={enrage=5}}
 local rng={seed=42}
 local s={player={},enemies={first,second,dead},rng=rng,events={}}
 if typed then Queue.start(s,{{kind='effect',effect={op='sentinel'}}})end
 local typedQueue=s.actionQueue;local typedItem=typedQueue and typedQueue.actions[1]
 local original=Cards.enqueue;local seen={}
 Cards.enqueue=function(state,effect,source,target,instance,top)
  assert(state==s and target==nil and instance==nil and top==true,'legacy admission contract')
  seen[#seen+1]=source;return original(state,effect,source,target,instance,top)
 end
 Nob.beforeCard(s,{type='attack'});assert(#seen==0)
 Nob.beforeCard(s,{type='skill'});Cards.enqueue=original
 assert(#seen==2 and seen[1]==first and seen[2]==second,'live owner iteration')
 assert(#s.cardActions==2 and s.cardActions[1].source==second and s.cardActions[2].source==first,'TOP owner order')
 assert(s.cardActions[1].effect.value==3 and s.cardActions[2].effect.value==2,'Enrage amounts')
 assert(s.actionQueue==typedQueue and s.rng==rng and rng.seed==42 and #s.events==0,'no drain or RNG')
 if typed then assert(#typedQueue.actions==1 and typedQueue.actions[1]==typedItem and typedQueue.paused==false,'typed queue unchanged')end
end
print('NOB_REACTION_ADMISSION_PASS')
