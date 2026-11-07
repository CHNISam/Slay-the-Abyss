local T=dofile('experiments/native-3d-lab/card-tween.lua')
local function fixture()
    local view={run={combat={}},active=true,canvasWidth=1600,canvasHeight=900}
    local box={alive=true,anchoredPositionX=10}
    local hit={x=3,y=4,width=110,height=220,angle=-9}
    local entry={box=box,labUid=10,visible=true,labLayout={count=1,index=0,hot=false},
        current={x=10,y=-100,scale=1.2,angle=9},target={x=10,y=-100,scale=1.2,angle=9,restAngle=9,baseY=-100}}
    local paints=0
    local controller=T.attach(view,{entries=function()return {[10]=entry}end,paint=function(e)
        T.recordPaint(e.box);e.box.anchoredPositionX=e.current.x;paints=paints+1
    end})
    local tweens={}
    game={Tween=function(object,values,duration)
        local tween={object=object,values=values,duration=duration}
        function tween:SetOnComplete(fn)self.callback=fn;return self end
        function tween:Play()self.played=true;return self end
        function tween:Kill(complete)self.killed=true;self.killComplete=complete end
        tweens[#tweens+1]=tween;return tween
    end}
    return view,entry,controller,tweens,hit,function()return paints end
end
local function equal(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
do
    local view,e,c,tweens,hit,paints=fixture()
    assert(T.start({battleUI=view},'tween'));equal(e.current.x,82);equal(tweens[1].values.anchoredPositionX,10)
    equal(tweens[1].duration,.24);assert(tweens[1].played)
    e.box.anchoredPositionX=46;assert(c:before(e,.12,nil));equal(e.current.x,46);c:after(e)
    assert(c:holdRender(e,e.box,1,0,false));equal(paints(),1)
    equal(e.current.y,-100);equal(e.current.scale,1.2);equal(e.current.angle,9)
    equal(hit.x,3);equal(hit.y,4);equal(hit.width,110);equal(hit.height,220);equal(hit.angle,-9)
    e.box.anchoredPositionX=10;tweens[1].callback();equal(e.current.x,10);equal(paints(),2)
    local result=T.result(view);assert(result.completed);equal(result.setterWrites,14);equal(result.setupCalls,3)
    assert(T.status(view):find('非GPU',1,true));equal(result.cardUid,10)
end
do
    local view,e,c,tweens=fixture();assert(T.start(view,'tween'));e.box.anchoredPositionX=35
    assert(not c:before(e,.016,{uid=10,moving=true}));assert(tweens[1].killed);equal(tweens[1].killComplete,false);equal(e.current.x,35)
    local previous=e.current.x;tweens[1].callback();equal(e.current.x,previous);equal(T.result(view).reason,'drag')
end
do
    local view,e,c,tweens=fixture();assert(T.start(view,'tween'));e.box.anchoredPositionX=29;e.target.x=15
    assert(not c:holdRender(e,e.box,1,0,false));assert(tweens[1].killed);equal(e.current.x,29);equal(T.result(view).reason,'new_target')
end
for _,kind in ipairs({'resize','battle','destroy','stop','removed'})do
    local view,e,c,tweens=fixture();assert(T.start(view,'tween'));e.box.anchoredPositionX=27
    if kind=='resize'then view.canvasWidth=800;c:before(e,.016,nil)
    elseif kind=='battle'then view.run={combat={}};c:before(e,.016,nil)
    elseif kind=='destroy'then e.box.alive=false;c:before(e,.016,nil)
    elseif kind=='removed'then c:removed(e)
    else T.cancel(view,'stop')end
    assert(tweens[1].killed,kind);equal(tweens[1].killComplete,false);equal(e.current.x,27)
    assert(not T.result(view).completed)
end
-- Completion may arrive before the next CardView update/render. Every state
-- snapshot must be checked at the callback boundary, before a target write.
for _,kind in ipairs({'resize','battle','destroy','root_destroy','disabled','target','drag','phase'})do
    local view,e,c,tweens,hit,paints=fixture()
    assert(T.start(view,'tween'));e.box.anchoredPositionX=31
    if kind=='resize'then view.canvasWidth=800
    elseif kind=='battle'then view.run={combat={}}
    elseif kind=='destroy'then e.box.alive=false
    elseif kind=='root_destroy'then view.root={alive=false}
    elseif kind=='disabled'then view.active=false
    elseif kind=='target'then e.target.x=22
    elseif kind=='drag'then view.gesture={uid=10,moving=true}
    elseif kind=='phase'then view.run.phase='reward'end
    tweens[1].callback()
    equal(paints(),1);equal(e.current.x,31);assert(tweens[1].killed,kind);equal(tweens[1].killComplete,false)
    local result=T.result(view)
    assert(not result.completed,kind);assert(not result.valid,kind);assert(result.comparisons.tween==nil,kind)
    assert(result.reason~='completed:tween',kind)
end
do
    local view,e,c=fixture();game.Tween=nil
    local ok,why=T.start(view,'tween');assert(not ok and why:find('缺少',1,true));equal(e.current.x,10)
    assert(T.start(view,'manual'))
    for _=1,100 do
        local native=c:before(e,1/60,nil);assert(not native)
        local x=e.current.x+(e.target.x-e.current.x)*.1
        e.current.x=math.abs(x-e.target.x)<.667 and e.target.x or x
        T.recordPaint(e.box);e.box.anchoredPositionX=e.current.x;c:after(e)
        if T.result(view).completed then break end
    end
    local result=T.result(view);assert(result.completed);assert(result.setterWrites>100);equal(result.reads,0);equal(result.setupCalls,0)
end
do
    local view,e,c,tweens=fixture()
    game.Tween=function()error('injected failure')end
    local ok,why=T.start(view,'tween');assert(not ok and why:find('不可用',1,true));assert(not c.active)
    assert(not T.result(view).valid);assert(not c:before(e,.016,nil))
end
print('card tween: ownership, hitbox invariance, counters, drag/resize/battle/destroy/cancel/failure passed; mocked engine only')
