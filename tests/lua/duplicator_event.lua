-- Real acquisition/transaction tests. Room boundaries are controlled, not natural playthroughs.
local Run,C,R=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random')
local Data,Hooks=require('abyss_data'),require('abyss_relic_hooks')
local loaded,Event=pcall(require,'abyss_duplicator_event')
assert(loaded and type(Event)=='table','Duplicator production event module must exist')
local function same(a,b,path)
 path=path or 'state';assert(type(a)==type(b),path)
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local n=0
local function test(name,fn)fn();n=n+1;print('PASS duplicator '..n..' '..name)end
local function new()
 local run=Run.new(Data,'105',{experimental=true,campaign=true,campaignProfile='competition-two-act',character='ironclad'})
 run.phase,run.act,run.floor='node',2,22
 run.nodeFlow={id='controlled_duplicator',type='event',floor=22,complete=false,event={id='duplicator'}}
 Event.prepare(run,run.nodeFlow.event)
 return run
end
local function command(run,choice,uid)
 return Run.transaction(run,function(staged)return Event.choose(staged,staged.nodeFlow,choice,uid)end)
end
local function selected(run,uid)
 assert(command(run,'copy'));assert(run.nodeFlow.event.stage=='choose_card')
 local rows=Event.cards(run);assert(#rows==#run.deck)
 assert(command(run,'select',uid));assert(run.nodeFlow.event.stage=='result')
end
local function streams(run)return C.copy({run.eventRng,run.miscRng,run.cardRng,run.treasureRng,run.encounters,run.relicPool,run.unknown})end

test('full-deck selection copies bottled card to fresh unbottled UID exactly once without RNG',function()
 local run=new();local original=run.deck[1]
 original.inBottleFlame,original.inBottleLightning,original.inBottleTornado=true,true,true
 local source=C.copy(original);local uid,count=run.nextDeckUid,#run.deck;local rng=streams(run)
 local cards=Event.cards(run);assert(cards[1].uid==original.uid);cards[1].cardId='not_real';same(run.deck[1],source)
 selected(run,original.uid)
 local copy=run.deck[#run.deck];assert(#run.deck==count+1 and copy.uid==uid and run.nextDeckUid==uid+1)
 assert(copy.cardId==source.cardId and copy.upgraded==source.upgraded)
 assert(not copy.inBottleFlame and not copy.inBottleLightning and not copy.inBottleTornado)
 same(run.deck[1],source);same(streams(run),rng)
 local before=C.copy(run);assert(not command(run,'select',source.uid));same(run,before)
 assert(command(run,'leave'));assert(not command(run,'copy'))
end)

test('copy preserves repeated Searing Blow upgrades and constructor-copy baseline',function()
 for _,spec in ipairs({{4,true,nil},{4,true,2},{3,false,3}})do
  local run=new();assert(Run.obtainCard(run,'searing_blow',{upgrades=spec[1],upgraded=spec[2],searingBlowCopyUpgrades=spec[3]}))
  local original=run.deck[#run.deck];local saved=C.copy(original);selected(run,original.uid)
  local copy=run.deck[#run.deck]
  assert(copy.upgrades==spec[1] and copy.upgraded==spec[2] and copy.searingBlowCopyUpgrades==spec[3])
  same(run.deck[#run.deck-1],saved)
 end
end)

test('copy keeps permanent ritual growth and cost before real obtain hooks',function()
 local run=new();assert(Run.obtainCard(run,'ritual_dagger'))
 local source=run.deck[#run.deck];source.misc,source.costOverride=42,0
 run.relics[#run.relics+1]='ceramic_fish';local beforeGold=run.gold
 local original=Hooks.onObtainCard;local observed=false
 Hooks.onObtainCard=function(owner,card,definition,api)
  assert(card.misc==42 and card.costOverride==0,'copy stats must precede onObtain')
  observed=true;return original(owner,card,definition,api)
 end
 local ok,why=pcall(selected,run,source.uid);Hooks.onObtainCard=original;assert(ok,why)
 local copy=run.deck[#run.deck];assert(observed and copy.misc==42 and copy.costOverride==0 and run.gold==beforeGold+9)
 assert(run.deck[#run.deck-1].misc==42 and run.deck[#run.deck-1].costOverride==0)
end)

test('Egg upgrades only newly obtained copy and does not double-upgrade upgraded original',function()
 for _,upgraded in ipairs({false,true})do
  local run=new();local source=run.deck[1];source.upgraded=upgraded;source.upgrades=upgraded and 1 or nil
  local saved=C.copy(source);run.relics[#run.relics+1]='molten_egg';selected(run,source.uid)
  local copy=run.deck[#run.deck];assert(copy.upgraded and copy.upgrades==1);same(run.deck[1],saved)
 end
end)

test('curse copy uses Omamori before UID allocation and Periapt/Fish exactly once otherwise',function()
 for _,blocked in ipairs({true,false})do
  local run=new();assert(Run.obtainCard(run,'regret'));local source=run.deck[#run.deck]
  run.relics[#run.relics+1]='ceramic_fish';run.relics[#run.relics+1]='darkstone_periapt'
  if blocked then run.relics[#run.relics+1]='omamori';run.relicCounters={omamori=1}end
  local gold,hp,maxHp,uid,count=run.gold,run.hp,run.maxHp,run.nextDeckUid,#run.deck
  selected(run,source.uid)
  if blocked then
   assert(#run.deck==count and run.nextDeckUid==uid and run.relicCounters.omamori==0)
   assert(run.gold==gold and run.hp==hp and run.maxHp==maxHp and run.nodeFlow.event.curseBlocked)
  else
   assert(#run.deck==count+1 and run.nextDeckUid==uid+1 and run.gold==gold+9)
   assert(run.hp==hp+6 and run.maxHp==maxHp+6)
  end
 end
end)

test('decline has separate result and no card, UID, resource or random changes',function()
 local run=new();local before=C.copy(run);assert(command(run,'leave'))
 assert(run.nodeFlow.event.stage=='result');same(run.deck,before.deck);same(streams(run),streams(before))
 assert(run.nextDeckUid==before.nextDeckUid and run.hp==before.hp and run.gold==before.gold)
 local ok,state=command(run,'leave');assert(ok and state=='complete')
end)

test('stale or ambiguous UID and malformed copy stats reject entire transaction',function()
 local run=new();assert(command(run,'copy'))
 for _,uid in ipairs({0,-1,999,'1'})do local before=C.copy(run);assert(not command(run,'select',uid));same(run,before)end
 local source=run.deck[1]
 for _,bad in ipairs({-1,.5,2147483648,'42'})do
  source.misc=bad;local before=C.copy(run);assert(not command(run,'select',source.uid));same(run,before)
 end
 source.misc=nil;run.deck[#run.deck+1]=C.copy(source)
 local before=C.copy(run);assert(not command(run,'select',source.uid));same(run,before)
end)

test('late obtain rejection rolls back all counters, rewards, copied owner and card state',function()
 local run=new();assert(command(run,'copy'));local before=C.copy(run);local originalData=run.data
 local original=Hooks.onObtainCard
 Hooks.onObtainCard=function(owner,card,definition,api)
  original(owner,card,definition,api);owner.gold=999;R.randomInt(owner.miscRng,99);R.randomInt(owner.eventRng,99)
  return false,'duplicator_late_failure'
 end
 local ok,why=command(run,'select',run.deck[1].uid);Hooks.onObtainCard=original
 assert(not ok and why=='duplicator_late_failure');same(run,before);assert(run.data==originalData)
end)

test('empty deck cannot enter an impossible mandatory picker and original decline stays usable',function()
 local run=new();run.deck={};local before=C.copy(run)
 local options=Event.options(run,run.nodeFlow.event)
 assert(options[1].choice=='copy' and options[1].enabled==false and options[2].choice=='leave' and options[2].enabled)
 local ok,why=command(run,'copy');assert(not ok and why=='no_copyable_card');same(run,before)
 assert(command(run,'leave'));local finished,result=command(run,'leave');assert(finished and result=='complete')
 assert(#run.deck==0 and run.nextDeckUid==before.nextDeckUid)
end)

print('DUPLICATOR_EVENT_PASS '..n)
