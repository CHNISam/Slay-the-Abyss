-- Fixed 319009 Corruption instance costs. No Combat.cardDefinition recursion.
local Events=require("abyss_events")
local M={}
local MAX=2147483647
local allPiles={"hand","draw","discard","exhaust"}
local resetPiles={"hand","draw","discard"}
local types={skill=true,attack=true,power=true,status=true,curse=true}
local function integer(n,lo,hi)
    return type(n)=="number" and n==n and n%1==0 and n>=lo and n<=hi
end
local function plain(t,message) assert(type(t)=="table" and getmetatable(t)==nil,message) end
local function dense(t)
    plain(t,"invalid Corruption pile")
    local n=0
    for k in next,t do assert(integer(k,1,MAX),"invalid Corruption pile index");n=n+1 end
    for i=1,n do assert(rawget(t,i)~=nil,"sparse Corruption pile") end
    return n
end
local function actor(s)
    plain(s,"invalid Corruption state");plain(s.player,"missing Corruption player")
    plain(s.player.statuses,"missing Corruption powers")
    local marker=s.player.statuses.corruption
    assert(marker==nil or marker==0 or marker==1,"invalid Corruption marker")
    assert(s.corruptionPrepared==nil or s.corruptionPrepared==true,"invalid prepared Corruption")
    return marker==1
end
local function definition(s,instance,supplied)
    plain(instance,"invalid Corruption card instance")
    assert(integer(instance.uid,1,MAX) and type(instance.cardId)=="string","invalid Corruption card identity")
    assert(instance.upgraded==nil or type(instance.upgraded)=="boolean","invalid Corruption upgrade")
    local def=supplied
    if def==nil then
        plain(s.catalog,"missing Corruption catalog");plain(s.catalog.cards,"missing Corruption cards")
        def=assert(s.catalog.cards[instance.cardId],"unknown Corruption card")
        plain(def,"invalid Corruption card definition")
        if instance.upgraded and def.upgrade then
            plain(def.upgrade,"invalid Corruption upgrade definition")
            local merged={};for k,v in pairs(def) do merged[k]=v end
            for k,v in pairs(def.upgrade) do merged[k]=v end
            def=merged
        end
    end
    plain(def,"invalid Corruption card definition")
    assert(def.id==instance.cardId and types[def.type] and integer(def.cost,-2,MAX),"invalid Corruption effective definition")
    for _,key in ipairs({"combatCost","turnCost"}) do
        local value=instance[key]
        assert(value==nil or integer(value,-2,MAX),"invalid Corruption "..key)
        -- Existing supported cost modifiers never turn a negative sentinel into
        -- a positive playable cost. Refuse such an unsupported combination.
        assert(value==nil or (def.cost<0 and value==def.cost or def.cost>=0 and value>=0),"unsupported Corruption sentinel override")
    end
    return def
end
local function costs(instance,def)
    local combat=instance.combatCost
    if combat==nil then combat=def.cost end
    local turn=instance.turnCost
    if turn==nil then turn=combat end
    return combat,turn
