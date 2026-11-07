-- Dedicated characterization fixture for Act1.choose responsibility extraction.
-- Run with generated abyss_data on package.path; the host may install
-- ACT1_GRAPH_WRITE(root,label) to observe complete values and retained owners.
-- Optional Lua global ACT1_BOUNDARY_GROUP=1..4 selects registration ordinals
-- congruent to that group modulo four. Omission executes every registered test.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Nodes,Act1=require('abyss_combat'),require('abyss_run'),require('abyss_nodes'),require('abyss_act1_events')
local Common,Random,Data=require('abyss_nodes_common'),require('abyss_sts_random'),require('abyss_data')
local count,registered=0,0
local group=ACT1_BOUNDARY_GROUP
assert(group==nil or (type(group)=='number' and group%1==0 and group>=1 and group<=4),
 'ACT1_BOUNDARY_GROUP must be an integer from 1 to 4')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'missing key '..tostring(k))end
end
local function observe(root,label)
 if ACT1_GRAPH_WRITE then ACT1_GRAPH_WRITE(root,label)end
end
local function test(name,fn)
 registered=registered+1
 if group~=nil and (registered-1)%4+1~=group then return end
 fn();count=count+1
 print('PASS act1 boundaries '..registered..' '..name)
end
local function rng(n)return Random.restore({words={'0000000000000000',string.format('%016x',n)},counter=0})end
local function fixture(id,stage,card)
 local r=Run.new(Data,42)
 r.phase='node';r.nodeFlow={type='event',complete=false,event={id=id,stage=stage}}
 if card then r.deck={{uid=7,cardId=card,upgraded=false}}end
 Act1.prepare(r,r.nodeFlow.event,r.miscRng,1)
 if stage=='choose_card'then
  r.nodeFlow.event.choice=({bonfire='offer',transmogrifier='change',accursed_blacksmith='forge'})[id]
 end
 r.miscRng=rng(99);r.relicPool.rng=rng(0)
 return r
end
local function direct(r,choice,uid)
 return Act1.choose(r,r.nodeFlow,choice,uid,Common.upgradeable,Common.upgradeCards)
end
local function command(r,choice,uid,raw)
 local values=table.pack((raw and direct or Nodes.chooseEvent)(r,choice,uid))
 observe({run=r,returns=values},'act1-choice-boundary')
 return table.unpack(values,1,values.n)
end
-- Restore methods even when assertions fail. A false value denotes a missing
-- capability; all other replacements are callable wrappers of actual methods.
local function replaced(patches,fn)
 local old={};for key,value in pairs(patches)do old[key]=Run[key];Run[key]=value~=false and value or nil end
 local out=table.pack(pcall(fn))
 for key in pairs(patches)do Run[key]=old[key]end
 assert(out[1],out[2]);return table.unpack(out,2,out.n)
end
local function refused(r,choice,uid,reason,raw)
 local before=C.copy(r)
 local owners={deck=r.deck,card=r.deck[1],flow=r.nodeFlow,event=r.nodeFlow.event,relics=r.relics,
  counters=r.relicCounters,misc=r.miscRng,pool=r.relicPool,queues=r.relicPool.queues,data=r.data}
 local ok,why=command(r,choice,uid,raw);eq(ok,false);eq(why,reason);same(r,before)
 eq(r.deck,owners.deck);eq(r.deck[1],owners.card);eq(r.nodeFlow,owners.flow);eq(r.nodeFlow.event,owners.event)
 eq(r.relics,owners.relics);eq(r.relicCounters,owners.counters);eq(r.miscRng,owners.misc)
 eq(r.relicPool,owners.pool);eq(r.relicPool.queues,owners.queues);eq(r.data,owners.data)
 observe({run=r,owners=owners},'act1-refusal-owners')
end
local ids={'sssserpent','big_fish','accursed_blacksmith','scrap_ooze','transmogrifier','bonfire'}
for _,id in ipairs(ids)do
 test(id..' unknown choice and premature UID are immutable refusals',function()
  local r=fixture(id)
  refused(r,'not_a_choice',nil,'invalid_event_choice')
  refused(r,'leave',7,'invalid_event_choice')
  r.nodeFlow.event.stage='unrecognized_stage'
  refused(r,'not_a_choice',nil,'invalid_event_choice')
  for _,stage in ipairs({'result','disagree'})do
   r.nodeFlow.event.stage=stage
   refused(r,'leave',7,'invalid_event_choice')
   refused(r,'not_a_choice',nil,'invalid_event_choice')
   local ok,why=command(r,'leave',nil,true);eq(ok,true);eq(why,'complete')
  end
 end)
end

test('unknown local event keeps shared terminal guard and fallback',function()
 local r=fixture('not_registered')
 refused(r,'leave',nil,'invalid_event_choice',true)
 r.nodeFlow.event.stage='result';local ok,why=command(r,'leave',nil,true);eq(ok,true);eq(why,'complete')
end)

