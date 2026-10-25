-- TASK-15.19: pinned source getLouse Boolean contract, not complete PC seed parity.
-- Selection cases avoid constructing Combat; integration retains real HP/AI/shuffle/Curl.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Map,Nodes,C,R,I,Data=require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_inventory'),require('abyss_data')
local passed,failed=0,0
local part=ABYSS_LOUSE_PART or 1
assert(part>=1 and part<=5 and part%1==0)
local function repr(v)
 if type(v)~='table' then return tostring(v) end
 local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
 local out={};for _,k in ipairs(keys)do out[#out+1]=tostring(k)..'='..repr(v[k])end;return '{'..table.concat(out,',')..'}'
end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function check(ok,label,detail)
 if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..label..(detail and ' '..detail or ''))
 return ok
end
local function checkeq(actual,expected,label)
 local ok=equal(actual,expected)
 return check(ok,label,not ok and ('expected='..repr(expected)..' actual='..repr(actual)):sub(1,700) or nil)
end
local function ids(battle)local a={};for _,e in ipairs(battle.enemies)do a[#a+1]=e.definitionId end;return a end
local function pattern(a)local s='';for _,id in ipairs(a)do s=s..(id=='red_louse' and 'R' or id=='green_louse' and 'G' or '?')end;return s end
local literal={
 [2]={'GG','GR','RG','RR'},
 [3]={'GGG','GGR','GRG','GRR','RGG','RGR','RRG','RRR'}
}
-- Each source getLouse call is an independent Boolean. No pool/selection code read.
local function oracle(flags)
 local out={};for i,b in ipairs(flags)do out[i]=b and 'red_louse' or 'green_louse' end;return out
end
local function flags(n,mask)
 local out={};for i=1,n do out[i]=math.floor(mask/2^(n-i))%2==1 end;return out
end
local function fresh(enc,seed,advance)
 local r=Run.new(Data,seed or 42);r.floor=enc=='louse_pair' and 1 or 4
 for _=1,advance or 0 do R.randomInt(r.miscRng,999) end
 return r
end
local function observe(bits,fn)
 local old=R.randomBoolean;local calls=0;local selected,otherCalls={},{}
 local methods={};for _,key in ipairs({'randomInt','randomIntBetween','randomBooleanChance','randomLongHex','shuffle'})do methods[key]=R[key];R[key]=function(state,...)
  otherCalls[state]=(otherCalls[state] or 0)+1;return methods[key](state,...)
 end end
 R.randomBoolean=function(state)
  selected[state]=true;calls=calls+1;local actual=old(state)
  if bits then assert(calls<=#bits,'extra color Boolean');return bits[calls] end
  return actual
 end
 local ok,err=pcall(fn,function()
  local unexpected=0;for state in pairs(selected)do unexpected=unexpected+(otherCalls[state] or 0)end
  return calls,unexpected
 end)
 R.randomBoolean=old;for k,v in pairs(methods)do R[k]=v end
 assert(ok,err)
end
local function expectedStream(run,n,floor)
 local s=floor and Run.roomStreams(run,floor).miscRng or R.cloneState(run.miscRng);local choices={}
 for i=1,n do choices[i]=R.randomBoolean(s) end
 return s,oracle(choices)
end
local function referenceBattle(run,roster)
 local seed=require('abyss_run_seed').forFloor(run.runSeed,run.floor)
 local reference=C.new(Data,{seed=run.seed,hp=run.hp,maxHp=run.maxHp,gold=run.gold,deck=run.deck,
  enemies=roster,cardRandomSeed=seed,shuffleSeed=seed})
 assert(equal(Data.rules.player.startingRelics,{'burning_blood'}))
 reference.relics={'burning_blood'};reference.relicCounters={};reference.relicCombat={attackPlayed=false}
 return reference
end

if part==1 then
print('SECTION pure source oracle, literal distribution, no production constructor')
for n=2,3 do
 local histogram={};for m=0,2^n-1 do local output=oracle(flags(n,m));local s=pattern(output)
  assert(s==literal[n][m+1]);local reds=select(2,s:gsub('R',''));histogram[reds]=(histogram[reds] or 0)+1
 end
 checkeq(histogram,n==2 and {[0]=1,[1]=2,[2]=1} or {[0]=1,[1]=3,[2]=3,[3]=1},'oracle '..n..'-slot red-count multiplicities')
end

print('SECTION Run selection seam, all 4+8 ordered source branches, HP/AI never invoked')
for n=2,3 do
 local enc=n==2 and 'louse_pair' or 'louse_trio';local seen={}
 for m=0,2^n-1 do
  local r=fresh(enc,42,5);local before=repr(r);local captured;local oldNew=C.new
  C.new=function(_,options)captured=C.copy(options.enemies);return nil,'audit_selection_stop'end
  observe(flags(n,m),function(count)
   local ok,reason=Run.startCombat(r,enc);assert(ok==false and reason=='audit_selection_stop');assert(before==repr(r),'failed start mutated run')
   local calls,extra=count();local actual=pattern(captured);seen[actual]=(seen[actual] or 0)+1
   checkeq(actual,literal[n][m+1],enc..' mask '..m..' ordered colors')
   checkeq(calls,n,enc..' mask '..m..' Boolean count');assert(extra==0,'unexpected non-Boolean selection RNG')
  end)
  C.new=oldNew
 end
 checkeq(seen,n==2 and {GG=1,GR=1,RG=1,RR=1} or {GGG=1,GGR=1,GRG=1,GRR=1,RGG=1,RGR=1,RRG=1,RRR=1},enc..' complete ordered support')
end

print('SECTION real Run.startCombat, controlled color only, production HP/AI/shuffle/Curl intact')
for n=2,3 do for _,allRed in ipairs({false,true})do
 local enc=n==2 and 'louse_pair' or 'louse_trio';local r=fresh(enc,42,5);local wanted=expectedStream(r,n)
 local bits={};for i=1,n do bits[i]=allRed end
 local wantedIds=oracle(bits);local oldMisc,oldEvent,oldData,oldDeck=r.miscRng,r.eventRng,r.data,r.deck
 local eventBefore,miscBefore,dataBefore,deckBefore=repr(oldEvent),repr(oldMisc),repr(oldData),repr(oldDeck)
 observe(bits,function(count)
  assert(Run.startCombat(r,enc));local calls,extra=count()
  local label=enc..' real '..(allRed and 'all-red' or 'all-green')
  checkeq(ids(r.combat),wantedIds,label..' colors');checkeq(calls,n,label..' Boolean count');checkeq(R.snapshot(r.miscRng),R.snapshot(wanted),label..' exact misc state')
  check(extra==0,label..' no pool/shuffle/integer selection draw')
 end)
 check(r.eventRng==oldEvent and repr(oldEvent)==eventBefore and repr(oldMisc)==miscBefore and r.data==oldData and repr(oldData)==dataBefore and r.deck==oldDeck and repr(oldDeck)==deckBefore,enc..' original stream/catalog/deck isolated')
 local actual=ids(r.combat);local reference=referenceBattle(r,actual)
 checkeq(r.combat,reference,enc..' actual ordered group exactly equals explicit real Combat construction')
end end

end
local fixtures={
 {kind='combat',enc='louse_pair',seed=65536,prefix=0},
 {kind='combat',enc='louse_trio',seed=65535,prefix=3},
 {kind='event',enc='louse_trio',seed=65535,prefix=3},
 {kind='event',enc='louse_pair',seed=65536,prefix=0}
}
local mapTemplates={}
local function nodeSetup(f)
 local r=Run.new(Data,f.seed)
 mapTemplates[f.seed]=mapTemplates[f.seed] or Map.generate(Data,f.seed)
 local m=C.copy(mapTemplates[f.seed]);local Q=require('abyss_encounter_queue')
 for _=1,f.prefix do
  local _,nextQueue=Q.consume(r.encounters,'normal');r.encounters=assert(nextQueue)
  assert(Map.choose(m,Map.available(m)[1].id))
 end
 assert(Q.peek(r.encounters,'normal')==(f.enc=='louse_pair' and '2 Louse' or '3 Louse'))
 local available=assert(Map.available(m)[1]);local node
 for _,v in ipairs(m.nodes)do if v.id==available.id then node=v end end
 assert(node);node.type=f.kind;node.eventId=nil;f.id,f.floor=node.id,node.floor
 -- Explicit source-queue/frontier checkpoint, not a naturally played route.
 -- Advance the real event stream to a monster bucket; do not replace its value.
 if f.kind=='event' then
  local found=false
  for _=1,100 do
   if R.randomFloat(R.cloneState(r.eventRng))<0.1 then found=true;break end
   R.randomFloat(r.eventRng)
  end
  assert(found)
 end
 return r,m
end
if part==2 then
print('SECTION real reachable Nodes.enter; frontier placement only, not claimed full played run')
for _,f in ipairs(fixtures)do
 local r,m=nodeSetup(f);local n=f.enc=='louse_pair' and 2 or 3;local wanted,wantedIds=expectedStream(r,n,f.floor);local oldEvent=R.snapshot(r.eventRng)
 local label=f.kind..' '..f.enc..' seed='..f.seed..' node='..f.id
 observe(nil,function(count)
  assert(Nodes.enter(r,m,f.id));assert(r.encounterId==f.enc and r.nodeFlow.sourceType==f.kind)
  local calls,extra=count();print('ENTRY '..label..' expected='..pattern(wantedIds)..' actual='..pattern(ids(r.combat)))
  checkeq(ids(r.combat),wantedIds,label..' natural colors');checkeq(calls,n,label..' Boolean count');checkeq(R.snapshot(r.miscRng),R.snapshot(wanted),label..' exact misc state')
  check(extra==0,label..' no other misc draw')
 end)
 checkeq(r.eventRng.counter-oldEvent.counter,f.kind=='event' and 1 or 0,label..' only unknown-room event roll')
 local before=repr({run=r,map=m});Nodes.view(r,m);Nodes.view(r,m);assert(Nodes.enter(r,m,f.id)==false);assert(Run.startCombat(r,f.enc)==false)
 checkeq(repr({run=r,map=m}),before,label..' view/reentry no new draw')
end

end
-- Preserve each original nested reference as well as its value, including maps,
-- catalogs and streams. Structural equality alone would miss replacement.
local function freeze(...)
 local refs={}
 local function visit(t)
  if type(t)~='table' or refs[t] then return end
  local fields={};refs[t]=fields;for k,v in pairs(t)do fields[k]=v;visit(v)end
 end
 for _,v in ipairs({...})do visit(v)end
 return function()
  for t,fields in pairs(refs)do
   for k,v in pairs(fields)do assert(t[k]==v,'changed original field '..tostring(k))end
   for k in pairs(t)do assert(fields[k]~=nil,'added original field '..tostring(k))end
  end
 end
end
print('SECTION failure guards and retry through direct, ordinary and unknown-room entry')
local entries={{kind='direct',enc='louse_pair'},{kind='direct',enc='louse_trio'}}
for _,f in ipairs(fixtures)do entries[#entries+1]=f end
for _,f in ipairs(entries)do if part==(f.kind=='direct' and 2 or f.kind=='combat' and 3 or 4)then
for _,mode in ipairs({'constructor-nil','constructor-throw','before-opening','after-opening'})do
 local function setup()if f.kind=='direct' then return fresh(f.enc,42,5)else return nodeSetup(f)end end
 local function enter(r,m)if f.kind=='direct' then return Run.startCombat(r,f.enc)else return Nodes.enter(r,m,f.id)end end
 local r,m=setup();local stable=freeze(r,m);local before=C.copy({run=r,map=m});local oldMisc=r.miscRng
 local n=f.enc=='louse_pair' and 2 or 3;local wanted,wantedIds=expectedStream(r,n,f.kind~='direct' and f.floor or nil)
 local oldNew,oldOpening=C.new,I.applyOpening
 if mode=='constructor-nil' then C.new=function()return nil,'injected_failure'end
 elseif mode=='constructor-throw' then C.new=function()error('injected_failure')end
 else local calls=0;I.applyOpening=function(...)
  calls=calls+1;if calls==(mode=='before-opening' and 1 or 2)then return false,'injected_failure'end
  return oldOpening(...)
 end end
 local called,ok
 observe(nil,function(count)
  called,ok=pcall(enter,r,m)
  local draws,extra=count()
  local wantedDraws=f.kind~='direct' and (mode=='constructor-nil' or mode=='constructor-throw') and 0 or n
  checkeq(draws,wantedDraws,f.kind..' '..f.enc..' '..mode..' staged Boolean count');assert(extra==0)
 end)
 C.new,I.applyOpening=oldNew,oldOpening
 local label=f.kind..' '..f.enc..' '..mode
 check((f.kind=='direct' and mode=='constructor-throw' and not called or called and ok==false),label..' fails')
 stable();checkeq({run=r,map=m},before,label..' preserves all run/map references and values');assert(r.miscRng==oldMisc)
 assert(enter(r,m));checkeq(ids(r.combat),wantedIds,label..' retry colors');checkeq(R.snapshot(r.miscRng),R.snapshot(wanted),label..' retry exact misc state')
 local clean,cleanMap=setup();assert(enter(clean,cleanMap))
 checkeq({run=r,map=m},{run=clean,map=cleanMap},label..' retry full state matches clean entry')
end end end

if part==5 then
print('SECTION other 16 encounters retain full construction and selection state')
local groups={
 cultist_solo={'cultist'},jaw_solo={'jaw_worm'},medium_slimes={'acid_slime_m','spike_slime_m'},
 large_acid={'acid_slime_l'},large_spike={'spike_slime_l'},looter_solo={'looter'},
 blue_slaver_solo={'blue_slaver'},red_slaver_solo={'red_slaver'},fungi_pair={'fungi_beast','fungi_beast'},
 wildlife={'jaw_worm','green_louse'},elite_nob={'gremlin_nob'},elite_lagavulin={'lagavulin'},
 elite_sentries={'sentry','sentry','sentry'},boss_guardian={'guardian'},small_slimes={'spike_slime_s','acid_slime_m'},
 gremlin_gang={'mad_gremlin','shield_gremlin','fat_gremlin','fat_gremlin'}
}
local unchanged=0
for _,e in ipairs(Data.enemies.encounters)do if e.id~='louse_pair' and e.id~='louse_trio' then
 unchanged=unchanged+1;local r=Run.new(Data,42);r.floor=e.minFloor
 local oldMisc,oldEvent=r.miscRng,r.eventRng;local stable=freeze(r.data,r.deck,oldMisc,oldEvent)
 local wanted=R.cloneState(oldMisc)
 if e.id=='small_slimes' then R.randomBoolean(wanted)
 elseif e.id=='gremlin_gang' then for _,upper in ipairs({7,6,5,4})do R.randomInt(wanted,upper)end end
 assert(Run.startCombat(r,e.id));stable()
 checkeq(ids(r.combat),assert(groups[e.id]),e.id..' original ordered roster')
 checkeq(r.miscRng,wanted,e.id..' exact misc state');assert(r.eventRng==oldEvent)
 if e.id~='small_slimes' and e.id~='gremlin_gang' then assert(r.miscRng==oldMisc)end
 checkeq(r.combat,referenceBattle(r,groups[e.id]),e.id..' full independent Combat state')
end end
checkeq(unchanged,16,'all other encounters exercised')
for _,roster in ipairs({{'red_louse','green_louse'},{'green_louse','green_louse','green_louse'}})do
 observe({},function(count)
  local battle=C.new(Data,{seed=42,enemies=roster});checkeq(ids(battle),roster,'explicit low-level roster is unchanged');checkeq(count(),0,'explicit construction consumes no misc Boolean')
  assert(battle.enemies[1]~=battle.enemies[2] and battle.enemies[1].intents~=battle.enemies[2].intents and battle.enemies[1].statuses~=battle.enemies[2].statuses,'repeated colors share actor state')
 end)
end
end
print('LOUSE_COLORS part='..part..' passed='..passed..' failed='..failed)
assert(failed==0,tostring(failed)..' louse color contract failures')
