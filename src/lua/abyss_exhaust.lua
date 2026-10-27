-- Source-ordered exhaust hooks. Combat owns transactions, relics and disposal.
-- All persisted plans contain action data only; callbacks stay on the call stack.
local Events=require('abyss_events');local Actors=require('abyss_actor')
local M={}
local MAX=2147483647
local hooks={feel_no_pain=true,dark_embrace=true}
local function integer(n,lo,hi)
    return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi
end
local function dense(t)
    assert(type(t)=='table' and getmetatable(t)==nil,'invalid exhaust list')
    local n=0
    for k in next,t do assert(integer(k,1,MAX),'invalid exhaust list index');n=n+1 end
    for i=1,n do assert(rawget(t,i)~=nil,'sparse exhaust list') end
    return n
end
local function statuses(s)
    assert(type(s)=='table' and type(s.player)=='table' and type(s.player.statuses)=='table','invalid exhaust actor')
    return s.player.statuses
end
local function amount(value)
    if value==nil then return 0 end
    assert(integer(value,0,MAX),'invalid exhaust power amount');return value
end
local function alive(s)
    dense(s.enemies)
    for _,enemy in ipairs(s.enemies) do
        assert(type(enemy)=='table' and type(enemy.hp)=='number','invalid exhaust enemy')
        if Actors.isPresent(enemy) then return true end
    end
    return false
end
local function effect(op,value,source,fixed)
    local e={op=op,value=value}
    if fixed then e.fixed=true end
    return {kind='effect',effect=e,exhaustSource=source}
end
function M.rememberPower(s,id)
    assert(hooks[id],'unknown exhaust power')
    statuses(s)
    local order=s.exhaustPowerOrder or {}
    dense(order)
    local seen={}
    for _,prior in ipairs(order) do
        assert(hooks[prior] and not seen[prior],'invalid exhaust power order');seen[prior]=true
    end
    if not seen[id] then order[#order+1]=id end
    s.exhaustPowerOrder=order
end
function M.shouldExhaust(s,definition,options)
    local powers=statuses(s)
    assert(type(definition)=='table','missing exhaust card definition')
    options=options or {}
    if options.purge or definition.type=='power' then return false end
    return definition.exhaust==true or (definition.type=='skill' and (powers.corruption or 0)~=0)
end
function M.plan(s,instance,options)
    local powers=statuses(s)
    assert(type(s.player.hp)=='number' and s.player.hp>0,'cannot exhaust for dead player')
    assert(type(instance)=='table' and integer(instance.uid,1,MAX),'invalid exhausted card')
    local def=assert(s.catalog and s.catalog.cards and s.catalog.cards[instance.cardId],'unknown exhausted card')
    options=options or {}
    -- Caller supplies every owned relic with an onExhaust hook. Unknown hooks
    -- are deliberately refused until their RNG/selection handlers are wired.
    local relicHooks=options.onExhaustRelics or {}
    assert(dense(relicHooks)==0,'unsupported exhaust relic hook')
    assert(instance.cardId~='necronomicurse' and not def.onExhaust and not def.exhaustEffects
        and not def.exhaustTrigger,'unsupported card exhaust hook')
    local order=s.exhaustPowerOrder or {}
    dense(order)
    local seen={}
    for _,id in ipairs(order) do
        assert(hooks[id] and not seen[id],'invalid exhaust power order');seen[id]=true
    end
    local fnp,de=amount(powers.feel_no_pain),amount(powers.dark_embrace)
    assert((fnp==0 or seen.feel_no_pain) and (de==0 or seen.dark_embrace),'missing exhaust power order')
    local plan={top={},bottom={}}
    local living=alive(s)
    for _,id in ipairs(order) do
        if id=='feel_no_pain' and fnp>0 then
            plan.bottom[#plan.bottom+1]=effect('block',fnp,id,true)
        elseif id=='dark_embrace' and de>0 and living then
            plan.bottom[#plan.bottom+1]=effect('draw',de,id)
        end
    end
    if instance.cardId=='sentinel' then
        plan.top[1]=effect('energy',instance.upgraded==true and 3 or 2,'sentinel')
    end
    return plan
end
function M.move(s,instance,origin,queue,options)
    assert(origin=='hand' or origin=='using','unsupported exhaust origin')
    assert(type(queue)=='table' and type(queue.pushTop)=='function' and type(queue.pushBottom)=='function'
        and queue.active(s),'exhaust requires an active queue')
    local plan=M.plan(s,instance,options)
    local seen,position={},nil
    for _,name in ipairs({'hand','draw','discard','exhaust'}) do
        dense(s[name])
        for i,card in ipairs(s[name]) do
            assert(type(card)=='table' and integer(card.uid,1,MAX) and not seen[card.uid]
                and s.catalog.cards[card.cardId],'invalid exhaust piles')
            seen[card.uid]=true
            if card.uid==instance.uid then
                assert(origin=='hand' and name=='hand' and card==instance,'wrong exhaust origin');position=i
            end
        end
    end
    if origin=='using' then
        assert(not seen[instance.uid] and s.cardInUse==instance,'wrong card in use')
    else
        assert(position and (not s.cardInUse or s.cardInUse.uid~=instance.uid),'missing exhaust hand card')
        if s.cardInUse then
            assert(type(s.cardInUse)=='table' and integer(s.cardInUse.uid,1,MAX)
                and not seen[s.cardInUse.uid] and s.catalog.cards[s.cardInUse.cardId],'invalid card in use')
        end
    end
    assert(type(s.events)=='table','missing exhaust events')
    -- Hook actions are enqueued before movement, but cannot execute until
    -- the current handler returns. TOP lists describe source enqueue order.
    for _,action in ipairs(plan.top) do queue.pushTop(s,action) end
    for _,action in ipairs(plan.bottom) do queue.pushBottom(s,action) end
    if origin=='hand' then table.remove(s.hand,position) else s.cardInUse=nil end
    s.exhaust[#s.exhaust+1]=instance
    if (s.player.statuses.corruption or 0)~=0 then require("abyss_corruption").onDrawOrDiscard(s) end
    Events.emit(s,'exhaust',{uid=instance.uid,cardId=instance.cardId,origin=origin})
    return true
end
return M
