package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data,Run,Random=require('abyss_combat'),require('abyss_data'),require('abyss_run'),require('abyss_sts_random')
local Catalog,AI=require('abyss_combat_catalog'),require('abyss_enemy_ai')
local records,active,count={},nil,0
local function eq(a,b,label)assert(a==b,'[COMBAT_CONSTRUCTOR] '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function graph(v,seen)
 if type(v)=='function'then return 'function'end
 if type(v)=='number'then return 'number:'..string.format('%.17g',v)end
 if type(v)~='table'then return type(v)..':'..tostring(v)end
 seen=seen or {n=0};if seen[v]then return 'ref:'..seen[v]end
 seen.n=seen.n+1;seen[v]=seen.n
 local keys={};for k in pairs(v)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
 local parts={};for _,k in ipairs(keys)do parts[#parts+1]=graph(k,seen)..'='..graph(v[k],seen)end
 return '{'..table.concat(parts,';')..'}'
end
local prepare=Catalog.prepare
Catalog.prepare=function(data)
 local prepared,catalog=prepare(data)
 if active then active.prepared=prepared;active.catalog=catalog end
 return prepared,catalog
end
for _,name in ipairs({'initialize','preBattle'})do
 local old=AI[name]
 AI[name]=function(state,enemy,...)
  if active then active.order[#active.order+1]=name..':'..enemy.id end
  return old(state,enemy,...)
 end
end
local shuffle=Random.shuffle
Random.shuffle=function(...)
 if active then active.order[#active.order+1]='shuffle' end
 return shuffle(...)
end
local function observation(s)
 return {phase=s.phase,turn=s.turn,energy=s.energy,hand=#s.hand,draw=#s.draw,player=s.player,
  shuffle=s.shuffleRng and Random.snapshot(s.shuffleRng),card=s.cardRng and Random.snapshot(s.cardRng),
  hp=s.monsterHpRng and Random.snapshot(s.monsterHpRng)}
end
local function call(data,options)
 local record={data=data,options=options,order={},callbacks={}}
 records[#records+1]=record;active=record
 local result=table.pack(pcall(C.new,data,options));active=nil
 -- Assertion file locations differ between complete old/new modules. Preserve
 -- exact error kind/message while removing only this diagnostic source prefix.
 if not result[1]and type(result[2])=='string'then result[2]=result[2]:match(':%d+: (.*)')or result[2]end
 record.result=result
 return table.unpack(result,1,result.n)
end
local function state(data,options)
 local called,s,why=call(data,options);eq(called,true,'constructor called');assert(s,'[COMBAT_CONSTRUCTOR] state: '..tostring(why));return s
end
local function test(name,fn)
 if ABYSS_CONSTRUCTOR_CASE and ABYSS_CONSTRUCTOR_CASE~=name then return end
 fn();count=count+1;print('ok constructor '..count..' '..name)
end
local function opts()return {seed=42,deck={'strike','defend','bash'},enemies={'cultist'}}end

test('defaults-and-registration',function()
 local s=state(Data,nil);eq(s.turn,1,'default first turn');eq(s.phase,'player','default phase')
 local r=records[#records];eq(s.rules==Data.rules,false,'caller rules detached')
 eq(s.catalog.cards.strike==Data.cards.cards[1],false,'caller definitions detached')
 eq(s.catalog,r.catalog,'prepared catalog owner retained')
 if r.prepared~=Data then eq(s.sourcePools,r.prepared.cards.sourcePools,'new registered pools adopted')
 else eq(s.sourcePools==Data.cards.sourcePools,false,'registered caller pools copied')end
 local d=require('abyss_colorless_cards').withCards(Data);local o=opts();o.deck={}
 s=state(d,o);eq(records[#records].prepared,d,'already registered bundle retained');eq(s.sourcePools==d.cards.sourcePools,false,'existing pools detached')
 eq(#s.hand,0,'empty deck valid')
end)
test('independent-streams',function()
 local run=Run.new(Data,'42');local streams=Run.roomStreams(run,1);local o=opts()
 o.roomSeed=streams.seed;o.roomStreams=streams;o.shuffleSeed='13';o.cardRandomSeed='99'
 o.cardRng=Random.fromSeed('73');o.miscRng=Random.fromSeed('17')
 local before=graph({streams=streams,cardRng=o.cardRng,miscRng=o.miscRng})
 local s=state(Data,o)
 eq(s.roomSeed,streams.seed,'raw room seed');eq(s.monsterHpRng==streams.monsterHpRng,false,'HP stream cloned')
 eq(s.aiRng==streams.aiRng,false,'AI stream cloned');eq(s.shuffleRng==streams.shuffleRng,false,'shuffle stream cloned')
 eq(s.cardRandomRng==streams.cardRandomRng,false,'card random stream cloned');eq(s.cardRng==o.cardRng,false,'cardRng cloned')
 eq(s.miscRng==streams.miscRng,false,'room misc cloned');eq(graph({streams=streams,cardRng=o.cardRng,miscRng=o.miscRng}),before,'all caller streams untouched')
 eq(table.concat(records[#records].order,','),'initialize:cultist_1,shuffle,preBattle:cultist_1,shuffle','AI/shuffle/prebattle then empty draw reshuffle order')
end)
test('prepared-adoption',function()
 local run=Run.new(Data,'42');local streams=Run.roomStreams(run,1)
 local prepared=C.prepareEncounter(Data,{enemies={'cultist'},roomSeed=streams.seed,roomStreams=streams})
 local before=graph(prepared)
 local o={seed=42,deck={'strike'},roomSeed=streams.seed,roomStreams=streams,preparedEncounter=prepared}
 local s=state(Data,o);eq(s.enemies==prepared.actors,false,'prepared actors detached');eq(s.enemies[1]==prepared.actors[1],false,'prepared actor detached')
 eq(s.enemies[1].definitionId,'cultist','prepared identity');eq(graph(prepared),before,'prepared input not initialized in place')
 prepared.version=2;local called=call(Data,o);eq(called,false,'invalid prepared identity rejected rather than reconstructed')
end)
test('permanent-card-identity',function()
 local d=require('abyss_original_v4_profiles').prepare(Data,'RD')
 local o={seed=42,enemies={'cultist'},deck={{cardId=d.cards.starter_deck.cards[1],uid=19},{cardId=d.cards.starter_deck.cards[2],uid=7}}}
 -- Profile starter entries may already be instance descriptors.
 for _,v in ipairs(o.deck)do if type(v.cardId)=='table'then v.cardId=v.cardId.cardId end end
 local s=state(d,o);eq(s.nextUid,21,'permanent UID allocation keeps original max/increment rule')
 local found={};for _,pile in ipairs({s.hand,s.draw})do for _,card in ipairs(pile)do found[card.uid]=card;eq(card.uuid,card.uid,'permanent UUID')end end
 eq(found[19].deckUid,19,'high permanent UID');eq(found[7].deckUid,7,'lower permanent UID')
 o.deck[2].uid=19;local called,why=call(d,o);eq(called,false,'duplicate permanent UID rejected');assert(why:find('duplicate permanent card UID',1,true),'[COMBAT_CONSTRUCTOR] duplicate UID reason')
end)
test('card-copy-metadata',function()
 local o=opts();o.deck={{cardId='searing_blow',upgraded=false,upgrades=3,searingBlowCopyUpgrades=3,misc=0,costOverride=0,inBottleFlame=true},
  {cardId='defend',upgraded=true,upgrades=1,misc=false,inBottleLightning=false,inBottleTornado=true}}
 local s=state(Data,o);local found={};for _,c in ipairs(s.hand)do found[c.cardId]=c end
 local c=assert(found.searing_blow);eq(c.upgrades,3,'Searing upgrades');eq(c.searingBlowCopyUpgrades,3,'Searing count baseline')
 eq(c.upgraded,false,'count-only upgraded flag');eq(c.costOverride,0,'zero cost retained');eq(c.misc,0,'zero misc retained');eq(c.inBottleFlame,true,'bottle Flame')
 eq(found.defend.inBottleLightning,false,'false bottle retained');eq(found.defend.inBottleTornado,true,'bottle Tornado')
 eq(c==o.deck[1],false,'instances detached from descriptors')
end)
test('opening-callbacks',function()
 local o=opts();o.deck={};for i=1,7 do o.deck[i]='dramatic_entrance'end
 o.beforeFirstTurn=function(s)
  active.order[#active.order+1]='beforeFirstTurn';active.callbacks[#active.callbacks+1]=observation(s)
  eq(s.phase,'setup','first callback setup');eq(s.turn,0,'first callback before turn');eq(#s.hand,0,'first callback before extra innate')
  eq(s.enemies[1].intentIndex,2,'enemy prebattle already ran');return true
 end
 o.beforeOpeningDraw=function(s)
  active.order[#active.order+1]='beforeOpeningDraw';active.callbacks[#active.callbacks+1]=observation(s)
  eq(s.phase,'player','opening callback player');eq(s.turn,1,'opening callback after start turn');eq(#s.hand,2,'extra innate drawn before opening callback')
  return true
 end
 local s=state(Data,o);eq(#s.hand,7,'all innate cards opened')
 eq(table.concat(records[#records].order,','),'initialize:cultist_1,preBattle:cultist_1,beforeFirstTurn,beforeOpeningDraw','callback placement without source shuffle')
 eq(s.beforeFirstTurn,nil,'constructor callback not saved');eq(s.beforeOpeningDraw,nil,'opening callback not saved')
end)
test('callback-refusal',function()
 for _,name in ipairs({'beforeFirstTurn','beforeOpeningDraw'})do
  local o=opts();o[name]=function(s)active.observedState=s;return false,name..'_refused'end
  local called,s,why=call(Data,o);eq(called,true,'refusal return');eq(s,nil,'refusal no state');eq(why,name..'_refused','refusal reason')
  eq(#records[#records].observedState.hand,0,'refusal before ordinary draw')
 end
end)
test('callback-exception',function()
 for _,name in ipairs({'beforeFirstTurn','beforeOpeningDraw'})do
  local sentinel={boundary=name};local o=opts();o[name]=function(s)active.observedState=s;error(sentinel,0)end
  local called,why=call(Data,o);eq(called,false,'callback error propagates');eq(why,sentinel,'callback table error identity')
 end
end)
test('profile-option-defaults',function()
 local r=Run.new(Data,'42',{character='defect',experimental=true});local o=opts();o.deck={}
 local s=state(r.data,o);eq(s.orbs.slots,3,'Defect default orb slots');eq(s.player.stance,'Neutral','default stance')
 eq(o.orbSlots,nil,'caller orb option unmodified');eq(o.enableStances,nil,'caller stance option unmodified')
 o.enableStances=false;o.orbSlots=0;s=state(r.data,o);eq(s.player.stance,nil,'explicit false stance retained');eq(s.orbs.slots,0,'explicit zero slots retained')
end)
test('emerald-placement',function()
 local o=opts();o.emeraldBoost={version=1,act=1,nodeId='f8_l2',x=1,y=7,roll=0}
 o.beforeFirstTurn=function(s)eq(s.enemies[1].statuses.strength,2,'emerald applied before first callback');return true end
 local s=state(Data,o);eq(s.enemies[1].statuses.strength,2,'emerald strength retained')
end)
test('invalid-boundaries',function()
 for _,o in ipairs({{seed=0.5},{hp=0},{gold=-1},{deck='invalid'},{enableStances='invalid'},
  {sourceEncounter='unknown'},{enemies={'cultist'},roomStreams={},roomSeed=5},
  {deck={{cardId='searing_blow',upgraded=false,upgrades=1,searingBlowCopyUpgrades=3}}}})do
  local called=call(Data,o);eq(called,false,'invalid options fail')
 end
end)
if ABYSS_CONSTRUCTOR_TRACE then print('COMBAT_CONSTRUCTOR_TRACE '..graph(records))end
print('COMBAT_CONSTRUCTOR_PASS '..count)