test('nonterminal stage behavior stays event-specific',function()
 local cases={{'sssserpent','confirm','invalid_event_choice'},{'accursed_blacksmith','forge','invalid_event_choice'},
  {'bonfire','offer','invalid_event_choice'},{'transmogrifier','change','invalid_card'}}
 for _,v in ipairs(cases)do refused(fixture(v[1],'unrecognized_stage'),v[2],nil,v[3])end
 -- The old fish and ooze branches do not reject arbitrary nonterminal stages.
 for _,v in ipairs({{'big_fish','banana'},{'scrap_ooze','leave'}})do
  local r=fixture(v[1],'unrecognized_stage');assert(command(r,v[2]));eq(r.nodeFlow.event.stage,'result')
 end
end)

test('all card pickers reject wrong choice, absent, string and stale UID',function()
 for _,v in ipairs({{'accursed_blacksmith','forge','invalid_card'},{'bonfire','offer','card_not_purgeable'},
  {'transmogrifier','change','invalid_card'}})do
  local r=fixture(v[1],'choose_card','strike')
  refused(r,'wrong',7,'invalid_event_choice')
  refused(r,v[2],nil,v[3]);refused(r,v[2],'7',v[3]);refused(r,v[2],99,v[3])
 end
 local r=fixture('accursed_blacksmith','choose_card','strike');r.deck[1].upgraded=true
 refused(r,'forge',7,'card_not_upgradeable')
 local fresh=fixture('accursed_blacksmith','choose_card','strike')
 assert(command(fresh,'forge',7))
 eq(fresh.deck[1].upgrades,1);eq(fresh.deck[1].upgraded,true)
 eq(fresh.nodeFlow.event.upgradedUids[1],7)
end)

test('bonfire and transform retain protected and bottled cards',function()
 for _,id in ipairs({'bonfire','transmogrifier'})do
  local choice=id=='bonfire'and'offer'or'change'
  for _,card in ipairs({'curse_of_the_bell','necronomicurse','strike'})do
   local r=fixture(id,'choose_card',card)
   if card=='strike'then r.deck[1].inBottleLightning=true end
   refused(r,choice,7,'card_not_purgeable')
  end
  local r=fixture(id,'choose_card','strike');r.deck={}
  refused(r,choice,7,id=='bonfire'and'card_not_purgeable'or'invalid_card')
 end
end)

local missing={
 {'sssserpent','agree','confirm',nil,{'transaction','prepareCard','gainGold','commitCard'}},
 {'big_fish',nil,'banana',nil,{'heal'}},
 {'big_fish',nil,'donut',nil,{'increaseMaxHp'}},
 {'big_fish',nil,'box',nil,{'transaction','prepareRelic','prepareCard','obtainRelic','commitCard'}},
 {'accursed_blacksmith',nil,'rummage',nil,{'transaction','prepareCard','obtainRelic','commitCard'}},
 {'scrap_ooze',nil,'search',nil,{'prepareRelic','obtainRelic'}},
 {'bonfire','choose_card','offer','anger',{'transaction','heal','removeCard'}},
 {'bonfire','choose_card','offer','battle_trance',{'heal'}},
 {'bonfire','choose_card','offer','bludgeon',{'increaseMaxHp','heal'}},
 {'bonfire','choose_card','offer','doubt',{'obtainRelic'}},
}
for _,v in ipairs(missing)do
 for _,key in ipairs(v[5])do
  test(v[1]..' '..v[3]..' missing '..key..' refuses atomically',function()
   local r=fixture(v[1],v[2],v[4])
   replaced({[key]=false},function()
    refused(r,v[3],v[4]and 7 or nil,'event_content_unavailable',key=='transaction')
   end)
  end)
end

end
test('unguarded ooze and transform capabilities are caught by outer transaction',function()
 for _,v in ipairs({{'scrap_ooze',nil,'search','eventDamage'},
  {'transmogrifier','choose_card','change','removeCard'},{'transmogrifier','choose_card','change','obtainCard'}})do
  local r=fixture(v[1],v[2],'strike');r.miscRng=rng(0)
  replaced({[v[4]]=false},function()refused(r,v[3],v[2]and 7 or nil,'transaction_failed')end)
 end
end)

test('bonfire unknown definition and rarity refuse before permanent removal',function()
 for _,mode in ipairs({'definition','rarity'})do
  local r=fixture('bonfire','choose_card','strike');r.data=C.copy(r.data)
  for i,d in ipairs(r.data.cards.cards)do
   if d.id=='strike'then
    if mode=='definition'then table.remove(r.data.cards.cards,i)else d.rarity='unsupported_rarity'end
    break
   end
  end
  refused(r,'offer',7,'event_content_unavailable')
 end
end)

