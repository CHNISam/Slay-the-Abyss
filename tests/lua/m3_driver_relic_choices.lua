-- Real starter combat/reward and unmodified random chest draw. Only the next
-- map room's type is a controlled treasure-entry fixture, not a natural route.
local Run,N,Map,D,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data'),require('abyss_combat')
local Pending=require('abyss_relic_pending')
local Policy=dofile('scripts/warrior75-autoplay-policy.lua')
local Select=dofile('scripts/m3-relic-choice-policy.lua')
local function same(a,b)
 assert(type(a)==type(b));if type(a)~='table'then assert(a==b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function consume(r)
 local token,details=Select.choose(r,Policy.scoreCard);assert(token,'driver omitted mandatory relic choice')
 local ok,why=Pending.resolve(r,token);assert(ok,why);return token,details
end
local r=Run.new(D,'25',{experimental=true,campaign=true,campaignProfile='competition-two-act'})
local m=Map.generate(r.data,r.runSeed,1)
assert(N.enter(r,m,N.available(r,m)[1].id))
for _=1,180 do
 if r.phase~='combat'then break end
 local uid,target=Policy.chooseCombat(r)
 if r.combat.pendingChoice then local p=r.combat.pendingChoice;assert(Run.chooseCard(r,p.token,p.uids[1]))
 elseif uid then assert(Run.play(r,uid,target))else assert(Run.endTurn(r))end
end
assert(r.phase=='reward','starter fight must win through real commands')
-- Snapshot clone keeps the real generated reward source while isolating a
-- controlled Singing Bowl precondition for the public reward-selection modal.
local cardRun=C.copy(r)
assert(Run.obtainRelic(cardRun,'Singing Bowl'))
assert(require('abyss_relic_card_rewards').open(cardRun,cardRun.rewards))
assert(Pending.view(cardRun).key=='pendingCardRewardSelection')
while Pending.owner(cardRun)do consume(cardRun)end
assert(cardRun.rewards.cardResolved)
assert(not r.rewards.cardResolved,'isolated modal test must not consume main fixture rewards')
print('PASS mandatory owner pendingCardRewardSelection')

assert(Run.claimGoldReward(r))
if r.rewards.potion and not r.rewards.potion.resolved then assert(Run.skipPotionReward(r))end
local choice
for i,id in ipairs(Run.rewardOptions(r))do
 for _,d in ipairs(r.data.cards.cards)do if d.id==id and d.type=='attack'then choice=i;break end end
 if choice then break end
end
assert(choice,'fixture must legitimately obtain a non-basic attack')
assert(Run.claimCardReward(r,choice))
if r.rewards and r.rewards.manualContinue then assert(Run.leaveCombatRewards(r))end
assert(N.completeCombat(r,m))
local nextNode=N.available(r,m)[1]
for _,n in ipairs(m.nodes)do if n.id==nextNode.id then n.type='treasure'end end
assert(N.enter(r,m,nextNode.id));assert(N.claimTreasure(r))
assert(r.pendingBottledRelic and r.pendingBottledRelic.id=='bottled_flame','real unmodified chest must draw bottle')
local roomFloor,roomId,phase=r.floor,r.nodeFlow.id,r.phase
assert(not N.enter(r,m,N.available(r,m)[1].id),'old driver continuation is blocked by required choice')
local token,details=consume(r)
assert(details.key=='pendingBottledRelic'and details.uid==token.uid)
assert(not Pending.owner(r)and r.floor==roomFloor and r.nodeFlow.id==roomId and r.phase==phase)
local bottled=false;for _,c in ipairs(r.deck)do if c.uid==token.uid then bottled=c.inBottleFlame end end;assert(bottled)
local before=C.copy(r);local ok,why=Pending.resolve(r,token)
assert(not ok and why=='stale_relic_choice');same(r,before)
assert(N.enter(r,m,N.available(r,m)[1].id),'driver must continue from original completed chest')
print('PASS normal chest bottle mandatory token and original-room continuation')
-- Controlled public relic acquisition isolates each additional modal owner.
for _,id in ipairs({'DollysMirror','Empty Cage','Tiny House','Orrery','Cauldron'})do
 local run=Run.new(D,'25')
 if id=='Cauldron'or id=='Tiny House'then
  for _=1,run.data.rules.player.potionSlots do assert(Run.obtainPotion(run,'block_potion'))end
 end
 assert(Run.obtainRelic(run,id))
 local count=0
 while Pending.owner(run)do count=count+1;assert(count<20,'modal failed to finish');consume(run)end
 assert(count>0,'fixture must exercise modal')
 if id=='Cauldron'or id=='Tiny House'then assert(Run.potionCount(run)==run.data.rules.player.potionSlots)end
 print('PASS mandatory owner '..id)
end
local blocked=Run.new(D,'25')
assert(Run.obtainRelic(blocked,'Sozu'));assert(Run.obtainRelic(blocked,'Tiny House'))
local rounds=0
while Pending.owner(blocked)do rounds=rounds+1;assert(rounds<20);consume(blocked)end
assert(Run.potionCount(blocked)==0)
print('PASS boss reward bag legally completes when visible Sozu blocks bottles')
print('M3_DRIVER_RELIC_CHOICES_PASS 8')
