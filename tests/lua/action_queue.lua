package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Queue=require("abyss_action_queue")
local count=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function test(name,fn) fn();count=count+1;print("ok action_queue "..count.." - "..name) end
local function effect(label) return {kind="effect",effect={op="example",label=label}} end
test("top insertion preempts pending work while bottom follows cleanup",function()
    local s,seen={},{}
    Queue.start(s,{effect("a"),effect("b"),{kind="useCard",uid=7}})
    Queue.run(s,{effect=function(state,a,q)
        seen[#seen+1]=a.effect.label
        if a.effect.label=="a" then q.pushTop(state,effect("top"));q.pushBottom(state,effect("bottom")) end
    end,useCard=function() seen[#seen+1]="use" end})
    eq(table.concat(seen,","),"a,top,b,use,bottom");eq(Queue.active(s),false)
end)
test("pause preserves popped current and resume never reexecutes it",function()
    local s,n={},0;local a=effect("pause")
    local handlers={effect=function(state,action)
        n=n+1
        if action.effect.label=="pause" then state.pendingScry={token=1};return "pause" end
    end}
    Queue.start(s,{a,effect("later")});eq(Queue.run(s,handlers),"pause")
    eq(s.actionQueue.current,a);eq(#s.actionQueue.actions,1);eq(n,1)
    eq(Queue.run(s,handlers),"pause");eq(n,1)
    assert(not pcall(Queue.resume,s,handlers));eq(n,1)
    s.pendingScry=nil;eq(Queue.resume(s,handlers),true);eq(n,2);eq(s.actionQueue,nil)
end)
test("allow filters terminal actions while preserving allowed order",function()
    local s,seen={},{}
    Queue.start(s,{effect("draw"),effect("block"),{kind="useCard",uid=1}})
    Queue.run(s,{allow=function(_,a) return a.kind=="useCard" or a.effect.label=="block" end,
        effect=function(_,a) seen[#seen+1]=a.effect.label end,useCard=function() seen[#seen+1]="use" end})
    eq(table.concat(seen,","),"block,use")
end)
test("only serializable acyclic data is accepted without replacing live queue",function()
    local invalid={effect("x"),effect("x"),{kind="unknown"}}
    invalid[1].callback=function() end
    invalid[2].self=invalid[2]
    for _,a in ipairs(invalid) do local s={};assert(not pcall(Queue.start,s,{a}));eq(s.actionQueue,nil) end
    local s={};assert(not pcall(Queue.start,s,{[2]=effect("hole")}))
    Queue.start(s,{effect("first")});local q=s.actionQueue
    assert(not pcall(Queue.start,s,{}));eq(s.actionQueue,q)
    assert(not pcall(Queue.pushBottom,s,{kind="effect",value=0/0}));eq(#q.actions,1)
end)
test("reentrant run and missing handlers fail for owning transaction",function()
    local s={};Queue.start(s,{effect("first")})
    local called=false
    Queue.run(s,{effect=function(state)
        assert(not pcall(Queue.run,state,{}));called=true
    end})
    eq(called,true)
    Queue.start(s,{{kind="useCard",uid=1}})
    assert(not pcall(Queue.run,s,{}));eq(s.actionQueue.current.uid,1)
end)
test("empty action list completes without storing handlers",function()
    local s={};Queue.start(s,{});eq(Queue.run(s,{}),true);eq(s.actionQueue,nil)
end)
test("false handler result propagates its reason to the owning transaction",function()
    local s={};local failure={reason="refused"};local a=effect("refuse")
    Queue.start(s,{a,effect("must_not_run")})
    local ok,reason=pcall(Queue.run,s,{effect=function() return false,failure end})
    eq(ok,false);eq(reason,failure);eq(s.actionQueue.current,a);eq(#s.actionQueue.actions,1)
    local skipped={}
    Queue.start(skipped,{effect("skip")})
    eq(Queue.run(skipped,{allow=function() return false end,
        effect=function() error("filtered action executed") end}),true)
end)
print("ACTION_QUEUE_PASS "..count)