test('bonfire rarity rewards precede permanent removal including special and existing Spirit Poop',function()
 local cases={{'strike','basic',10,80},{'anger','common',15,80},{'strike','special',15,80},
  {'battle_trance','uncommon',80,80},{'bludgeon','rare',90,90},{'doubt','curse',10,80}}
 for _,v in ipairs(cases)do
  for _,owned in ipairs(v[2]=='curse'and{'none','spirit_poop','Spirit Poop'}or{'none'})do
   local r=fixture('bonfire','choose_card',v[1]);r.hp=10;r.maxHp=80
   -- No purgeable special card exists in the playable catalog. Keep the real
   -- strike card and removal hooks, varying only its definition's rarity.
   if v[2]=='special'then
    r.data=C.copy(r.data)
    for _,d in ipairs(r.data.cards.cards)do if d.id=='strike'then d.rarity='special'end end
   end
   if owned~='none'then r.relics[#r.relics+1]=owned end
   local observations;local remove=Run.removeCard;local before=C.copy(r)
   replaced({removeCard=function(staged,uid)
    observations={hp=staged.hp,maxHp=staged.maxHp,uid=uid,stage=staged.nodeFlow.event.stage,
     lastRelic=staged.relics[#staged.relics],cards=#staged.deck}
    return remove(staged,uid)
   end},function()assert(command(r,'offer',7))end)
   assert(observations);eq(observations.hp,v[3]);eq(observations.maxHp,v[4]);eq(observations.uid,7)
   eq(observations.stage,'choose_card');eq(observations.cards,1)
   if v[2]=='curse'then eq(observations.lastRelic,owned=='none'and'spirit_poop'or'circlet')end
   eq(#r.deck,0);eq(r.nodeFlow.event.offeredRarity,v[2]);eq(r.nodeFlow.event.removedUid,7)
   same(r.miscRng,before.miscRng);same(r.eventRng,before.eventRng);same(r.relicPool,before.relicPool)
   observe({run=r,beforeRemoval=observations},'bonfire-rarity-order')
  end
 end
end)

test('source command ordering remains distinct for serpent, box, rummage, ooze and transform',function()
 local cases={
  {'sssserpent','agree','confirm',nil,{'prepareCard','gainGold','commitCard'}},
  {'big_fish',nil,'box',nil,{'prepareRelic','prepareCard','obtainRelic','commitCard'}},
  {'accursed_blacksmith',nil,'rummage',nil,{'prepareCard','obtainRelic','commitCard'}},
  {'scrap_ooze',nil,'search',nil,{'eventDamage','prepareRelic','obtainRelic'}},
  {'transmogrifier','choose_card','change','strike',{'removeCard','obtainCard','prepareCard','commitCard'}},
 }
 for _,v in ipairs(cases)do
  local r=fixture(v[1],v[2],v[4]);if v[4]then r.miscRng=rng(0)end
  local trace,patches={},{}
  for _,key in ipairs(v[5])do
   local original=Run[key]
   patches[key]=function(...)trace[#trace+1]=key;return original(...)end
  end
  replaced(patches,function()assert(command(r,v[3],v[4]and 7 or nil))end)
  same(trace,v[5]);observe({run=r,trace=trace},'source-order')
 end
end)

test('late reward failures restore all owners and RNG before retry',function()
 local cases={{'sssserpent','agree','confirm',nil,'commitCard'},
  {'big_fish',nil,'box',nil,'commitCard'},
  {'accursed_blacksmith',nil,'rummage',nil,'commitCard'},
  {'scrap_ooze',nil,'search',nil,'obtainRelic'},
  {'transmogrifier','choose_card','change','strike','obtainCard'},
  {'bonfire','choose_card','offer','doubt','removeCard'}}
 for _,v in ipairs(cases)do
  for _,mode in ipairs({'refuse','throw'})do
   local r=fixture(v[1],v[2],v[4]);if v[1]=='transmogrifier'then r.miscRng=rng(0)end
   local original=Run[v[5]];local reached=false
   replaced({[v[5]]=function(staged,...)
    local ok,why=original(staged,...);if not ok then return ok,why end
    reached=true;staged.gold=staged.gold+11;Random.randomInt(staged.miscRng,99)
    staged.nodeFlow.event.body='must be rolled back'
    if mode=='throw'then error('late choice failure',0)end
    return false,'late_choice_refusal'
   end},function()
    refused(r,v[3],v[4]and 7 or nil,mode=='throw'and'transaction_failed'or'late_choice_refusal')
   end)
   assert(reached,'fault must follow the real permanent operation')
   assert(command(r,v[3],v[4]and 7 or nil));eq(r.nodeFlow.event.stage,'result')
  end
 end
end)
eq(registered,39)
eq(count,group==nil and registered or math.floor((registered-group)/4)+1)
print('ACT1_CHOICE_BOUNDARIES '..count..' passed; registered='..registered..
 '; executed='..count..'; group='..tostring(group or 'all'))
