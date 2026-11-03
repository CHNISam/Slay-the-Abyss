-- Reward pointer ownership component: mutating a shared reward tail must retire its old gesture.
-- This leaf only needs graph copying; loading it must not initialize Combat.
assert(package.loaded.abyss_combat==nil,'reward owner fixture must start without Combat')
local oldLoader=package.preload.abyss_combat
package.preload.abyss_combat=function()error('COPY_ONLY_OWNER_LOADED_COMBAT')end
local loaded,Owner=pcall(require,'abyss_battle_reward_owner')
package.preload.abyss_combat=oldLoader
assert(loaded,Owner)
assert(package.loaded.abyss_combat==nil,'reward owner unexpectedly loaded Combat')
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

-- Copy each reward graph privately, preserving aliases/cycles inside that graph.
local shared={count=3};shared.self=shared
run.rewards.relics={
 {id='lantern',sourceId='Lantern',meta=shared},
 {id='anchor',sourceId='Anchor',meta=shared},
}
run.rewards.cardUpgrades={true}
run.rewards.emeraldKey={available=true}
local originalRelics,originalCards=run.rewards.relics,run.rewards.cards
token=Owner.capture({battle=run.combat},view,run)
assert(Owner.ready(view,token),'valid captured reward should remain usable')
assert(token.relics==originalRelics and token.cards==originalCards,'live ownership identities changed')
assert(token.relicState~=originalRelics and token.relicState[1]~=originalRelics[1])
assert(token.relicState[1].meta~=shared and token.relicState[1].meta==token.relicState[2].meta)
assert(token.relicState[1].meta.self==token.relicState[1].meta,'snapshot lost its cycle')
assert(token.cardChoices~=originalCards and token.cardChoices[1]=='strike')
assert(token.cardUpgrades~=run.rewards.cardUpgrades and token.cardUpgrades[1]==true)
assert(token.emeraldState~=run.rewards.emeraldKey and token.emeraldState.available==true)
assert(run.rewards.relics==originalRelics and originalRelics[1].meta==shared and shared.self==shared)
local again=Owner.capture({battle=run.combat},view,run)
assert(again.relicState[1].meta~=token.relicState[1].meta,'captures must not share private graphs')
token.relicState[1].meta.count=99
assert(shared.count==3 and again.relicState[1].meta.count==3,'snapshot mutation escaped its owner')

for _,mutation in ipairs({
 {run.rewards,'gold',20}, {run.rewards,'goldClaimed',true},
 {run.rewards.cards,1,'defend'}, {run.rewards.cardUpgrades,1,false},
 {run.rewards.relics[1],'claimed',true}, {run.rewards.relics[1],'unavailable',true},
 {run.rewards.emeraldKey,'available',false}, {view,'rewardEpoch',2},
 {view,'rewardScreen','cards'}, {run,'combat',{}}, {run,'phase','map'},
})do
 local object,key,value=mutation[1],mutation[2],mutation[3];local before=object[key]
 object[key]=value;assert(not Owner.ready(view,again),'changed reward accepted old token: '..tostring(key))
 object[key]=before;assert(Owner.ready(view,again),'restored reward rejected unchanged token: '..tostring(key))
end

-- Preserve the existing error/partial-token contract; capture is not a transaction.
local failure,oldState={},{old=true}
local badRelics=setmetatable({},{__pairs=function()error(failure)end})
local failedRun={phase='reward',combat=run.combat,rewards={cards={},relics=badRelics}}
local partial={relicState=oldState}
local ok,err=pcall(Owner.capture,partial,view,failedRun)
assert(not ok and err==failure,'copy failure must preserve the original error object')
assert(partial.rewards==failedRun.rewards and partial.relics==badRelics and partial.relicState==oldState)
assert(failedRun.phase=='reward' and failedRun.rewards.relics==badRelics,'failed capture mutated live Run')
local empty=Owner.capture({},view,nil)
assert(empty.rewards==nil and empty.cardChoices==nil and empty.relicState==nil)
print('RELIC_REWARD_OWNER_PASS')
