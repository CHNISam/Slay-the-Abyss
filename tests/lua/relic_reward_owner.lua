-- Reward pointer ownership component: mutating a shared reward tail must retire its old gesture.
local Owner=require('abyss_battle_reward_owner')
local run={phase='reward',combat={turn=1},rewards={cards={'strike'},cardResolved=false,manualContinue=true,
 gold=10,goldClaimed=false,relics={{id='lantern',sourceId='Lantern',unavailable=false},{id='anchor',sourceId='Anchor',unavailable=false}}}}
local view={run=run,rewardScreen='list',rewardEpoch=1,rewardRender=1}
local token=Owner.capture({battle=run.combat},view,run)
assert(Owner.ready(view,token))
local tail=table.remove(run.rewards.relics)
assert(not Owner.ready(view,token),'removing a tail reward revived an old pointer token')
run.rewards.relics[#run.rewards.relics+1]=tail
assert(Owner.ready(view,token))
run.rewards.relics[#run.rewards.relics+1]={id='vajra',sourceId='Vajra',unavailable=false}
assert(not Owner.ready(view,token),'appending a reward failed to retire its old pointer token')
print('RELIC_REWARD_OWNER_PASS')
