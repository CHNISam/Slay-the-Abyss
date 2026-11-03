package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Combat=require('abyss_combat')
local data=require('abyss_data')
local Native=require('abyss_combat_native_play')
local Queued=require('abyss_combat_queued_play')
local Queue=require('abyss_action_queue')
local copy=require('abyss_copy').copy

-- Compare the entire graph, including aliases between pending context, queues,
-- card instances, catalog, RNG and retained reactions. Functions are code values.
local function sameGraph(actual,expected)
    local forward,reverse={},{}
    local function visit(a,b,path)
        assert(type(a)==type(b),path..': type')
        if type(a)~='table'then
            if type(a)~='function'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b))end
            return
        end
        if forward[a]then assert(forward[a]==b,path..': changed alias');return end
        assert(not reverse[b],path..': merged alias')
        forward[a]=b;reverse[b]=a
        for k,v in pairs(a)do visit(v,b[k],path..'.'..tostring(k))end
        for k in pairs(b)do assert(a[k]~=nil,path..': missing '..tostring(k))end
    end
    visit(actual,expected,'state')
end

local function hooksFor(state,case)
    state.protocolTrace={}
    local function phase(name,detail)
        state.protocolTrace[#state.protocolTrace+1]={name=name,detail=detail,energy=state.energy,
            hand=#state.hand,inUse=state.cardInUse,pending=state.pendingPlay}
    end
    return {
        event=function(_,kind,detail)
            phase(kind,detail)
            if case.reentrant then
                local replacement=copy(state.enemies[1])
                replacement.id='replacement';replacement.statuses.vulnerable=3
                state.enemies[1]=replacement
            end
        end,
        paidCost=function(_,card)return card.cost end,
        queueUseCopies=function(_,instance,card,target,energy,purge,free)
            phase('copies',{instance=instance,card=card,target=target,energy=energy,purge=purge,free=free})
        end,
        handlers={},finish=function()phase('finish')end,
    }
end

local cases={
    {name='native multi-hit damage and block',native=true,effects={{op='damage',value=6,times=2},{op='block',value=3}}},
    {name='native target group retains companion',native=true,effects={{op='damage',value=6,targetGroup=1},{op='applyStatus',status='weak',value=1,targetGroup=1}}},
    {name='native zero X removes item',native=true,energy=0,effects={{op='damage',value=6,times='X'}}},
    {name='native X bonus automatic TOP purge',native=true,automatic=true,energy=2,effects={{op='damageAll',value=3,times='X'}}},
    {name='native random target and poison capture',native=true,effects={{op='playTop',value=1},{op='applyStatus',status='poison',value=2}}},
    {name='native dont-trigger and one-shot free',native=true,dontTrigger=true,free=true,effects={{op='damageEqualToBlock',value=0}}},
    {name='native original paid energy',native=true,automatic=true,effects={{op='originalV4',kind='test'}}},
    {name='queued ordinary batch',effects={{op='damage',value=6},{op='block',value=3}},batch=true},
    {name='queued advanced captures split hits and block',effects={{op='damage',value=6,times=2},{op='block',value=3},{op='nextBlock',value=2}}},
    {name='queued poison random and conditional',effects={{op='playTop',value=1},{op='applyStatus',status='poison',value=2},{op='conditional',['then']={{op='damage',value=4}}}}},
    {name='queued matrix and automatic purge',automatic=true,effects={{op='whirlwind',value=2},{op='reaperDamage',value=3}}},
    {name='queued dont-trigger finishes without pause',dontTrigger=true,done=true,effects={{op='damageAll',value=3}}},
    {name='queued target retained across reentrant use hook',reentrant=true,effects={{op='damage',value=6},{op='applyStatus',status='poison',value=2}}},
    {name='queued nonstring preparation failure',failure=true,effects={{op='playTop',value=1},{op='damage',value=3}}},
}

local errorObject={test='captured failure identity'}
local function prepare(case)
    local state=Combat.new(data,{deck={'strike','pain','defend'},enemies={'jaw_worm','cultist'},seed=42,experimentalMechanics=true})
    state.energy=case.energy or 3
    state.player.block=5
    state.catalog.statuses.rage=require('abyss_card_triggers').definition('rage')
    state.catalog.statuses.envenom=require('abyss_card_triggers').definition('envenom')
    state.catalog.statuses.choked={id='choked',kind='debuff',stack='intensity',decay='none'}
    if not case.batch then require('abyss_card_triggers').apply(state,'rage',2)end
    if not case.batch then require('abyss_card_triggers').apply(state,'envenom',1)end
    Combat.addStatus(state.enemies[1],'sharp_hide',3)
    require('abyss_power_schedule').recordApplied(state,state.enemies[1],'sharp_hide',nil)
    Combat.addStatus(state.enemies[1],'choked',2)
    require('abyss_power_schedule').recordApplied(state,state.enemies[1],'choked',nil)
    local instance
    for _,held in ipairs(state.hand)do if held.cardId=='strike'then instance=held end end
    assert(instance,'fixture strike')
    instance.freeToPlayOnce=case.free
    local card=copy(Combat.cardDefinition(state,instance))
    card.effects=copy(case.effects);card.experimental=not case.batch
    card.dontTriggerOnUseCard=case.dontTrigger
    return state,instance,card
end

local function run(case,baseline)
    local state,instance,card=prepare(case)
    local hooks=hooksFor(state,case)
    local api=Combat
    if case.failure then
        api=setmetatable({attackAmount=function()error(errorObject,0)end},{__index=Combat})
    end
    local owner=baseline and dofile('tests/lua/support/m9_combat_protocol_baseline.lua')(api,hooks)
    local oldRun=Queue.run
    Queue.run=function(s,handlers)
        assert(handlers==hooks.handlers,'same handler owner')
        s.protocolTrace[#s.protocolTrace+1]={name='run',queue=s.actionQueue,card=s.cardInUse}
        return case.done and 'done'or 'pause'
    end
    local ok,why=pcall(function()
        if case.native then
            local fn=owner and owner.queue or function(...)return Native.queue(api,hooks,...)end
            fn(state,instance.uid,1,instance,card,case.automatic,case.automatic,case.automatic,case.automatic,case.energy)
        else
            local fn=owner and owner.begin or function(...)return Queued.begin(api,hooks,...)end
            local position
            for i,c in ipairs(state.hand)do if c==instance then position=i end end
            fn(state,instance.uid,1,instance,case.automatic and nil or position,card,
                case.automatic and {purge=true,exhaustCards=true,energyOnUse=2}or nil)
        end
    end)
    Queue.run=oldRun
    assert(ok==not case.failure,case.name..': success convention '..tostring(why))
    if case.failure then assert(why==errorObject,case.name..': error identity')end
    return state
end

for _,case in ipairs(cases)do
    local old=run(case,true)
    local current=run(case,false)
    sameGraph(current,old)
    print('PASS '..case.name..' complete preparation graph and trace')
end
print('M9_COMBAT_PROTOCOLS '..#cases..' old/new complete graph trajectories passed')
