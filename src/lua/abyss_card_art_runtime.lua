-- Candidate engineering bounds, not official platform capacity/performance claims.
-- Every native callback may re-enter lifecycle APIs. Working records retain
-- ownership until returned handles are registered and deferred cleanup finishes.
local M={}
local MAX_POOLS,MAX_CREATES,MAX_SLOTS=10,64,2657
local api,records,order=nil,{},{}
local createdLastUpdate,generation,operationDepth=0,0,0
local updating,clearing=false,false
local CANCELLED={}
-- A face can change type while a cancelled allocation is still unwinding.
-- Cleanup owns its shapes, but only the latest intent owns shared visibility.
local intents=setmetatable({},{__mode='k'})
local function alive(control)return control and control.alive~=false end
local function current(record)
    return not record.cancelled and not record.removed and record.generation==generation
        and records[record.box]==record and alive(record.box) and alive(record.pool) and alive(record.fallback)
end
local function check(record)if not current(record)then error(CANCELLED,0)end end
local function livePools()
    local count=0
    for _,record in ipairs(order)do if not record.removed and record.allocated then count=count+1 end end
    return count
end
local function failure(record,reason)
    record.failed,record.reason=true,tostring(reason)
    if not record.logged then
        print('ABYSS_NATIVE_ART rejected card_id='..tostring(record.metadata.cardId)
            ..' lua_sha256='..tostring(record.metadata.luaSha256)..' reason='..record.reason)
        record.logged=true
    end
end
local function cancel(record)
    record.cancelled,record.ready,record.cleanupRequested=true,false,true
    if intents[record.box]==record.intent then record.intent.ready=false end
    if records[record.box]==record then records[record.box]=nil end
end
local function claim(box,pool,fallback)
    local intent={box=box,pool=pool,fallback=fallback,ready=false}
    intents[box]=intent;return intent
end
local function presented(intent)
    if not intent.ready then return false end
    for _,record in ipairs(order)do
        if record.box==intent.box and record.cancelled and (record.working or record.allocated)then return false end
    end
    return true
end
local function reconcile(box,pool,fallback)
    local controls,failed={},{}
    if pool then controls[pool]=true end;if fallback then controls[fallback]=true end
    operationDepth=operationDepth+1
    local reason
    repeat
        local intent=intents[box]
        if not intent then break end
        local ready=presented(intent)
        if intent.pool then controls[intent.pool]=true end
        if intent.fallback then controls[intent.fallback]=true end
        for control in pairs(controls)do
            if alive(control) and not failed[control]then
                local visible=control==intent.pool and ready or control==intent.fallback and not ready
                local ok,result=pcall(control.SetVisible,control,visible)
                if not ok or result==false then
                    reason=result or 'native visibility rejected';failed[control]=true;intent.ready=false
                end
            end
            if intents[box]~=intent or presented(intent)~=ready then break end
        end
        -- Only a new owner/value can cause another pass, never a failed setter.
        if intents[box]==intent and presented(intent)==ready then break end
    until false
    operationDepth=operationDepth-1
    return not reason,reason
end
function M.owns(intent)return intent and intents[intent.box]==intent end
function M.publish(intent,ready)
    if not M.owns(intent) then return false end
    intent.ready=ready
    if operationDepth>0 then return false end
    local ok,reason=reconcile(intent.box)
    return ok and intents[intent.box]==intent and presented(intent)==ready,reason
end
function M.guardPublication(intent,control)
    local function verify()assert(M.owns(intent),'native static publication superseded')end
    return setmetatable({}, {__index=function(_,key)
        verify();local value=control[key];verify()
        if type(value)=='function'then return function(_, ...)
            verify();local result=value(control,...);verify()
            assert(result~=false,'native '..key..' rejected');return result
        end end
        return value
    end,__newindex=function(_,key,value)verify();control[key]=value;verify()end})
