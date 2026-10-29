package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local A=require('abyss_card_actions')
local data=require('abyss_data')
local count=0
local function eq(a,b,label) assert(a==b,'[EXHAUST_CONTRACT] '..label..': '..tostring(a)..' ~= '..tostring(b)) end
local function serialize(value,seen)
    if type(value)=='function' then return 'function' end
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    seen=seen or {n=0};if seen[value]then return 'ref:'..seen[value] end
    seen.n=seen.n+1;seen[value]=seen.n
    local keys={};for k in pairs(value)do if k~='statusDefinitions'then keys[#keys+1]=k end end
    table.sort(keys,function(a,b)return type(a)..tostring(a)<type(b)..tostring(b)end)
    local out={};for _,k in ipairs(keys)do out[#out+1]=serialize(k,seen)..'='..serialize(value[k],seen)end
    return '{'..table.concat(out,';')..'}'
end
local function trace(s)
    if not ABYSS_EXHAUST_TRACE then return end
    local snapshot={};for k,v in pairs(s)do
        if k~='catalog'and k~='rules'and k~='sourcePools'then snapshot[k]=v end
    end
    print('EXHAUST_TRACE '..serialize(snapshot))
end
-- Observe real queue boundaries and each completed action, preserving all
-- return values. Independent old/new VMs use these same observers.
for _,name in ipairs({'apply','enqueue'})do
    local original=A[name]
    A[name]=function(...)
        local args=table.pack(...)
        local result=table.pack(original(...))
        trace(args[name=='apply'and 2 or 1])
        return table.unpack(result,1,result.n)
    end
end
local function battle(size,hooks)
    local s=C.new(data,{seed=42,deck={'strike'},enemies={'cultist'},cardRandomSeed='42'})
    s.hand={};s.draw={};s.discard={};s.exhaust={};s.cardActions=nil
    for i=1,size do s.hand[i]={uid=100+i,cardId=i%2==0 and 'strike'or'defend'}end
    if hooks then
        C.addStatus(s.player,'dark_embrace',1);C.addStatus(s.player,'feel_no_pain',3)
        s.draw[1]={uid=201,cardId='strike'}
    end
    return s
end
local originalRandom=C.cardRandom
C.cardRandom=function(s,max)
    local result=originalRandom(s,max)
    s.randomCalls=s.randomCalls or {};s.randomCalls[#s.randomCalls+1]={max=max,result=result}
    return result
end
local function test(name,fn)fn();count=count+1;print('ok exhaust '..count..' '..name)end
test('single random exhaust keeps the alwaysRandom RNG boundary',function()
    for _,always in ipairs({false,true})do
        local s=battle(1,true);local card=s.hand[1]
        A.apply(C,s,{effect={op='exhaustRandom',alwaysRandom=always},source=s.player})
        eq(s.exhaust[1],card,'same exhausted instance');eq(#s.hand,0,'hand moved')
        eq(#(s.randomCalls or {}),always and 1 or 0,'singleton random call')
        trace(s)
    end
end)
test('fiend fire snapshots count and pushes exhausts above damage',function()
    for _,size in ipairs({0,1,4})do
        local s=battle(size,true);local resolved={[s.enemies[1].id]=7}
        A.apply(C,s,{effect={op='fiendFire',value=7,resolved=resolved},source=s.player,target=s.enemies[1]})
        eq(#(s.cardActions or {}),2*size,'original count')
        for i=1,size do
            eq(s.cardActions[i].effect.op,'exhaustRandom','exhaust before hit')
            eq(s.cardActions[i].effect.alwaysRandom,true,'consume singleton RNG')
            eq(s.cardActions[size+i].effect.resolved,resolved,'damage snapshot identity')
        end
        trace(s);A.drain(C,s);eq(#s.exhaust,size,'only original count exhausted');trace(s)
    end
end)
test('nonattacks freeze UIDs and reverse TOP exhaust before blocks',function()
    for _,op in ipairs({'exhaustNonAttacks','secondWind'})do
        for _,size in ipairs({0,1,4})do
            local s=battle(size,true);local first=s.hand[1];local expected=math.ceil(size/2)
            A.apply(C,s,{effect={op=op,value=5},source=s.player})
            eq(#(s.cardActions or {}),expected*(op=='secondWind'and 2 or 1),'queued count')
            if expected>0 then
                eq(s.cardActions[1].effect.uid,100+(2*expected-1),'reverse UID order')
                if op=='secondWind'then eq(s.cardActions[expected+1].effect.op,'block','block behind exhaust')end
            end
            trace(s);A.drain(C,s)
            eq(#s.exhaust,expected,'nonattack count')
            if first then eq(s.exhaust[expected],first,'original object identity')end
            trace(s)
        end
    end
end)
test('specific exhaust preserves missing UID and paused draining',function()
    local s=battle(4,true);local card=s.hand[3]
    A.apply(C,s,{effect={op='exhaustSpecific',uid=999},source=s.player})
    eq(#s.hand,4,'missing UID no movement')
    A.apply(C,s,{effect={op='exhaustSpecific',uid=card.uid},source=s.player})
    eq(s.exhaust[1],card,'selected instance');eq(s.hand[3].uid,104,'remaining order')
    s.pendingChoice={token='held'};local pending=s.cardActions;A.drain(C,s)
    eq(s.cardActions,pending,'choice pauses queue');trace(s)
    s.pendingChoice=nil;A.drain(C,s);trace(s)
end)
test('random empty hand never consumes RNG',function()
    local s=battle(0,true)
    A.apply(C,s,{effect={op='exhaustRandom',alwaysRandom=true},source=s.player})
    eq(s.randomCalls,nil,'empty RNG');eq(#s.exhaust,0,'empty exhaust');trace(s)
end)
test('real native play rolls back exhaust, hooks, RNG and all original references',function()
    local s=battle(4,true);local playing={uid=900,cardId='defend'}
    table.insert(s.hand,1,playing)
    s.catalog.cards.defend.effects={{op='fiendFire',value=1}}
    s.catalog.cards.defend.target='ENEMY';s.catalog.cards.defend.cost=0
    local saved={}
    local function capture(t)
        if type(t)~='table'or saved[t]then return end
        local values={};saved[t]=values
        for k,v in pairs(t)do values[k]=v;capture(k);capture(v)end
    end
    capture(s)
    local originalDefinition=C.cardDefinition
    C.cardDefinition=function(state,instance)
        if instance~=playing and #state.exhaust>0 then error('injected_exhaust_failure',0)end
        return originalDefinition(state,instance)
    end
    local ok,why=pcall(C.play,s,playing.uid,1)
    C.cardDefinition=originalDefinition
    eq(ok,false,'failure thrown');eq(why,'injected_exhaust_failure','same error')
    for original,values in pairs(saved)do
        for k,v in pairs(values)do eq(original[k],v,'restored original '..tostring(k))end
        for k,v in pairs(original)do eq(v,values[k],'no inserted key '..tostring(k))end
    end
    trace(s)
end)
C.cardRandom=originalRandom
print('LUA_CARD_ACTIONS_EXHAUST_PASS '..count)
