package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C, E, A, data = require('abyss_combat'), require('abyss_effects'), require('abyss_actor'), require('abyss_data')
local count, failed = 0, 0
local function eq(a,b,label) assert(a==b or (type(a)=='number' and type(b)=='number' and a~=a and b~=b),(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function test(name, run)
    count=count+1; local ok,err=pcall(run)
    if not ok then failed=failed+1 end
    print((ok and 'ok ' or 'not ok ')..count..' - '..name..(ok and '' or ': '..tostring(err)))
end
local function pair(n)
    return {{op='applyStatusAll',status='weak',value=n or 3,targetGroup='weak_then_vulnerable'},
        {op='applyStatusAll',status='vulnerable',value=n or 3,targetGroup='weak_then_vulnerable'}}
end
local function battle(upgraded)
    return C.new(data,{seed=42,deck={{cardId='shockwave',upgraded=upgraded}},enemies={'cultist','cultist'}})
end
local function snapshot(root)
    local seen={}
    local function visit(t)
        if type(t)~='table' or seen[t] then return end
        local row={};seen[t]=row
        for k,v in pairs(t) do row[k]=v;visit(k);visit(v) end
    end
    visit(root)
    return function()
        for original,row in pairs(seen) do
            for k,v in pairs(row) do eq(original[k],v,'changed '..tostring(k)) end
            for k,v in pairs(original) do eq(row[k],v,'inserted '..tostring(k)) end
        end
    end
end
local function statusOrder(s)
    local result={}
    for _,e in ipairs(s.events) do if e.kind=='status' then result[#result+1]=e.detail.target..':'..e.detail.status end end
    return table.concat(result,',')
end
local grouped='cultist_1:weak,cultist_1:vulnerable,cultist_2:weak,cultist_2:vulnerable'
local legacy='cultist_1:weak,cultist_2:weak,cultist_1:vulnerable,cultist_2:vulnerable'
local bad={
    {'single first',function() local p=pair();p[2]=nil;return p end},
    {'single second',function() local p=pair();p[1].targetGroup=nil;return p end},
    {'only first marked',function() local p=pair();p[2].targetGroup=nil;return p end},
    {'separated',function() local p=pair();table.insert(p,2,{op='energy',value=1});return p end},
    {'three members',function() local p=pair();p[3]=C.copy(p[1]);return p end},
    {'two groups',function() local p,q=pair(),pair();p[3],p[4]=q[1],q[2];return p end},
    {'reversed',function() local p=pair();p[1],p[2]=p[2],p[1];return p end},
    {'duplicate weak',function() local p=pair();p[2].status='weak';return p end},
    {'wrong status',function() local p=pair();p[1].status='frail';return p end},
    {'wrong op',function() local p=pair();p[1].op='applyStatus';return p end},
    {'unequal amounts',function() local p=pair();p[2].value=5;return p end},
    {'hole before markers',function() local p=pair();return {[2]=p[1],[3]=p[2]} end},
    {'hole between markers',function() local p=pair();return {[1]=p[1],[3]=p[2]} end},
    {'named key marker',function() return {hidden=pair()[1]} end},
    {'container marker',function() local p=pair();p.targetGroup='weak_then_vulnerable';return p end},
    {'unreachable nested',function() return {{op='damage',value=0},{op='conditional',['if']='target_vulnerable',['then']=pair()}} end},
    {'nested malformed then',function() return {{op='energy',value=1,['then']={targetGroup=false}}} end},
    {'cycle with nested marker',function() local p={{op='energy',value=1}};p[1]['then']=p;p.hidden={targetGroup=false};return p end,true},
    {'group with nonnumeric key',function() local p=pair();p.extra=false;return p end},
    {'group with non-table entry',function() local p=pair();p[3]=false;return p end},
    {'nested alias',function() local p=pair();p[3]={op='energy',value=1,['then']=p};return p end,true},
}
for _,field in ipairs({'target','times','then','if','extra'}) do
    bad[#bad+1]={'extra '..field,function() local p=pair();p[1][field]=false;return p end}
end
for _,value in ipairs({false,0,'','unknown',{}, {'weak_then_vulnerable'}}) do
    bad[#bad+1]={'marker '..tostring(value),function() local p=pair();p[1].targetGroup=value;p[2].targetGroup=value;return p end}
end
for _,value in ipairs({-1,0,0.5,0/0,math.huge,-math.huge,'3',2147483648}) do
    bad[#bad+1]={'amount '..tostring(value),function() return pair(value) end}
end
for _,case in ipairs(bad) do
    test('reject '..case[1]..' before direct effects'..(case[3] and '' or ' and play payment'),function()
        local p=case[2]();local ok,why=E.supported(p)
        eq(ok,false);eq(why,'invalid_target_group')
        local s=battle();s.catalog.cards.shockwave.effects=p
        local unchanged=snapshot(s)
        if case[3] then
            -- Cyclic tables cannot be JSON card data; existing cardDefinition
            -- copying rejects them before supported. Direct interpreter below
            -- must still reject them safely with the marker-specific error.
            -- Do not drive the unrelated card copier into a pathological deep
            -- recursion in CI; cyclic input is tested through supported/apply.
            unchanged()
        else
            local playable,reason=C.canPlay(s,s.hand[1].uid,1)
            eq(playable,false);eq(reason,'unsupported_effect:invalid_target_group')
            eq(C.play(s,s.hand[1].uid,1),false);unchanged()
        end
        -- Prefix mutating effects, while retaining sparse/non-numeric keys.
        local direct={{op='block',value=7},{op='energy',value=2},{op='draw',value=2}}
        for k,v in pairs(p) do if type(k)=='number' then direct[k+3]=v else direct[k]=v end end
        local called,err=pcall(C.applyEffects,s,direct,s.player,s.enemies[1])
        eq(called,false);assert(tostring(err):find('invalid_target_group',1,true),tostring(err));unchanged()
    end)
end
for _,amount in ipairs({1,3,5,2147483647}) do
    test('public player group accepts bounded amount '..amount..' without playedCard',function()
        local s=battle();s.events={};local p=pair(amount);assert(E.supported(p));local untouched=snapshot(p)
        eq(C.applyEffects(s,p,s.player),0);eq(statusOrder(s),grouped);untouched()
        eq(s.enemies[1].statuses.weak,amount);eq(s.enemies[2].statuses.vulnerable,amount)
    end)
end
for _,context in ipairs({'enemy','queued_player','queued_enemy'}) do
    test('context '..context..' rejects before own side effects',function()
        local s=battle();local p=pair();table.insert(p,1,{op='block',value=5});assert(E.supported(p))
        local unchanged=snapshot(s);local source=context=='queued_player' and s.player or s.enemies[1]
        local ok,err=pcall(E.apply,C,s,p,source,s.player,nil,context~='enemy')
        eq(ok,false);assert(tostring(err):find('invalid_target_group',1,true));unchanged()
    end)
end
test('unmarked same shape stays effect-first without global fusion',function()
    local s=battle();s.events={};local p=pair();for _,e in ipairs(p) do e.targetGroup=nil end
    C.applyEffects(s,p,s.player);eq(statusOrder(s),legacy)
end)
test('empty public effects and real Slimed remain valid',function()
    local s=battle();local unchanged=snapshot(s);eq(C.applyEffects(s,{},s.player),0);unchanged();eq(E.supported({}),false)
    s=C.new(data,{deck={'slimed'},seed=42});local instance=s.hand[1];assert(C.play(s,instance.uid));eq(s.energy,2);eq(s.exhaust[1],instance)
end)
test('unmarked late invalid op retains earlier direct mutation',function()
    local s=battle();local ok,err=pcall(C.applyEffects,s,{{op='block',value=7},{op='missing'}},s.player)
    eq(ok,false);assert(tostring(err):find('unsupported effect: missing',1,true));eq(s.player.block,7)
end)
test('unmarked late invalid amount retains earlier direct mutation',function()
    local s=battle();local ok,err=pcall(C.applyEffects,s,{{op='energy',value=7},{op='applyStatusAll',status='weak',value=-1}},s.player)
    eq(ok,false);assert(tostring(err):find('invalid status amount',1,true));eq(s.energy,10)
end)
test('unmarked sparse and cyclic irrelevant metadata remain old no-ops',function()
    local s=battle();local unchanged=snapshot(s);C.applyEffects(s,{[2]={op='energy',value=7}},s.player);unchanged()
    local p={{op='energy',value=0}};p[1]['then']=p;C.applyEffects(s,p,s.player);unchanged()
end)
for _,upgraded in ipairs({false,true}) do
    for _,status in ipairs({'weak','vulnerable'}) do
        test('real overflow after first Artifact rolls back all references '..status..tostring(upgraded),function()
            local s=battle(upgraded);C.addStatus(s.enemies[1],'artifact',1);C.addStatus(s.enemies[2],status,2147483647)
            local unchanged=snapshot(s);assert(C.canPlay(s,s.hand[1].uid))
            local ok,err=pcall(C.play,s,s.hand[1].uid);eq(ok,false);assert(tostring(err):find('status stack overflow',1,true));unchanged()
        end)
    end
end
for _,position in ipairs({'before','after'}) do
    test('group '..position..' surrounding mutations rolls back real play',function()
        local s=battle();local p=pair()
        local mutations={{op='block',value=7},{op='draw',value=1},{op='energy',value=2}}
        if position=='before' then for i=#mutations,1,-1 do table.insert(p,1,mutations[i]) end
        else for _,e in ipairs(mutations) do p[#p+1]=e end end
        p[#p+1]={op='gainStatus',status='missing',value=1};s.catalog.cards.shockwave.effects=p
        s.discard[1]={uid=99,cardId='strike',upgraded=false};s.enemies[1].statuses.artifact=1
        local unchanged=snapshot(s);assert(C.canPlay(s,s.hand[1].uid));local ok,err=pcall(C.play,s,s.hand[1].uid)
        eq(ok,false);assert(tostring(err):find('unknown status: missing',1,true));unchanged()
    end)
end
test('Artifact blocks capped status without prospective overflow',function()
    local s=battle();for _,a in ipairs(s.enemies) do a.statuses.artifact=2;a.statuses.weak=2147483647;a.statuses.vulnerable=2147483647 end
    assert(C.play(s,s.hand[1].uid));for _,a in ipairs(s.enemies) do eq(a.statuses.artifact,0);eq(a.statuses.weak,2147483647);eq(a.statuses.vulnerable,2147483647) end
end)
test('legal surrounding effects execute once at their original positions',function()
    local s=battle();s.events={};local p=pair();table.insert(p,1,{op='block',value=7});p[#p+1]={op='energy',value=2}
    C.applyEffects(s,p,s.player);eq(s.player.block,7);eq(s.energy,5);eq(s.events[1].kind,'block');eq(statusOrder(s),grouped)
end)
test('final damage clears both grouped statuses but retains Block',function()
    local s=battle();s.events={};local p=pair();table.insert(p,1,{op='damageAll',value=999});p[#p+1]={op='block',value=7}
    C.applyEffects(s,p,s.player);eq(statusOrder(s),'');eq(s.player.block,7);eq(C.outcome(s),'victory')
end)
test('source HP payment stops group after lethal payment',function()
    local s=battle();s.events={};local p=pair();table.insert(p,1,{op='loseHp',value=s.player.hp})
    C.applyEffects(s,p,s.player);eq(statusOrder(s),'');eq(s.player.hp,0)
end)
-- applyPower has no lethal hook today. Wrap only its completed call to inject
-- an interruption; all real Artifact/status/event/frame behavior stays intact.
local function interrupted(mode, owner)
    local s=battle();s.events={};local original=A.applyPower;local calls=0
    A.applyPower=function(state,victim,status,value,source,...)
        calls=calls+1;local result=original(state,victim,status,value,source,...)
        if calls==1 then
            local actor=owner=='source' and source or victim
            if mode=='dead' then actor.hp=0 else actor.escaped=true end
        end
        return result
    end
    local ok,err=pcall(C.applyEffects,s,pair(),s.player);A.applyPower=original;assert(ok,err)
    return s,calls
end
for _,mode in ipairs({'dead','escaped'}) do
    test('target '..mode..' between applications skips second and continues next enemy',function()
        local s,calls=interrupted(mode,'target');eq(calls,3)
        eq(statusOrder(s),'cultist_1:weak,cultist_2:weak,cultist_2:vulnerable');eq(s.enemies[1].statuses.vulnerable,nil)
    end)
    test('source '..mode..' between applications stops all remaining targets',function()
        local s,calls=interrupted(mode,'source');eq(calls,1);eq(statusOrder(s),'cultist_1:weak')
    end)
    test('initial source '..mode..' skips legal group',function()
        local s=battle();if mode=='dead' then s.player.hp=0 else s.player.escaped=true end
        local unchanged=snapshot(s);C.applyEffects(s,pair(),s.player);unchanged()
    end)
end
test('every status frame remains detached after later mutations',function()
    local s=battle();s.events={};C.applyEffects(s,pair(),s.player)
    s.enemies[1].statuses.weak=99;s.enemies[2].statuses.vulnerable=99
    eq(s.events[1].frame.enemies[1].statuses.weak,3);eq(s.events[1].frame.enemies[1].statuses.vulnerable,nil)
    eq(s.events[2].frame.enemies[1].statuses.vulnerable,3);eq(s.events[2].frame.enemies[2].statuses.weak,nil)
    eq(s.events[3].frame.enemies[2].statuses.weak,3);eq(s.events[3].frame.enemies[2].statuses.vulnerable,nil)
end)
for _,marked in ipairs({false,true}) do
    test('deep irrelevant metadata is stack-safe, marker='..tostring(marked),function()
        local leaf=marked and {targetGroup=false} or {}
        local payload=leaf
        for _=1,10000 do payload={child=payload} end
        local effects={{op='energy',value=1,metadata=payload}}
        local s=battle();local before=s.energy
        if marked then
            local ok,why=E.supported(effects);eq(ok,false);eq(why,'invalid_target_group')
            local applied,err=pcall(C.applyEffects,s,effects,s.player)
            eq(applied,false);assert(tostring(err):find('invalid_target_group',1,true));eq(s.energy,before)
        else
            assert(E.supported(effects));C.applyEffects(s,effects,s.player);eq(s.energy,before+1)
        end
    end)
end
print('SHOCKWAVE_GROUP '..(count-failed)..' passed; '..failed..' failed')
assert(failed==0,'Shockwave target-group regressions failed')
