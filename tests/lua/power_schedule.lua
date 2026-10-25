-- Scheduler component + real Actor application contract. The fixture host
-- records successful applications explicitly when Core has not wired it yet.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local S=require('abyss_power_schedule')
local A=require('abyss_actor')
local C=require('abyss_combat')
local n=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();n=n+1;print('ok power_schedule '..n..' - '..name)end
local function state()
    local s=C.new(require('abyss_data'),{seed=42,deck={},enemies={'cultist'}})
    for _,spec in ipairs({{'early',-5},{'late',20},{'alpha',5},{'beta',5},{'negative',5}}) do
        s.catalog.statuses[spec[1]]={id=spec[1],name=spec[1],description='scheduler fixture',
            kind=spec[1]=='negative' and 'debuff' or 'buff',stack='intensity',decay='none',priority=spec[2]}
    end
    return s
end
local function has(actor,id)
    for _,entry in ipairs(actor.powerScheduleOrder or {})do if entry.id==id then return entry end end
end
local function apply(s,id,value,actor)
    actor=actor or s.player
    local before=rawget(actor.statuses,id)
    local old=has(actor,id)
    local ok=A.applyPower(s,actor,id,value,s.player)
    -- A fully integrated host may already have recorded this new application.
    -- Otherwise this explicit component host performs the prescribed callback.
    if ok and not (before==nil and not old and has(actor,id)) then S.recordApplied(s,actor,id,before) end
    return ok