end
local function cleanup(record)
    if record.working or record.cleaning or not record.cleanupRequested then return end
    record.cleaning=true;record.cleanupRequested=false;operationDepth=operationDepth+1
    local reason
    local function hide(control,value)
        if not alive(control)then return end
        local ok,result=pcall(control.SetVisible,control,value)
        if not ok or result==false then reason=result or 'native visibility rejected' end
    end
    -- Failed visibility must never abort destruction of already-owned controls.
    hide(record.pool,false)
    local retained={}
    for _,group in ipairs(record.groups)do
        if alive(group.control)then
            local ok,result=pcall(record.destroy,group.control)
            if not ok or result==false then retained[#retained+1]=group;reason='native pool destruction rejected' end
        end
    end
    record.groups,record.controls=retained,{}
    record.allocated,record.ready=#retained>0,false
    local ok,why=reconcile(record.box,record.pool,record.fallback)
    if not ok then reason=why end
    record.cleaning=false;operationDepth=operationDepth-1
    -- Nested release/clear requests are satisfied by this same cleanup attempt,
    -- not retried recursively or automatically after a destruction failure.
    record.cleanupRequested=false
    if reason then failure(record,reason)end
    if record.cancelled and not record.allocated then record.removed=true end
end
-- Do not replay damaged static geometry in cleanup or allow pending native
-- work to republish its shared pool. Only a fresh binding may try again.
function M.invalidatePublication(box,pool)
    local intent=intents[box]
    if not intent or intent.pool~=pool then return end
    intent.ready=false
    local record=records[box]
    if record and record.pool==pool then cancel(record);cleanup(record)
    else M.publish(intent,false)end
end
local function work(record,fn)
    if record.working or record.cleaning then return false end
    record.working=true;operationDepth=operationDepth+1
    local ok,reason=pcall(fn)
    record.working=false;operationDepth=operationDepth-1
    if not ok then
        if reason==CANCELLED then cancel(record)
        else failure(record,reason);record.ready=false;record.intent.ready=false;record.cleanupRequested=true end
    end
    if record.cancelled then record.cleanupRequested=true end
    cleanup(record)
    return ok and current(record) and not record.failed
end
local function call(record,control,name,...)
    check(record)
    local result=control[name](control,...)
    check(record)
    assert(result~=false,'native '..name..' rejected')
    return result
end
local function visibility(record,ready)
    record.intent.ready=ready
    call(record,record.pool,'SetVisible',ready)
    call(record,record.fallback,'SetVisible',not ready)
end
-- The existing property writer receives guarded handles; every native setter,
-- property assignment and Color callback is checked before the next operation.
local function guardedControl(record,control)
    return setmetatable({}, {__index=function(_,key)
        local value=control[key]
        if type(value)=='function'then return function(_,...)return call(record,control,key,...)end end
        check(record);return value
    end,__newindex=function(_,key,value)
        check(record);control[key]=value;check(record)
    end})
end
local function guardedPlatform(record)
    return setmetatable({color=function(...)
        check(record);local value=record.platform.color(...);check(record);return value
    end},{__index=record.platform})
end
function M.release(box,fallback,pool)
    local prior=intents[box]
    -- An ordinary release inside a visibility callback is the same pending
    -- intent, not a fresh replacement. Explicit binds always get a new owner.
    local repeated=not fallback and prior and not prior.ready and not records[box] and (not pool or pool==prior.pool)
    local intent=repeated and prior or (fallback or prior) and claim(box,pool or prior and prior.pool,fallback or prior.fallback)
    local pending={}
    for _,record in ipairs(order)do
        if not record.removed and record.box==box then cancel(record);pending[#pending+1]=record end
    end
    for _,record in ipairs(pending)do cleanup(record)end
    if #pending==0 and operationDepth==0 and intent and intents[box]==intent then reconcile(box)end
    return intent
end
function M.clear()
    if clearing then return end
    clearing=true;generation=generation+1;records={}
    local pending={}
    for _,record in ipairs(order)do
        if not record.removed then
            if intents[record.box]==record.intent then claim(record.box,record.pool,record.fallback)end
            cancel(record);pending[#pending+1]=record
        end
    end
    for _,record in ipairs(pending)do cleanup(record)end
    clearing=false
end
function M.configure(value)
    if value then
        assert(type(value.instantiate)=='function' and type(value.destroy)=='function','native art creation API missing')
        for _,key in ipairs({'imageTemplateIndex','containerTemplateIndex'})do
            local index=value[key]
            assert(type(index)=='number' and index>0 and index%1==0,'native art templateIndex missing')
        end
    end
    -- Set first: a newer configure invoked by cleanup must not be overwritten.
    api=value;M.clear()
end
-- Compact candidates retain their explicit pixel coordinates, not thousands of
-- expanded slot tables. Preflight once before allocation; decode only on draw.
local drawings=setmetatable({},{__mode='k'})
local center,unit,zero={.5,.5},{1,1},{0,0,0}
local function rectangleGeometry(data,index)
    local offset=(index-1)*14
    return tonumber(data:sub(offset+1,offset+2),16),tonumber(data:sub(offset+3,offset+4),16),
        tonumber(data:sub(offset+5,offset+6),16),tonumber(data:sub(offset+7,offset+8),16)
end
local function rectangleHeader(metadata)
    local data,count=metadata.rectangles,metadata.rectangleCount
    if metadata.slots~=nil or metadata.rectangleEncoding~='xywh-rgb24-hex14' then return false end
    if type(data)~='string' or type(count)~='number' then return false end
    return count>=1 and count<=MAX_SLOTS and count%1==0 and #data==count*14 and not data:find('[^%x]')
end
local function rectangleBounds(data,count)
    for index=1,count do
        local x,y,w,h=rectangleGeometry(data,index)
        if w==0 or h==0 or x+w>144 or y+h>64 then return false end
    end
    return true
end
local function drawing(metadata)
    if drawings[metadata]~=nil then return drawings[metadata]end
    local result=false
    if metadata.rectangles~=nil then
        if rectangleHeader(metadata) and rectangleBounds(metadata.rectangles,metadata.rectangleCount)then
            result={rectangles=metadata.rectangles,count=metadata.rectangleCount}
        end
    elseif type(metadata.slots)=='table' and #metadata.slots>=1 and #metadata.slots<=MAX_SLOTS then
        result={slots=metadata.slots,count=#metadata.slots}
    end
    drawings[metadata]=result;return result
end
local function drawingSlot(data,index)
    if data.slots then return data.slots[index]end
    local x,y,w,h=rectangleGeometry(data.rectangles,index)
    local offset=(index-1)*14
    local function channel(first)return tonumber(data.rectangles:sub(offset+first,offset+first+1),16)end
    return {image=100001,imageType='stretch',position={x+w/2-72,32-y-h/2},size={w,h},
        anchorMin=center,anchorMax=center,pivot=center,scale=unit,rotation=zero,
        colour={channel(9),channel(11),channel(13),255}}
end
function M.request(box,pool,metadata,platform,fallback,identity,writeSlot)
    if clearing or not api then return false,'native art runtime not configured' end
    local previous=records[box]
    if previous and previous.metadata==metadata and previous.pool==pool and previous.fallback==fallback then
        previous.identity=identity
        if not previous.failed and operationDepth==0 then work(previous,function()visibility(previous,previous.ready==true)end)end
        return current(previous) and previous.ready==true,previous.reason
    end
    local data=drawing(metadata)
    if not data then M.release(box,fallback,pool);return false,'native art drawing rejected' end
    if previous then cancel(previous)end
    local record={box=box,pool=pool,metadata=metadata,platform=platform,fallback=fallback,identity=identity,
        generation=generation,groups={},controls={},drawing=data,writeSlot=writeSlot,destroy=api.destroy,
        intent=claim(box,pool,fallback),
        instantiate=api.instantiate,imageTemplateIndex=api.imageTemplateIndex,containerTemplateIndex=api.containerTemplateIndex}
    records[box]=record;order[#order+1]=record
    -- Register the replacement before cleanup callbacks can issue a newer request.
    if previous then cleanup(previous)end
    if operationDepth==0 and current(record)then work(record,function()visibility(record,false)end)end
    return false,record.reason or 'native art pending'
end
local function makeGroup(record)
    check(record)
    local control=assert(record.instantiate(record.containerTemplateIndex,record.pool),'native group creation failed')
    record.groups[#record.groups+1]={control=control,count=0}
    check(record) -- A cancellation inside Instantiate cannot orphan its return.
    call(record,control,'SetAnchorMin',.5,.5);call(record,control,'SetAnchorMax',.5,.5);call(record,control,'SetPivot',.5,.5)
    call(record,control,'SetSizeDelta',144,64);call(record,control,'SetLocalScale',1,1,1);call(record,control,'SetLocalRotation',0,0,0)
    call(record,control,'SetAnchoredPosition',0,0);call(record,control,'SetVisible',true)
end
local function advance(record)
    check(record)
    local index=#record.controls+1
    if index%60==1 and #record.groups<math.ceil(index/60)then makeGroup(record);return end
    local group=record.groups[#record.groups]
    local control=assert(record.instantiate(record.imageTemplateIndex,group.control),'native image creation failed')
    group.count=group.count+1;record.controls[index]=control
    check(record)
    local guarded=guardedControl(record,control);guarded.raycastTarget=false
    local result=record.writeSlot(guarded,drawingSlot(record.drawing,index),guardedPlatform(record))
    check(record);assert(result~=false,'native slot writer rejected')
    if index==record.drawing.count then visibility(record,true);check(record);record.ready=true end
end
local function sweep()
    local kept={}
    for _,record in ipairs(order)do
        if not record.removed then
            if not alive(record.box) or not alive(record.pool)then
                cancel(record);record.removed=true -- Native owner owns its destroyed subtree.
            else kept[#kept+1]=record end
        end
    end
    order=kept
end
local function blocked(record)
    for _,other in ipairs(order)do
        if other~=record and not other.removed and other.box==record.box and other.allocated then return true end
    end
    return false
end
local function eligible(record)
    return not record.failed and not record.cancelled and not record.removed and not record.ready
end
function M.update()
    if updating or operationDepth>0 or clearing then return end
    updating=true;createdLastUpdate=0;sweep()
    if api then
        local count=livePools()
        for _,record in ipairs(order)do
            if eligible(record) and not record.allocated and count<MAX_POOLS and not blocked(record)then
                record.allocated=true;count=count+1
            end
        end
        local progressed=true
        while createdLastUpdate<MAX_CREATES and progressed do
            progressed=false
            for _,record in ipairs(order)do
                if record.allocated and eligible(record) and createdLastUpdate<MAX_CREATES then
                    createdLastUpdate=createdLastUpdate+1;progressed=true
                    work(record,function()advance(record)end)
                end
            end
        end
    end
    updating=false
end
function M.status()
    local status={livePools=livePools(),waitingPools=0,failedPools=0,liveControls=0,
        createdLastUpdate=createdLastUpdate,maxPools=MAX_POOLS,maxCreatesPerUpdate=MAX_CREATES}
    for _,record in ipairs(order)do
        if not record.removed then
            if record.failed then status.failedPools=status.failedPools+1
            elseif not record.allocated then status.waitingPools=status.waitingPools+1 end
            for _,group in ipairs(record.groups)do status.liveControls=status.liveControls+group.count+1 end
        end
    end
    return status
end
return M
