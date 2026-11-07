package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,T,S=require('abyss_combat'),require('abyss_warrior_status_cards'),require('abyss_act2_stasis')
local group=CARD_UPGRADE_GROUP or 'all'
local count=0
local function eq(a,b,label)assert(a==b,'[CARD_UPGRADE] '..label..': '..tostring(a)..' ~= '..tostring(b))end
local function observe(value,label)
 if CARD_UPGRADE_GRAPH_WRITE then CARD_UPGRADE_GRAPH_WRITE(value,label,true)end
end
local function result(label,fn,...)
 local out=table.pack(pcall(fn,...))
 if not out[1]and type(out[2])=='string'and CARD_UPGRADE_NORMALIZE_ERROR then
  local raw=out[2];out[2]=CARD_UPGRADE_NORMALIZE_ERROR(label,raw)
  CARD_UPGRADE_DIAGNOSTIC(label,raw,out[2])
 end
 return out
end
local function test(name,fn)
 fn();count=count+1;print('CARD_UPGRADE_CASE '..name)
end
local function unchanged(root)
 local records={}
 local function visit(value)
  if type(value)~='table'or records[value]then return end
  local row={fields={},count=0,meta=getmetatable(value)};records[value]=row
  for key,item in next,value do row.fields[key]=item;row.count=row.count+1;visit(key);visit(item)end
  visit(row.meta)
 end
 visit(root)
 return function()
  for object,row in pairs(records)do
   eq(getmetatable(object),row.meta,'rollback retains exact metatable')
   local n=0
   for key,item in next,object do n=n+1;eq(item,row.fields[key],'rollback retains every field and alias')end
   eq(n,row.count,'rollback retains complete field inventory')
  end
 end
end
local function state()
 local metadata=setmetatable({tag='shared metadata'},{kind='metadata metatable'});metadata.self=metadata
 local cards={
  strike={id='strike',type='attack',cost=1,upgrade={effects={{op='damage',value=9}}}},
  cheaper={id='cheaper',type='skill',cost=2,upgrade={cost=1}},
  expensive={id='expensive',type='skill',cost=1,upgrade={cost=3}},
  searing_blow={id='searing_blow',type='attack',cost=2,repeatable=true,effects={{op='damage',value=12}},upgrade={}},
  blood_for_blood={id='blood_for_blood',type='attack',cost=4,effects={{op='damage',value=18}},upgrade={cost=3,effects={{op='damage',value=22}}}},
  masterful_stab={id='masterful_stab',type='attack',cost=0,upgrade={}},
  all_energy={id='all_energy',type='attack',cost=0,costMode='all_energy',upgrade={cost=0}},
  wound={id='wound',type='status',cost=-2,upgrade={}},curse={id='curse',type='curse',cost=-2,upgrade={}},
  absent={id='absent',type='skill',cost=1},false_upgrade={id='false_upgrade',type='skill',cost=1,upgrade=false},
 }
 for _,d in pairs(cards)do d.metadata=metadata end
 return {catalog={cards=cards,metadata=metadata},player={hp=50,statuses={}},rules={player={maxHand=10}},
  hand={},draw={},discard={},exhaust={},metadata=metadata,alias=metadata}
end
local function inst(id,fields)
 local c={cardId=id,uid=17,upgraded=false}
 for key,value in pairs(fields or {})do c[key]=value end
 return c