end
local function ids(entries)
    local out={};for _,entry in ipairs(entries)do out[#out+1]=entry.id end;return table.concat(out,',')
end
local function rejects(fn)eq(pcall(fn),false)end
local function unchanged(actor,fn)
    local order,serial=actor.powerScheduleOrder,actor.powerScheduleSerial
    rejects(fn);eq(actor.powerScheduleOrder,order);eq(actor.powerScheduleSerial,serial)
end

test('real Actor applications use priority then stable acquisition order',function()
    local s=state();apply(s,'late',1);apply(s,'beta',1);apply(s,'early',1);apply(s,'alpha',1)
    eq(ids(S.list(s)),'early,beta,alpha,late')
    eq(ids(s.player.powerScheduleOrder),'late,beta,early,alpha')
end)
test('missing definition priority defaults to source five',function()
    local s=state();s.catalog.statuses.alpha.priority=nil;apply(s,'alpha',1);apply(s,'beta',1)
    eq(S.list(s)[1].priority,5);eq(ids(S.list(s)),'alpha,beta')
end)
test('real stacking changes amount without changing order identity or serial',function()
    local s=state();apply(s,'beta',1);apply(s,'alpha',1)
    local order,serial=s.player.powerScheduleOrder,s.player.powerScheduleSerial
    apply(s,'beta',2);eq(s.player.powerScheduleOrder,order);eq(s.player.powerScheduleSerial,serial)
    eq(ids(S.list(s)),'beta,alpha');eq(S.list(s)[1].amount,3)
end)
test('zero and signed negative Strength remain present',function()
    local s=state();apply(s,'strength',0);apply(s,'alpha',1);apply(s,'strength',-2)
    eq(ids(S.list(s)),'strength,alpha');eq(S.list(s)[1].amount,-2)
    apply(s,'strength',2);eq(S.list(s)[1].amount,0)
end)
test('buff debuff and priority twenty all retain membership',function()
    local s=state();apply(s,'negative',1);apply(s,'late',1);apply(s,'alpha',1)
    eq(ids(S.list(s)),'negative,alpha,late')
end)
test('remove after real membership deletion and reapply acquires a later slot',function()
    local s=state();apply(s,'alpha',1);apply(s,'beta',1)
    s.player.statuses.alpha=nil;assert(S.remove(s,s.player,'alpha'));apply(s,'alpha',1)
    eq(ids(S.list(s)),'beta,alpha');eq(has(s.player,'alpha').order,3)
end)
test('remove before membership deletion leaves the status untouched',function()
    local s=state();apply(s,'alpha',2);assert(S.remove(s,s.player,'alpha'));eq(s.player.statuses.alpha,2)
    rejects(function()S.list(s)end)
    s.player.statuses.alpha=nil;eq(#S.list(s),0);eq(s.player.powerScheduleSerial,1)
end)
test('reapply without removal rejects instead of silently keeping old order',function()
    local s=state();apply(s,'alpha',1)
    unchanged(s.player,function()S.recordApplied(s,s.player,'alpha',nil)end)
end)
test('an existing stack without history cannot be recorded as a new acquisition',function()
    local s=state();s.player.statuses.alpha=2
    unchanged(s.player,function()S.recordApplied(s,s.player,'alpha',1)end)
end)
test('Artifact rejection creates no new Power schedule entry',function()
    local s=state();apply(s,'artifact',1);local serial=s.player.powerScheduleSerial
    eq(apply(s,'weak',1),false);eq(s.player.statuses.weak,nil);eq(has(s.player,'weak'),nil)
    eq(s.player.powerScheduleSerial,serial)
end)
test('list snapshots do not expose stored order or status amounts',function()
    local s=state();apply(s,'alpha',1);local list=S.list(s)
    list[1].id='invented';list[1].amount=99;list[2]={id='extra'}
    eq(ids(S.list(s)),'alpha');eq(s.player.statuses.alpha,1)
end)
test('zero and negative one-Power old fixtures use a read-only fallback',function()
    for _,value in ipairs({0,-3})do
        local s=state();s.player.statuses.strength=value
        local list=S.list(s);eq(list[1].id,'strength');eq(list[1].amount,value);eq(list[1].fallback,true)
        eq(s.player.powerScheduleOrder,nil);eq(s.player.powerScheduleSerial,nil)
    end
end)
test('multiple unrecorded Powers reject rather than guessing alphabetical order',function()
    local s=state();s.player.statuses.alpha=1;s.player.statuses.beta=1
    unchanged(s.player,function()S.list(s)end)
end)
test('phase filter ignores unrelated raw fixture Powers before singleton fallback',function()
    local s=state();s.player.statuses.strength=2;s.player.statuses.weak=1;s.player.statuses.alpha=1
    local list=S.list(s,{alpha=true,beta=true});eq(ids(list),'alpha');eq(list[1].fallback,true)
    unchanged(s.player,function()S.list(s)end)
end)
test('phase filter refuses two missing relevant records even with unrelated Powers',function()
    local s=state();s.player.statuses.strength=2;s.player.statuses.alpha=1;s.player.statuses.beta=1
    unchanged(s.player,function()S.list(s,{alpha=true,beta=true})end)
end)
test('new real application may coexist with old unrelated unrecorded fixture statuses',function()
    local s=state();s.player.statuses.strength=2;s.player.statuses.weak=1
    apply(s,'beta',1);apply(s,'alpha',1)
    eq(ids(S.list(s,{alpha=true,beta=true})),'beta,alpha')
    rejects(function()S.list(s)end)
end)
test('filter does not validate removed non-hook records as stale',function()
    local s=state();apply(s,'alpha',1);apply(s,'beta',1);s.player.statuses.beta=nil
    eq(ids(S.list(s,{alpha=true})),'alpha');rejects(function()S.list(s)end)
end)
test('filtered order retains actual priority and acquisition order',function()
    local s=state();apply(s,'late',1);apply(s,'beta',1);apply(s,'early',1);apply(s,'alpha',1)
    eq(ids(S.list(s,{alpha=true,beta=true,late=true})),'beta,alpha,late')
end)
test('actor and enemy acquisition schedules remain independent',function()
    local s=state();apply(s,'alpha',1);apply(s,'beta',1,s.enemies[1]);apply(s,'alpha',1,s.enemies[1])
    eq(ids(S.list(s.player)),'alpha');eq(ids(S.list(s.enemies[1])),'beta,alpha')
    eq(s.player.powerScheduleSerial,1);eq(s.enemies[1].powerScheduleSerial,2)
end)
test('priority changes and removed tracked Powers fail complete listing',function()
    for _,mode in ipairs({'priority','removed'})do
        local s=state();apply(s,'alpha',1)
        if mode=='priority' then s.catalog.statuses.alpha.priority=20 else s.player.statuses.alpha=nil end
        unchanged(s.player,function()S.list(s)end)
    end
end)
test('serial overflow rejects before replacing original acquisition storage',function()
    local s=state();apply(s,'alpha',1);s.player.powerScheduleSerial=2147483647;s.player.statuses.beta=1
    unchanged(s.player,function()S.recordApplied(s,s.player,'beta',nil)end)
end)
test('sparse duplicate and invalid records reject without repair',function()
    for _,mode in ipairs({'sparse','duplicate','serial','priority'})do
        local s=state();apply(s,'alpha',1)
        if mode=='sparse' then s.player.powerScheduleOrder[3]={id='beta',order=2,priority=5}
        elseif mode=='duplicate' then s.player.powerScheduleOrder[2]={id='alpha',order=2,priority=5};s.player.powerScheduleSerial=2
        elseif mode=='serial' then s.player.powerScheduleSerial=-1
        else s.player.powerScheduleOrder[1].priority=0/0 end
        unchanged(s.player,function()S.list(s)end)
    end
end)
test('unknown definitions malformed filters and absent application reject',function()
    local s=state();s.player.statuses.unknown=1
    rejects(function()S.list(s)end)
    rejects(function()S.list(s,{unknown='yes'})end)
    unchanged(s.player,function()S.recordApplied(s,s.player,'alpha',nil)end)
end)
test('removing absent fixture membership does not synthesize a schedule',function()
    local s=state();eq(S.remove(s,s.player,'alpha'),false);eq(s.player.powerScheduleOrder,nil)
end)
print('POWER_SCHEDULE_PASS '..n)
