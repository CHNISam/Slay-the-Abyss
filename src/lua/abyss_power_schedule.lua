-- Source-ordered Power membership only. Hosts own effects, hooks and removal.
local M={}
local MAX=2147483647
local function plain(value,why)
    assert(type(value)=='table' and getmetatable(value)==nil,why)
end
local function integer(value,lo,hi)
    return type(value)=='number' and value==value and value%1==0 and value>=lo and value<=hi
end
local function owner(value)
    plain(value,'missing Power schedule owner')
    local actor=value.statuses and value or value.player
    plain(actor,'missing Power schedule actor')
    plain(actor.statuses,'missing Power membership')
    return actor,value==actor and nil or value
end
local function priority(state,actor,id)
    assert(type(id)=='string' and #id>0,'invalid scheduled Power id')
    local definitions=actor.statusDefinitions or state and state.catalog and state.catalog.statuses
    plain(definitions,'missing scheduled Power definitions')
    local definition=assert(definitions[id],'unknown scheduled Power: '..id)
    assert(definition.id==id,'incompatible scheduled Power definition')
    local value=definition.priority
    if value==nil then value=5 end
    assert(integer(value,-2147483648,MAX),'invalid scheduled Power priority')
    return value
end
local function membership(actor,filter)
    local count=0
    for id,value in pairs(actor.statuses) do
        if not filter or filter[id] then
            assert(type(id)=='string' and #id>0 and integer(value,-MAX,MAX),'invalid Power membership')
            count=count+1
        end
    end
    return count
end
local function read(actor)
    local entries=actor.powerScheduleOrder
    local serial=actor.powerScheduleSerial
    if entries==nil then
        assert(serial==nil or serial==0,'missing Power schedule order')
        return {},{},0,false
    end
    plain(entries,'invalid Power schedule order')
    assert(integer(serial,0,MAX),'invalid Power schedule serial')
    local count=0
    for key in pairs(entries) do
        assert(integer(key,1,MAX),'invalid Power schedule index');count=count+1
    end
    local copy,seen,previous={},{},0
    for i=1,count do
        local entry=rawget(entries,i)
        plain(entry,'sparse Power schedule order')
        assert(type(entry.id)=='string' and #entry.id>0 and not seen[entry.id]
            and integer(entry.priority,-2147483648,MAX)
            and integer(entry.order,1,serial) and entry.order>previous,'invalid Power acquisition record')
        copy[i]={id=entry.id,priority=entry.priority,order=entry.order}
        seen[entry.id]=copy[i];previous=entry.order
    end
    return copy,seen,serial,true
end
local function complete(state,actor,entries,seen,filter)
    membership(actor,filter)
    for _,entry in ipairs(entries) do
        assert(rawget(actor.statuses,entry.id)~=nil,'Power removed without schedule removal')
        assert(priority(state,actor,entry.id)==entry.priority,'scheduled Power priority changed')
    end
    for id in pairs(actor.statuses) do
        assert(filter and not filter[id] or seen[id],'missing Power acquisition history: '..id)
    end
end

-- After successful application; before is rawget(actor.statuses,id) BEFORE
-- applying, not "old or 0". A rejected Artifact application must not call this.
function M.recordApplied(state,actor,id,before)
    plain(state,'missing Power schedule state')
    plain(actor,'missing Power schedule actor');plain(actor.statuses,'missing Power membership')
    assert(before==nil or integer(before,-MAX,MAX),'invalid previous Power membership')
    assert(rawget(actor.statuses,id)~=nil,'record requires an applied Power')
    local p=priority(state,actor,id)
    local entries,seen,serial=read(actor)
    assert(integer(rawget(actor.statuses,id),-MAX,MAX),'invalid applied Power membership')
    -- Other raw fixture statuses may predate host integration. Do not invent
    -- their positions here; a complete or phase-filtered list checks coverage.
    for _,entry in ipairs(entries) do
        assert(rawget(actor.statuses,entry.id)~=nil,'Power removed without schedule removal')
        assert(priority(state,actor,entry.id)==entry.priority,'scheduled Power priority changed')
    end
    if seen[id] then
        assert(before~=nil,'Power reapplied without schedule removal')
        return false -- Stack retains the original object and acquisition slot.
    end
    assert(before==nil,'stacked Power is missing acquisition history')
    assert(serial<MAX,'Power acquisition serial overflow')
    entries[#entries+1]={id=id,priority=p,order=serial+1}
    actor.powerScheduleOrder=entries;actor.powerScheduleSerial=serial+1
    return true
end

-- Call when the source Remove/Reduce actually removes membership, before or
-- after clearing statuses[id]. This does not run onRemove or mutate statuses.
function M.remove(state,actor,id)
    plain(state,'missing Power schedule state')
    plain(actor,'missing Power schedule actor');plain(actor.statuses,'missing Power membership')
    assert(type(id)=='string' and #id>0,'invalid removed Power id')
    local entries,seen=read(actor)
    if not seen[id] then
        -- Removing an unrecorded old fixture Power needs no guessed position.
        return false
    end
    local keep={}
    for _,entry in ipairs(entries) do if entry.id~=id then keep[#keep+1]=entry end end
    actor.powerScheduleOrder=keep
    return true
end

-- Ascending source priority, stable acquisition order for ties. Returned
-- entries are snapshots; phase hook selection remains the host's business.
function M.list(actorOrState,filter)
    local actor,state=owner(actorOrState)
    local entries,seen,_,recorded=read(actor)
    if filter then
        plain(filter,'invalid Power hook filter')
        for id,enabled in pairs(filter) do
            assert(type(id)=='string' and #id>0 and type(enabled)=='boolean','invalid Power hook filter entry')
        end
        local selected,selectedIds={},{}
        for _,entry in ipairs(entries) do
            if filter[entry.id] then selected[#selected+1]=entry;selectedIds[entry.id]=entry end
        end
        entries,seen=selected,selectedIds
    end
    local count=membership(actor,filter)
    if (not recorded or filter and #entries==0) and count<=1 then
        for id,value in pairs(actor.statuses) do
            if not filter or filter[id] then
                return {{id=id,priority=priority(state,actor,id),order=1,amount=value,fallback=true}}
            end
        end
        return {}
    end
    complete(state,actor,entries,seen,filter)
    for _,entry in ipairs(entries) do entry.amount=rawget(actor.statuses,entry.id) end
    table.sort(entries,function(a,b)
        if a.priority~=b.priority then return a.priority<b.priority end
        return a.order<b.order
    end)
    return entries
end
return M