end
if group=='all'or group=='rules'then
 test('validation truth values and constructor limits',function()
  local rows={
   {inst('strike'),true},{inst('strike',{searingBlowCopyUpgrades=0,upgrades=0}),false},
   {inst('searing_blow',{searingBlowCopyUpgrades=0,upgrades=0}),true},
   {inst('searing_blow',{searingBlowCopyUpgrades=3,upgrades=3}),true},
   {inst('searing_blow',{searingBlowCopyUpgrades=3,upgrades=4,upgraded=true}),true},
   {inst('searing_blow',{searingBlowCopyUpgrades=2147483647,upgrades=2147483647}),true},
  }
  for _,bad in ipairs({false,'0',-1,.5,2147483648,math.huge,0/0})do
   rows[#rows+1]={inst('searing_blow',{searingBlowCopyUpgrades=bad,upgrades=0}),false}
   rows[#rows+1]={inst('searing_blow',{searingBlowCopyUpgrades=0,upgrades=bad}),false}
  end
  for _,fields in ipairs({{searingBlowCopyUpgrades=2,upgrades=1},{searingBlowCopyUpgrades=2,upgrades=2,upgraded=true},
   {searingBlowCopyUpgrades=2,upgrades=3},{searingBlowCopyUpgrades=0,upgrades=0,upgraded=0},{searingBlowCopyUpgrades=0}})do
   rows[#rows+1]={inst('searing_blow',fields),false}
  end
  for _,row in ipairs(rows)do eq(C.validSearingBlowCopy(row[1]),row[2],'Searing constructor validation')end
  local s=state();local values={}
  for _,id in ipairs({'strike','wound','curse','absent','unknown','false_upgrade'})do
   local c=inst(id);values[id]=table.pack(C.canUpgrade(s,c))
  end
  eq(values.strike[1],true,'ordinary upgrade eligibility');eq(values.wound[1],false,'status refuses')
  eq(values.curse[1],false,'curse refuses');eq(values.absent[1],false,'missing upgrade refuses')
  eq(values.unknown[1],nil,'unknown card preserves nil return');eq(values.false_upgrade[1],true,'false upgrade is not nil')
  observe({state=s,rows=rows,values=values},'validation complete input graphs and return arity')
 end)
 test('cost resolution precedence and complete read order',function()
  local s=state();local rows={
   {'strike',{},1},{'strike',{costOverride=0},0},{'strike',{costOverride=-3},-3},
   {'all_energy',{costOverride=8},-1},{'cheaper',{upgraded=true},1},
   {'masterful_stab',{masterfulLosses=3},3},{'masterful_stab',{costOverride=1,masterfulLosses=3},1},
   {'masterful_stab',{combatCost=0,costOverride=2,masterfulLosses=3},0},
   {'blood_for_blood',{costReduction=2},2},{'blood_for_blood',{upgraded=true,costReduction=9},0},
   {'blood_for_blood',{costOverride=5,costReduction=1,combatCost=2,turnCost=0},4},
  }
  for _,row in ipairs(rows)do row.card=inst(row[1],row[2]);row.returned=table.pack(C.combatBaseCost(s,row.card));eq(row.returned[1],row[3],'base cost precedence')end
  local order={};local c=setmetatable({},{__index=function(_,key)order[#order+1]='card.'..key;if key=='cardId'then return 'strike'end end})
  local catalog=setmetatable({},{__index=function(_,key)order[#order+1]='catalog.'..key;return s.catalog.cards[key]end})
  local returned=table.pack(C.canUpgrade({catalog={cards=catalog}},c))
  eq(table.concat(order,','),'card.cardId,catalog.strike,card.searingBlowCopyUpgrades,card.upgraded','catalog lookup precedes validation')
  observe({state=s,rows=rows,order=order,card=c,returned=returned},'cost precedence aliases and property lookup order')
 end)
 test('ordinary repeatable and count-only upgrade arithmetic',function()
  local s=state();local cases={}
  for _,spec in ipairs({{'strike',{}},{'strike',{upgraded=true}},{'wound',{}},{'unknown',{}},
   {'cheaper',{costOverride=4,costForTurn=3}},{'cheaper',{costOverride=0,costForTurn=0}},
   {'cheaper',{costOverride=-1,costForTurn=-2}},{'expensive',{costForTurn=4}},
   {'strike',{costOverride=4,costForTurn=3}},{'searing_blow',{}},
   {'searing_blow',{upgrades=3,searingBlowCopyUpgrades=3}},
   {'searing_blow',{upgrades=2147483647,searingBlowCopyUpgrades=2147483647}},
  })do
   local c=inst(spec[1],spec[2]);local first=table.pack(C.upgrade(s,c));local second=table.pack(C.upgrade(s,c))
   cases[#cases+1]={card=c,first=first,second=second}
  end
  eq(cases[5].card.costOverride,nil,'ordinary upgrade clears override');eq(cases[5].card.costForTurn,0,'positive turn cost retains signed delta')
  eq(cases[6].card.costForTurn,0,'zero turn cost stays zero');eq(cases[7].card.costForTurn,-2,'negative turn cost stays negative')
  eq(cases[8].card.costForTurn,6,'cost-increasing upgrade retains turn delta');eq(cases[9].card.costOverride,4,'no upgrade cost retains override')
  eq(cases[10].card.upgrades,2,'ordinary Searing repeated upgrades');eq(cases[11].card.upgrades,5,'count-only Searing repeated upgrades')
  eq(C.cardDefinition(s,cases[11].card).effects[1].value,27,'count-only damage subtracts constructor baseline')
  eq(cases[12].card.upgrades,-2147483648,'maximum signed count retains runtime wrap');eq(cases[12].second[1],false,'wrapped constructor count subsequently refuses')
  observe({state=s,cases=cases},'ordinary repeatable count-only max signed upgrade graphs')
 end)
 test('Blood for Blood cost deltas and direct public hook',function()
  local s=state();local rows={}
  for _,fields in ipairs({{},{costReduction=1},{costReduction=7},{costOverride=5,costForTurn=6},
   {combatCost=2,turnCost=0},{combatCost=0,turnCost=1},{combatCost=4,turnCost=6,costForTurn=1},
   {combatCost=2147483647,turnCost=2147483647},{combatCost=3,turnCost=2147483647},
  })do
   local c=inst('blood_for_blood',fields);local returned=table.pack(C.upgrade(s,c));local again=table.pack(C.upgrade(s,c))
   rows[#rows+1]={card=c,returned=returned,again=again}
   eq(returned[1],true,'Blood upgrade accepted');eq(again[1],false,'Blood upgrade once');eq(c.costReduction,nil,'Blood reduction cleared')
  end
  eq(rows[2].card.combatCost,2,'Blood reduced base drops one');eq(rows[3].card.combatCost,0,'Blood base floor is zero')
  eq(rows[4].card.turnCost,4,'Blood turn cost preserves signed delta');eq(rows[4].card.costForTurn,4,'Blood synchronizes legacy turn cost')
  eq(rows[5].card.turnCost,0,'Blood zero turn cost stays zero');eq(rows[6].card.turnCost,0,'Blood below-zero raw base precedes turn delta')
  local c=inst('blood_for_blood',{combatCost=2,turnCost=5});local returned=table.pack(T.onUpgrade(s,c))
  eq(c.upgraded,false,'direct Blood hook does not set upgraded');eq(c.upgrades,nil,'direct Blood hook does not increment count');eq(c.turnCost,4,'direct Blood hook delta')
  observe({state=s,rows=rows,direct=c,returned=returned},'Blood for Blood full field cost upgrade results')
 end)
 test('malformed values retain partial writes and exact errors',function()
  local rows={}
  for _,spec in ipairs({
   {'false upgrade',inst('false_upgrade')},
   {'invalid Blood combat cost',inst('blood_for_blood',{combatCost=-1,costForTurn=2})},
   {'invalid Blood turn cost',inst('blood_for_blood',{turnCost='bad'})},
   {'invalid upgrade count',inst('cheaper',{upgrades='bad',costOverride=4,costForTurn=3})},
   {'invalid ordinary turn cost',inst('cheaper',{costOverride=3,costForTurn=false})},
  })do
   local s=state();local returned=result(spec[1],C.upgrade,s,spec[2])
   if spec[1]=='invalid ordinary turn cost'then eq(returned[1],true,'false turn falls back to base')else eq(returned[1],false,'malformed upgrade fails')end
   rows[#rows+1]={state=s,card=spec[2],returned=returned,label=spec[1]}
  end
  eq(rows[2].card.turnCost,2,'legacy turn copy precedes failed Blood validation')
  eq(rows[3].card.combatCost,4,'base materialization precedes failed Blood turn validation')
  eq(rows[4].card.costOverride,nil,'ordinary override clears before late count failure');eq(rows[4].card.costForTurn,0,'ordinary turn write survives late count failure')
  local s=state();local absent=inst('unknown');rows[#rows+1]={returned=result('already upgraded Blood hook',T.onUpgrade,s,inst('blood_for_blood',{upgraded=true}))}
  rows[#rows+1]={returned=result('unknown base definition',C.combatBaseCost,s,absent)}
  observe(rows,'malformed inputs exact pcall return tuples and partial writes')
 end)
end
if group=='all'or group=='slots'then
 test('ordinary dynamic function replacements nil false and saved references',function()
  local saved={valid=C.validSearingBlowCopy,cost=C.combatBaseCost,can=C.canUpgrade,upgrade=C.upgrade,hook=T.onUpgrade}
  local rows={};local s=state();local token=setmetatable({kind='replacement error'},{kind='error metatable'});token.self=token
  C.validSearingBlowCopy=function(c)eq(c.cardId,'strike','validator receives exact card');return false end
  eq(C.canUpgrade(s,inst('strike')),false,'canUpgrade reads current validator')
  for _,value in ipairs({{tag='nil'},{tag='false',value=false}})do
   C.validSearingBlowCopy=value.value
   rows[#rows+1]={kind=value.tag,returned=result('validator '..value.tag,C.canUpgrade,s,inst('strike'))}
   eq(rows[#rows].returned[1],false,'nil false validator throws rather than restoring a default')
  end
  C.validSearingBlowCopy=saved.valid
  C.canUpgrade=function()return false end;eq(saved.upgrade(s,inst('strike')),false,'saved upgrade reads current eligibility')
  for _,value in ipairs({{tag='nil'},{tag='false',value=false}})do
   C.canUpgrade=value.value;rows[#rows+1]={kind=value.tag,returned=result('eligibility '..value.tag,saved.upgrade,s,inst('strike'))}
   eq(rows[#rows].returned[1],false,'nil false eligibility throws')
  end
  C.canUpgrade=saved.can
  local calls={};C.combatBaseCost=function(owner,c)eq(owner,s,'cost exact state');calls[#calls+1]=c;return 6 end
  local c=inst('cheaper',{costOverride=7,costForTurn=8});eq(C.upgrade(s,c),true,'dynamic cost replacement executes');eq(c.costForTurn,3,'upgrade uses replaced cost return')
  for _,value in ipairs({{tag='nil'},{tag='false',value=false}})do
   C.combatBaseCost=value.value;rows[#rows+1]={kind=value.tag,returned=result('cost '..value.tag,saved.upgrade,s,inst('cheaper',{costOverride=7}))}
   eq(rows[#rows].returned[1],false,'nil false cost throws')
  end
  C.combatBaseCost=saved.cost
  T.onUpgrade=function(owner,card)eq(owner,s,'Blood hook exact state');card.hookAlias=token;error(token,0)end
  local blood=inst('blood_for_blood',{costForTurn=2});local returned=result('table Blood hook error',C.upgrade,s,blood)
  eq(returned[1],false,'hook exception surfaces');eq(returned[2],token,'hook exception object identity');eq(blood.combatCost,4,'base write precedes hook');eq(blood.turnCost,2,'turn write precedes hook');eq(blood.upgraded,false,'upgrade flag follows hook')
  for _,value in ipairs({{tag='nil'},{tag='false',value=false}})do
   T.onUpgrade=value.value;rows[#rows+1]={kind=value.tag,returned=result('Blood hook '..value.tag,C.upgrade,s,inst('blood_for_blood'))}
   eq(rows[#rows].returned[1],false,'nil false Blood hook throws')
  end
  T.onUpgrade=saved.hook
  C.upgrade=function(owner,card)eq(owner,s,'Stasis replacement exact state');card.externalUpgrade=token;return false end
  local orb={id='orb'};local held=inst('strike');s.act2StasisCards={orb=held};s.player.statuses.master_reality=1
  local stasis=table.pack(S.death(s,orb));eq(held.externalUpgrade,token,'Stasis reads current upgrade slot');eq(held.upgraded,false,'Stasis replacement is not bypassed')
  for _,value in ipairs({{tag='nil'},{tag='false',value=false}})do
   C.upgrade=value.value;rows[#rows+1]={kind=value.tag,returned=result('upgrade '..value.tag,S.death,s,orb)}
   eq(rows[#rows].returned[1],false,'nil false Stasis upgrade throws')
  end
  C.upgrade=saved.upgrade
  observe({state=s,card=c,blood=blood,returned=returned,token=token,rows=rows,calls=calls,saved=saved,stasis=stasis},'dynamic public slots saved functions exact failures and aliases')
 end)
 test('catalog then validation and two Stasis eligibility reads preserve error order',function()
  local s=state();local c=inst('strike');local saved=C.validSearingBlowCopy
  local token={kind='catalog read failure'};token.self=token;local calls={}
  local cards=setmetatable({},{__index=function(_,key)calls[#calls+1]=key;error(token,0)end})
  C.validSearingBlowCopy=function()error('VALIDATOR MUST NOT RUN')end
  local returned=result('catalog before validator',C.canUpgrade,{catalog={cards=cards}},c);C.validSearingBlowCopy=saved
  eq(returned[2],token,'catalog failure precedes validator');eq(#calls,1,'catalog read exactly once')
  local can=C.canUpgrade;local order={};local orb={id='orb'};s.act2StasisCards={orb=c};s.player.statuses.master_reality=1
  C.canUpgrade=function(owner,card)eq(owner,s,'Stasis eligibility exact state');eq(card,c,'Stasis eligibility exact card');order[#order+1]='can';return #order==1 end
  local death=table.pack(S.death(s,orb));C.canUpgrade=can
  eq(#order,2,'Stasis checks eligibility twice through upgrade');eq(c.upgraded,false,'second refusal prevents mutation')
  observe({state=s,returned=returned,error=token,calls=calls,order=order,death=death},'catalog failure identity and Stasis dynamic two-check ordering')
 end)
end
if group=='all'or group=='pairs'then
 test('Combat pairs copies the complete API with every live upgrade slot and unrelated raw fields',function()
  local names={'validSearingBlowCopy','combatBaseCost','canUpgrade','upgrade'}
  local saved={};for _,name in ipairs(names)do saved[name]=C[name]end
  local originalExtra,originalFalse,originalNumber=C.pairsExtra,C.pairsFalse,C[43]
  local marker=setmetatable({kind='copied API marker'},{kind='copied API metadata'});marker.self=marker
  C.pairsExtra=marker;C.pairsFalse=false;C[43]=marker
  local rows={};local replacements={}
  for _,name in ipairs(names)do local label=name;replacements[name]=function()return label,marker end end
  local function enumerate(kind)
   local api,seen={},{}
   for key,value in pairs(C)do
    eq(seen[key],nil,'Combat pairs yields each public key exactly once')
    seen[key]=1;api[key]=value
   end
   for _,name in ipairs(names)do
    eq(api[name],C[name],'copied API retains current upgrade slot identity')
    eq(seen[name],C[name]~=nil and 1 or nil,'Combat pairs omits nil but retains false upgrade slots')
   end
   eq(api.pairsExtra,marker,'Combat pairs retains unrelated raw table field')
   eq(api.pairsFalse,false,'Combat pairs retains unrelated raw false field')
   eq(api[43],marker,'Combat pairs retains unrelated raw numeric field')
   for _,name in ipairs({'statusDefinition','bloodCost','onUpgrade'})do eq(api[name],nil,'Combat pairs does not leak owner-only helper slots')end
   local row={kind=kind,api=api,seen=seen};rows[#rows+1]=row;return row
  end
  local normal=enumerate('original')
  for _,name in ipairs(names)do C[name]=replacements[name]end
  local replaced=enumerate('replaced')
  for _,name in ipairs(names)do
   eq(normal.api[name],saved[name],'already copied API retains saved function after replacement')
   local returned=table.pack(replaced.api[name]());eq(returned.n,2,'copied replacement return arity')
   eq(returned[1],name,'copied replacement executes selected slot');eq(returned[2],marker,'copied replacement return alias')
  end
  for _,name in ipairs(names)do C[name]=nil end
  enumerate('nil')
  for _,name in ipairs(names)do C[name]=false end
  enumerate('false')
  for _,name in ipairs(names)do C[name]=saved[name]end
  local restored=enumerate('restored')
  for _,name in ipairs(names)do eq(restored.api[name],saved[name],'pairs restore preserves original function identity')end
  -- Opening pairs must not freeze virtual values or share iterator progress.
  -- No assertion depends on Lua hash traversal order.
  local nextA,stateA,keyA=pairs(C);local nextB,stateB,keyB=pairs(C)
  for _,name in ipairs(names)do C[name]=replacements[name]end
  local apiA,apiB,seenA,seenB={},{},{},{};local doneA,doneB=false,false
  local function advance(step,context,key,api,seen)
   local name,value=step(context,key)
   if name~=nil then eq(seen[name],nil,'interleaved Combat iterator has no duplicate key');seen[name]=1;api[name]=value end
   return name
  end
  for _=1,1000 do
   if not doneA then keyA=advance(nextA,stateA,keyA,apiA,seenA);doneA=keyA==nil end
   if not doneB then keyB=advance(nextB,stateB,keyB,apiB,seenB);doneB=keyB==nil end
   if doneA and doneB then break end
  end
  eq(doneA and doneB,true,'both independent Combat iterators terminate')
  for _,name in ipairs(names)do
   eq(apiA[name],replacements[name],'first iterator reads replacement made before yield')
   eq(apiB[name],replacements[name],'second iterator has independent progress and fresh slot values')
   eq(seenA[name],1,'first iterator visits each upgrade slot once');eq(seenB[name],1,'second iterator visits each upgrade slot once')
  end
  for key,value in pairs(apiA)do eq(apiB[key],value,'interleaved complete API values agree')end
  for key,value in pairs(apiB)do eq(apiA[key],value,'interleaved complete API inventories agree')end
  -- This probes duplicate suppression only, not rawset/owner synchronization.
  rawset(C,'upgrade',marker);local shadow=enumerate('raw same-name shadow')
  eq(shadow.api.upgrade,marker,'raw same-name field is enumerated once without a virtual duplicate')
  rawset(C,'upgrade',nil)
  for _,name in ipairs(names)do C[name]=saved[name]end
  C.pairsExtra,C.pairsFalse,C[43]=originalExtra,originalFalse,originalNumber
  local cleaned={};for key,value in pairs(C)do cleaned[key]=value end
  eq(cleaned.pairsExtra,originalExtra,'deleted unrelated raw field stays absent')
  eq(cleaned.pairsFalse,originalFalse,'deleted unrelated false field stays absent');eq(cleaned[43],originalNumber,'deleted numeric field stays absent')
  observe({rows=rows,cleaned=cleaned,saved=saved,replacements=replacements,marker=marker,interleaved={apiA=apiA,apiB=apiB,seenA=seenA,seenB=seenB}},'Combat pairs complete public API snapshots function nil false and raw keys')
 end)
 test('real pairs copied API drains queued Armaments then completes UID choice and upgrade',function()
  local A=require('abyss_card_actions');local D=require('abyss_data')
  local s=C.new(D,{seed=42,deck={'strike'},enemies={'cultist'},cardRandomSeed='42',
   beforeFirstTurn=function(owner)owner.drainingCardActions=true;return true end})
  s.drainingCardActions=nil;s.cardActions=nil;s.queuedCards=nil;s.resolvingCard=nil
  local strike={uid=101,cardId='strike'};local defend={uid=102,cardId='defend'}
  s.hand={strike,defend};s.draw={};s.discard={};s.exhaust={}
  local armaments={uid=301,cardId='armaments'};local queued={{card=armaments,targetIndex=1}}
  s.queuedCards=queued
  local api={};for key,value in pairs(C)do api[key]=value end
  eq(api.canUpgrade,C.canUpgrade,'real copied API includes upgrade eligibility')
  eq(api.upgrade,C.upgrade,'real copied API includes upgrade execution')
  observe({state=s,api=api,queued=queued,armaments=armaments,strike=strike,defend=defend},'copied API real queued Armaments before drain')
  local drained=result('copied API Armaments drain',A.drain,api,s)
  eq(drained[1],true,'real copied API queued Armaments drains successfully');eq(drained.n,1,'real copied API drain returns no values')
  assert(s.pendingChoice,'[CARD_UPGRADE] real copied API opens Armaments choice')
  eq(s.pendingChoice.op,'upgradeHand','queued Armaments opens upgrade choice');eq(s.queuedCards,queued,'paused queued identity preserved');eq(#queued,0,'queued Armaments popped once')
  eq(strike.upgraded,nil,'choice has not upgraded strike early');eq(defend.upgraded,nil,'choice has not upgraded defend early')
  eq(s.player.block,5,'queued Armaments gains original five Block before choice')
  local choice=s.pendingChoice;local options=choice.uids
  eq(#options,2,'real copied API offers both unupgraded cards');eq(options[1],strike.uid,'first Armaments choice UID');eq(options[2],defend.uid,'second Armaments choice UID')
  observe({state=s,api=api,queued=queued,choice=choice,drained=drained,armaments=armaments},'copied API real queued Armaments pauses with complete choice graph')
  local selected=result('copied API Armaments choice',A.choose,api,s,choice.token,strike.uid)
  eq(selected[1],true,'copied API Armaments choice call succeeds');eq(selected[2],true,'copied API Armaments choice accepted');eq(selected.n,2,'copied API Armaments choice exact return arity')
  eq(s.pendingChoice,nil,'copied API choice cleared');eq(strike.upgraded,true,'copied API upgrades selected strike');eq(strike.upgrades,1,'copied API increments selected count once');eq(defend.upgraded,nil,'copied API leaves unselected defend unchanged')
  eq(s.hand[1],strike,'selected strike retains original hand identity');eq(s.queuedCards,nil,'completed copied API drains queued owner')
  eq(C.cardDefinition(s,strike).effects[1].value,9,'selected Strike uses upgraded damage')
  observe({state=s,api=api,queued=queued,choice=choice,drained=drained,selected=selected,armaments=armaments,strike=strike,defend=defend},'copied API Armaments completed upgrade disposal queues and full battle graph')
 end)
end
if group=='all'or group=='stasis'then
 test('Master Reality hand boundaries empty custody malformed and Blood return',function()
  local rows={}
  for _,size in ipairs({0,9,10,11})do
   local s=state();for i=1,size do s.hand[i]=inst('strike',{uid=i})end
   local c=inst('blood_for_blood',{combatCost=2,turnCost=0});s.act2StasisCards={orb=c};s.player.statuses.master_reality=1
   local returned=table.pack(S.death(s,{id='orb'}));eq(returned[1].forceDiscard,size==10,'death uses exact hand equality')
   eq(c.upgraded,size~=10,'Master Reality only skips exactly full hand');eq(s.act2StasisCards.orb,c,'death preserves custody identity')
   rows[#rows+1]={state=s,card=c,returned=returned}
  end
  local s=state();local empty=table.pack(S.death(s,{id='orb'}));eq(empty.n,0,'absent custody returns no values')
  s.act2StasisCards={};local again=table.pack(S.death(s,{id='orb'}));eq(again.n,0,'empty custody returns no values')
  local malformed=inst('searing_blow',{searingBlowCopyUpgrades=2,upgrades=1});s.act2StasisCards.orb=malformed;s.player.statuses.master_reality=1
  local bad=table.pack(S.death(s,{id='orb'}));eq(malformed.upgraded,false,'malformed constructor not upgraded');eq(bad[1].op,'stasis_return','malformed constructor still plans return')
  s.player.statuses.master_reality=0;local noPower=inst('strike');s.act2StasisCards.orb=noPower;S.death(s,{id='orb'});eq(noPower.upgraded,false,'absent Master Reality no upgrade')
  observe({rows=rows,state=s,empty=empty,again=again,malformed=malformed,bad=bad},'Stasis full overfull empty malformed and Blood custody graphs')
 end)
 test('actual battle Stasis release and late upgrade rollback retry',function()
  local D=require('abyss_data');local R=require('abyss_sts_random');local streams={}
  for _,key in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[key]=R.fromSeed('42')end
  local s=C.new(D,{enemies={'bronze_orb','cultist'},deck={'strike','blood_for_blood'},roomSeed='42',roomStreams=streams})
  local orb=s.enemies[1];local blood,strike
  for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do if c.cardId=='blood_for_blood'then blood=c else strike=c end end end
  assert(blood and strike,'[CARD_UPGRADE] actual battle both cards')
  s.hand={strike};s.draw={blood};s.discard={};s.player.statuses.master_reality=1;blood.combatCost=2;blood.turnCost=0
  C.applyEffects(s,{{op='enemyStasis',value=1}},orb,s.player)
  eq(s.act2StasisCards[orb.id],blood,'actual Stasis captures original card');orb.hp=1
  local marker=setmetatable({kind='battle alias'},{kind='battle metadata'});marker.self=marker
  blood.aliasA,blood.aliasB=marker,marker;s.alias=marker
  observe(s,'actual battle complete graph before late Stasis failure')
  local restore=unchanged(s);local upgrade=C.upgrade;local reached=false
  local fault=setmetatable({kind='late Stasis upgrade error',card=blood},{kind='fault metadata'});fault.self=fault
  C.upgrade=function(owner,c)local ok=upgrade(owner,c);eq(c.turnCost,0,'real Stasis Blood zero turn cost');reached=ok;error(fault,0)end
  local returned=result('actual battle late upgrade error',C.play,s,strike.uid,1);C.upgrade=upgrade
  eq(returned[1],false,'actual battle surfaces late exception');eq(returned[2],fault,'actual battle retains exact exception');eq(reached,true,'late failure follows successful upgrade');restore()
  observe({state=s,returned=returned,error=fault},'actual battle complete rollback aliases metatables queues RNG and error')
  returned=table.pack(C.play(s,strike.uid,1));eq(returned[1],true,'actual battle retry succeeds')
  eq(s.act2StasisCards[orb.id],nil,'actual Stasis custody released');local found
  for _,c in ipairs(s.hand)do if c.cardId=='blood_for_blood'then found=c end end
  assert(found and found~=blood,'[CARD_UPGRADE] release makes a detached identity copy');eq(found.upgraded,true,'returned card upgraded');eq(found.combatCost,1,'returned Blood base falls once');eq(found.turnCost,0,'returned Blood turn remains zero')
  eq(found.aliasA,found.aliasB,'release preserves nested aliases');assert(found.aliasA~=marker,'[CARD_UPGRADE] release copies nested metadata')
  observe({state=s,returned=returned,released=found,original=blood},'actual battle successful retry release copied metadata events and RNG')
 end)
end
print('CARD_UPGRADE_CONTRACT_PASS '..group..' '..count)
