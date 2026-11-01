-- Pure-data action continuation. Combat owns transactions and terminal policy.
local M={}
local function dense(list)
    assert(type(list)=="table" and getmetatable(list)==nil,"invalid action list")
    local count=0
    for k in next,list do
        assert(type(k)=="number" and k%1==0 and k>=1,"invalid action index")
        count=count+1
    end
    for i=1,count do assert(rawget(list,i)~=nil,"sparse action list") end
    return count
end
local function data(value,visiting,visited)
    local kind=type(value)
    if kind=="table" then
        assert(getmetatable(value)==nil and not visiting[value],"cyclic or metatable action data")
        if visited[value] then return end
        visiting[value]=true
        for k,v in next,value do
            assert(type(k)=="string" or type(k)=="number","invalid action data key")
            data(k,visiting,visited);data(v,visiting,visited)
        end
        visiting[value]=nil;visited[value]=true
    else
        assert(kind=="string" or kind=="boolean" or kind=="number","non-data action value")
        if kind=="number" then assert(value==value and value>-math.huge and value<math.huge,"invalid action number") end
    end
end
local function action(a)
    assert(type(a)=="table" and getmetatable(a)==nil
        and (rawget(a,"kind")=="effect" or rawget(a,"kind")=="useCard"),"unknown action kind")
    data(a,{},{})
end
local function queue(state)
    assert(type(state)=="table" and type(state.actionQueue)=="table","no action queue")
    local q=state.actionQueue
    assert(type(q.paused)=="boolean","invalid queue pause state")
    dense(q.actions)
    for _,a in ipairs(q.actions) do action(a) end
    if q.current then action(q.current) end
    return q
end
function M.active(state)
    return type(state)=="table" and state.actionQueue~=nil
end
function M.start(state,actions)
    assert(type(state)=="table" and state.actionQueue==nil,"action queue already exists")
    dense(actions)
    local list={}
    for i,a in ipairs(actions) do action(a);list[i]=a end
    state.actionQueue={actions=list,paused=false}
    return true
end
function M.pushTop(state,a)
    action(a);local q=queue(state);table.insert(q.actions,1,a)
end
function M.pushBottom(state,a)
    action(a);local q=queue(state);q.actions[#q.actions+1]=a
end
function M.run(state,handlers)
    local q=queue(state)
    assert(type(handlers)=="table" and (handlers.allow==nil or type(handlers.allow)=="function"),"invalid action handlers")
    if q.paused then return "pause" end
    assert(q.current==nil,"reentrant or unresolved action")
    while #q.actions>0 do
        local a=table.remove(q.actions,1)
        q.current=a
        if not handlers.allow or handlers.allow(state,a)~=false then
            local fn=handlers[a.kind]
            assert(type(fn)=="function","missing action handler: "..a.kind)
            local result,reason=fn(state,a,M)
            assert(result~=false,reason or "action handler returned false")
            assert(state.actionQueue==q,"handler replaced action queue")
            if result=="pause" then q.paused=true;return "pause" end
        end
        q.current=nil
    end
    state.actionQueue=nil
    return true
end
function M.resume(state,handlers)
    local q=queue(state)
    assert(q.paused and q.current~=nil,"action queue not paused")
    assert(state.pendingScry==nil and state.pendingHandChoice==nil and state.pendingDiscard==nil
        and state.pendingPileChoice==nil,"choice still pending")
    q.current=nil;q.paused=false
    return M.run(state,handlers)
end
return M