end
local function scan(s,names)
    local result,seen,objects={},{},{}
    for _,name in ipairs(names) do
        local pile=s[name];dense(pile)
        for _,instance in ipairs(pile) do
            local def=definition(s,instance)
            assert(not seen[instance.uid] and not objects[instance],"duplicate Corruption card instance")
            seen[instance.uid],objects[instance]=true,true
            result[#result+1]={instance=instance,definition=def,pile=name}
        end
    end
    return result
end
local function reduction(instance,def)
    local base,turn=costs(instance,def)
    if def.type~="skill" then return end
    if turn>0 then
        local value=math.max(0,turn-9.0)
        return {instance=instance,combatCost=value,turnCost=value}
    elseif base>=0 then
        return {instance=instance,combatCost=math.max(0,base-9.0),turnCost=0}
    end
end
local function changes(entries,handHook)
    local out={}
    for _,entry in ipairs(entries) do
        local _,turn=costs(entry.instance,entry.definition)
        if not handHook or turn~=0 then
            local change=reduction(entry.instance,entry.definition)
            if change then out[#out+1]=change end
        end
    end
    return out
end
local function commit(list)
    for _,change in ipairs(list) do
        change.instance.combatCost,change.instance.turnCost=change.combatCost,change.turnCost
    end
end
function M.definition()
    return {id="corruption",name="腐化",kind="buff",stack="none",decay="none",
        description="技能不消耗能量，使用后消耗。已有技能的战斗费用降低。"}
end
local function statusTargets(s)
    plain(s.catalog,"missing Corruption catalog");plain(s.catalog.statuses,"missing Corruption status catalog")
    local out={s.catalog.statuses}
    if s.player.statusDefinitions and s.player.statusDefinitions~=s.catalog.statuses then
        plain(s.player.statusDefinitions,"invalid Corruption actor definitions");out[#out+1]=s.player.statusDefinitions
    end
    for _,defs in ipairs(out) do
        local def=defs.corruption
        if def then
            plain(def,"invalid Corruption status definition")
            assert(def.id=="corruption" and def.kind=="buff" and def.stack=="none" and def.decay=="none","incompatible Corruption status definition")
        end
    end
    return out
end
-- Called at ApplyPowerAction construction, before the queued marker is applied.
-- The boolean is transaction data. Each new prepare call still performs its
-- own source constructor scan; apply consumes the prepared marker once.
function M.prepare(s)
    if actor(s) then return false end
    local list=changes(scan(s,allPiles),false)
    statusTargets(s)
    commit(list);s.corruptionPrepared=true
    return true
end
function M.apply(s,value)
    assert(value==nil or value==1,"unsupported Corruption amount")
    if actor(s) then return false end -- Corruption.use does not rebuild an existing Power.
    local entries=scan(s,allPiles)
    local list=s.corruptionPrepared and {} or changes(entries,false)
    local targets=statusTargets(s)
    plain(s.events,"missing Corruption events")
    -- Validate the presentation graph before the first rule write. Unexpected
    -- host/event callback exceptions are covered by Combat's graph transaction.
    Events.frame(s)
    s.experimentalMechanics=true
    commit(list)
    for _,defs in ipairs(targets) do
        if not defs.corruption then defs.corruption=M.definition() end
        for key,v in pairs(M.definition()) do if defs.corruption[key]==nil then defs.corruption[key]=v end end
    end
    s.player.statuses.corruption=1;s.corruptionPrepared=nil
    Events.emit(s,"status",{source=s.player.id,target=s.player.id,status="corruption",amount=1})
    return true
end
-- AbstractPlayer.onCardDrawOrDiscard: scan only the current hand, and only
-- skills whose current turn cost is not already zero.
function M.onDrawOrDiscard(s)
    if not actor(s) then return false end
    local list=changes(scan(s,{"hand"}),true)
    commit(list);return true
end
-- Power.onCardDraw is before AbstractPlayer.onCardDrawOrDiscard. Thus a newly
-- drawn nonnegative skill gets only a turn override, not a combat reduction.
function M.onDraw(s,instance,supplied)
    local active=actor(s)
    local def=definition(s,instance,supplied)
    if not active or def.type~="skill" then return false end
    local _,turn=costs(instance,def)
    if turn<0 then return false end
    instance.turnCost=0;return true
end
-- Invoke AFTER the generated card was added to hand. The source VFX invokes
-- onCardDrawOrDiscard BEFORE its final setCostForTurn; this can persist the
-- generated card's combat reduction and refresh other hand skills as well.
function M.created(s,instance,supplied)
    if not actor(s) then definition(s,instance,supplied);return false end
    local entries=scan(s,{"hand"});local found=false
    local def=definition(s,instance,supplied)
    for _,entry in ipairs(entries) do
        if entry.instance==instance then entry.definition=def;found=true end
    end
    assert(found,"generated Corruption card must already be in hand")
    local list=changes(entries,true)
    local _,turn=costs(instance,def)
    commit(list)
    if def.type=="skill" and turn>=0 then instance.turnCost=0 end
    return true
end
-- AbstractRoom.endTurn resets draw/discard/hand before queued end-turn actions.
-- Retained cards are still in hand here. Exhaust is deliberately untouched.
function M.resetEndTurn(s)
    actor(s)
    local entries=scan(s,resetPiles)
    for _,entry in ipairs(entries) do entry.instance.turnCost=nil end
    return true
end
-- There is no source start-turn reset: a skill drawn by end-turn Dark Embrace
-- can keep its new zero turn cost into the next turn.
function M.beginTurn(s) actor(s);return true end
function M.remove(s)
    if not actor(s) then return false end
    plain(s.events,"missing Corruption events");Events.frame(s)
    s.player.statuses.corruption=nil
    Events.emit(s,"status_removed",{source=s.player.id,target=s.player.id,status="corruption",amount=-1})
    return true
end
-- Adapt the already copied/merged definition, after other supported instance
-- costs and before display/canPlay/payment. Never mutate the source catalog.
function M.adaptDefinition(s,instance,card)
    local def=definition(s or {},instance,card)
    if s and s.catalog and s.catalog.cards then
        assert(card~=s.catalog.cards[instance.cardId],"Corruption requires detached definition")
    end
    local cost=instance.turnCost
    if cost==nil then cost=instance.combatCost end
    if cost~=nil then def.cost=cost end
    return def
end
-- AbstractPlayer.useCard skips normal positive payment for corrupted skills.
-- X actions still own their own energy consumption; sentinel costs stay intact.
function M.freePayment(s,card)
    return actor(s) and type(card)=="table" and card.type=="skill" and integer(card.cost,0,MAX)
end
return M
