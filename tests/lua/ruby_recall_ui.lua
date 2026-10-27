local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 7
local sliceRegistered,sliceExecuted=0,0
-- Actual NodeUI/Nodes integration with generated controls and mocked native calls.
-- History qualification is controlled input, not earned/persistent campaign evidence.
local UI,Nodes,Run,Map=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map')
local Copy,Data=require('abyss_combat').copy,require('abyss_data')
local Layout,Presentation=require('abyss_ui_layout'),require('abyss_presentation')
local events={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local count=0
local function test(name,fn)
    sliceRegistered=sliceRegistered+1
    if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end
    fn();sliceExecuted=sliceExecuted+1;count=count+1
    print('ok ruby recall UI '..count..' - '..name)
    print('RUBY_RECALL_UI_CASE '..sliceRegistered)
end
local function same(a,b,path,seen)
    if a==b then return end
    path=path or 'state';assert(type(a)==type(b),path..' type')
    if type(a)~='table' then assert(a==b,path..' value');return end
    seen=seen or {};if seen[a] then assert(seen[a]==b,path..' alias');return end;seen[a]=b
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k),seen)end
    for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function find(list,name)
    for _,spec in ipairs(list)do
        if spec.name==name then return spec end
        local found=spec.children and find(spec.children,name);if found then return found end
    end
end
local function control(spec,parent)
    local c={name=spec.name,parent=parent,children={},listeners={},visible=spec.visible~=false,
        text=spec.text and spec.text.content or '',scale={1,1,1}}
    function c:GetChild(name)return self.children[name]end
    function c:SetVisible(value)assert(type(value)=='boolean');self.visible=value end
    function c:SetImage(source,id)assert(source=='static' and type(id)=='number');self.imageId=id end
    function c:SetSizeDelta(width,height) NativeContract.sizeDelta(width,height);
        self.size={width,height};self.sizeDeltaX,self.sizeDeltaY=width,height
    end
    function c:SetLocalScale(x,y,z)self.scale={x,y,z}end
    function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
    function c:AddCursorEventListener(event,fn) NativeContract.listener(event,fn);assert(not self.listeners[event]);self.listeners[event]=fn end
    function c:emit(event,id)return assert(self.listeners[event],event)({touchId=id})end
    for _,child in ipairs(spec.children or {})do c.children[child.name]=control(child,c)end
    return c
end
local maps={}
local function camp(options)
    options=options or {};local act=options.act or 1
    if not maps[act] then
        local map=Map.generate(Data,'42',act)
        while true do
            local available=Map.available(map);assert(#available>0)
            local target
            for _,node in ipairs(available)do if node.type=='camp' then target=node;break end end
            if target then maps[act]={map=map,id=target.id};break end
            -- Prior navigation is staged, never claimed as a natural played run.
            assert(Map.choose(map,available[1].id))
        end
    end
    local run=Run.new(Data,'42',not options.standalone and {experimental=true,campaign=true} or nil)
    if not options.standalone then run.act=act;run.endingUnlocked=true end
    for _,relic in ipairs(options.relics or {})do assert(Run.obtainRelic(run,relic))end
    local map=Copy(maps[act].map);assert(Nodes.enter(run,map,maps[act].id))
    if options.hp then run.hp=options.hp end
    return run,map
end
local function setup(run,map)
    local host=control({name='host',children={assert(find(Layout,'nodePanel'))}})
    local root=host:GetChild('nodePanel');local changes={}
    local ui=UI.new(root,run,map,Presentation,'click',function(ok,reason)
        changes[#changes+1]={ok=ok,reason=reason}
    end,{cursorEvents=events,imageSource='static'})
    ui:setVisible(true)
    local function get(path)
        local node=root;for part in path:gmatch('[^/]+')do node=assert(node:GetChild(part),path)end;return node
    end
    local function shown(path)
        local node=get(path);while node do if not node.visible then return false end;node=node.parent end;return true
    end
    local function click(path,id)
        assert(shown(path),'hidden '..path);local hit=get(path):GetChild('hit');id=id or 1
        hit:emit('down',id);hit:emit('up',id);return hit:emit('click',id)
    end
    return ui,get,shown,click,changes,root
end
local function unchanged(run,map,fn)
    local before,mapBefore=Copy(run),Copy(map);local ok,why=fn()
    assert(ok==false and type(why)=='string',tostring(why));same(run,before);same(map,mapBefore)
    return why
end
local function parity(run,map,command,arg,click)
    local expected,expectedMap=Copy(run),Copy(map)
    if command=='recall' then assert(Nodes.recall(expected,expectedMap,assert(Nodes.recallSource(expected,expectedMap))))
    else assert(Nodes[command](expected,arg))end
    assert(click());same(run,expected);same(map,expectedMap)
end

test('default standalone retains the exact two camp actions and no Recall footer',function()
    local run,map=camp({standalone=true,hp=20});local before,mapBefore=Copy(run),Copy(map)
    local ui,get,shown,click=setup(run,map);same(run,before);same(map,mapBefore)
    assert(shown('campView/rest') and shown('campView/forge') and not shown('confirm') and not shown('back'))
    assert(get('campView/rest/description').text=='回复 24 点生命\n生命 20 → 44')
    assert(get('campView/forge/description').text=='升级一张卡牌\n可升级 10 张')
    assert(get('notice').text=='篝火旁，旅行者稍作停留 · 休息或锻造，只能选一项')
    unchanged(run,map,function()return ui:press('confirm')end)
    parity(run,map,'rest',nil,function()return click('campView/rest')end)
end)

test('eligible Recall is last existing footer and exact public-command full-state/map/RNG parity',function()
    local run,map=camp({hp=17,relics={'Dream Catcher','Regal Pillow','Ancient Tea Set','MawBank'}})
    run.gold=231;run.potions={'block_potion'};run.nodeFlow.reward={gold=27,relicId='vajra'}
    local project,command=Nodes.recallSource,Nodes.recall;local projections,token=0
    Nodes.recallSource=function(...)local source,reason=project(...);projections=projections+1;token=source;return source,reason end
    local ui,get,shown,click=setup(run,map)
    Nodes.recallSource=project
    assert(projections==1 and shown('campView/rest') and shown('campView/forge') and shown('confirm'))
    assert(get('confirm/label').text=='Recall' and not shown('back') and ui.recallSource==nil)
    local expected,expectedMap=Copy(run),Copy(map)
    assert(command(expected,expectedMap,assert(project(expected,expectedMap))))
    local received
    Nodes.recall=function(r,m,source)received=source;return command(r,m,source)end
    assert(click('confirm'));Nodes.recall=command
    assert(received==token,'render-time token must remain private and unchanged through Down/Up/Click')
    same(run,expected);same(map,expectedMap)
    unchanged(run,map,function()return get('confirm/hit'):emit('click',1)end)
    assert(run.keys.ruby and not run.keys.emerald and not run.keys.sapphire and ui:holding())
    assert(get('confirm/label').text=='继续' and get('notice').text=='Recall · Ruby')
    assert(click('confirm') and not ui:holding());same(run,expected);same(map,expectedMap)
end)

test('owned Ruby and absent/malformed eligibility never offer Recall',function()
    for _,mutate in ipairs({function(r)r.keys.ruby=true end,function(r)r.endingUnlocked=nil end,
        function(r)r.endingUnlocked='true'end,function(r)r.keys.sapphire='false'end})do
        local run,map=camp();mutate(run);local ui,_,shown=setup(run,map)
        assert(not shown('confirm'));unchanged(run,map,function()return ui:press('confirm')end)
    end
end)

test('missing core projection or command stays inert without a UI eligibility fallback',function()
    local project,command=Nodes.recallSource,Nodes.recall
    for _,missing in ipairs({'projection','command','token'})do
        local run,map=camp()
        if missing=='projection' then Nodes.recallSource=nil
        elseif missing=='command' then Nodes.recall=nil
        else Nodes.recallSource=function()return nil,'unavailable'end end
        local ui,_,shown=setup(run,map);assert(not shown('confirm'))
        unchanged(run,map,function()return ui:press('confirm')end)
        Nodes.recallSource,Nodes.recall=project,command
    end
end)

test('rest and committed upgrade retain exact commands and hide Recall',function()
    local run,map=camp({hp=20});local ui,get,_,click=setup(run,map)
    parity(run,map,'rest',nil,function()return click('campView/rest')end)
    assert(not run.keys.ruby and get('confirm/label').text=='继续' and not Nodes.recallSource(run,map))
    run,map=camp();ui,get,_,click=setup(run,map)
    assert(click('campView/forge') and get('confirm/label').text=='确认升级')
    assert(click('pickerView/card1'));local uid=ui.selected
    parity(run,map,'upgrade',uid,function()return click('confirm')end)
    assert(not run.keys.ruby and not Nodes.recallSource(run,map))
end)

test('Dream Catcher committed rest blocks a previously armed Recall and keeps its picker',function()
    local run,map=camp({hp=20,relics={'Dream Catcher'}});local ui,get,shown,click=setup(run,map)
    local hit=get('confirm/hit');hit:emit('down',7)
    assert(Nodes.rest(run) and run.nodeFlow.restReward and not run.nodeFlow.restReward.resolved)
    unchanged(run,map,function()hit:emit('up',7);return hit:emit('click',7)end)
    assert(not run.keys.ruby and not Nodes.recallSource(run,map));ui:render()
    assert(shown('pickerView') and not shown('campView') and get('confirm/label').text=='选择此牌')
    parity(run,map,'claimRestReward',0,function()return click('back')end)
end)

test('old Down then render/context change rejects before fresh gesture recovery',function()
    local run,map=camp();local ui,get,_,click=setup(run,map);local hit=get('confirm/hit')
    hit:emit('down',8);ui:render()
    unchanged(run,map,function()hit:emit('up',8);return hit:emit('click',8)end)
    parity(run,map,'recall',nil,function()return click('confirm',9)end)
end)

test('chapter/run/map replacement cannot adopt a new source at late Click',function()
    local run,map=camp();local ui,get,_,click=setup(run,map);local hit=get('confirm/hit');hit:emit('down',10)
    local nextRun,nextMap=camp({act=2});ui.run,ui.map=nextRun,nextMap
    unchanged(nextRun,nextMap,function()hit:emit('up',10);return hit:emit('click',10)end)
    assert(not run.keys.ruby and not nextRun.keys.ruby);ui:render()
    parity(nextRun,nextMap,'recall',nil,function()return click('confirm',11)end)
end)

test('same owner generation/flow replacement refuses old source then recovers',function()
    for _,mutate in ipairs({function(r)r.roomGeneration=r.roomGeneration+1 end,
        function(r)r.nodeFlow=Copy(r.nodeFlow)end})do
        local run,map=camp();local ui,get,_,click=setup(run,map);local hit=get('confirm/hit');hit:emit('down',12)
        mutate(run);unchanged(run,map,function()hit:emit('up',12);return hit:emit('click',12)end)
        ui:render();parity(run,map,'recall',nil,function()return click('confirm',13)end)
    end
end)

test('disabled eligibility after Down rejects without adopting a fresh click-time token',function()
    local run,map=camp();local ui,get,_,click=setup(run,map);local hit=get('confirm/hit');hit:emit('down',14)
    run.endingUnlocked=false
    unchanged(run,map,function()hit:emit('up',14);return hit:emit('click',14)end)
    assert(not run.keys.ruby);run.endingUnlocked=true;ui:render()
    parity(run,map,'recall',nil,function()return click('confirm',15)end)
end)

test('hidden detached resized and cancelled pointer sequences are retired',function()
    for _,cancel in ipairs({'hidden','detached','resized','exit','endDrag'})do
        local run,map=camp();local ui,get,_,click,_,root=setup(run,map)
        local footer,hit=get('confirm'),get('confirm/hit');hit:emit('down',16)
        if cancel=='hidden' then ui:setVisible(false)
        elseif cancel=='detached' then root.children.confirm=nil
        elseif cancel=='resized' then ui:resize(1600,900)
        else hit:emit(cancel,16)end
        unchanged(run,map,function()hit:emit('up',16);return hit:emit('click',16)end)
        root.children.confirm=footer;ui:setVisible(true);ui:render()
        parity(run,map,'recall',nil,function()return click('confirm',17)end)
    end
end)
test('Recall and forge confirmation cannot exchange an old gesture meaning',function()
    local run,map=camp();local ui,get,_,click=setup(run,map);local hit=get('confirm/hit')
    hit:emit('down',18);assert(click('campView/forge',19));assert(click('pickerView/card1',20))
    unchanged(run,map,function()hit:emit('up',18);return hit:emit('click',18)end)
    assert(get('confirm/label').text=='确认升级' and not run.keys.ruby)
    local uid=ui.selected;parity(run,map,'upgrade',uid,function()return click('confirm',21)end)
    run,map=camp();ui,get,_,click=setup(run,map);assert(click('campView/forge'));assert(click('pickerView/card1'))
    hit=get('confirm/hit');hit:emit('down',22);assert(click('back',23))
    assert(get('confirm/label').text=='Recall')
    unchanged(run,map,function()hit:emit('up',22);return hit:emit('click',22)end)
    parity(run,map,'recall',nil,function()return click('confirm',24)end)
end)

test('observed invalid source or hidden host stays retired after repair until a new Down',function()
    for _,stage in ipairs({'down','heldUpdate','up','releasedUpdate','enter','hiddenHost','detachedHost','disabledHost','parentDetach','parentOwner'})do
        local run,map=camp();local ui,get,_,click,_,root=setup(run,map);local hit=get('confirm/hit');local host=root.parent
        if stage=='down' then run.endingUnlocked=false end
        hit:emit('down',25)
        if stage=='heldUpdate' or stage=='up' or stage=='enter' then run.endingUnlocked=false end
        if stage=='enter' then hit:emit('enter',25) end
        if stage=='hiddenHost' then root.visible=false end
        if stage=='detachedHost' then ui.root={} end
        if stage=='disabledHost' then ui.busy=true end
        if stage=='parentDetach' then root.parent=nil end
        if stage=='parentOwner' then host.children.nodePanel=nil end
        if stage=='heldUpdate' or stage:find('Host',1,true) or stage:find('parent',1,true) then ui:update(0.01) end
        if stage=='up' or stage=='releasedUpdate' then hit:emit('up',25) end
        if stage=='releasedUpdate' then run.endingUnlocked=false;ui:update(0.01) end
        run.endingUnlocked=true;root.visible=true;ui.root=root;ui.busy=false;root.parent=host;host.children.nodePanel=root
        unchanged(run,map,function()
            if stage~='up' and stage~='releasedUpdate' then hit:emit('up',25) end
            return hit:emit('click',25)
        end)
        parity(run,map,'recall',nil,function()return click('confirm',26)end)
    end
end)

test('native attachment read reentry cannot commit a retired paint or detached host',function()
    for _,change in ipairs({'render','detachHost'})do
        local run,map=camp();local ui,get,_,click,_,root=setup(run,map);local host=root.parent
        local hit=get('confirm/hit');hit:emit('down',27);hit:emit('up',27)
        local original=root.GetChild;local once=true
        root.GetChild=function(owner,key)
            if key=='confirm' and once then
                once=false
                if change=='render' then ui:render() else host.children.nodePanel=nil end
            end
            return original(owner,key)
        end
        unchanged(run,map,function()return hit:emit('click',27)end)
        root.GetChild=original;host.children.nodePanel=root
        parity(run,map,'recall',nil,function()return click('confirm',28)end)
    end
end)
print('RUBY_RECALL_UI_PASS '..count)

assert(sliceRegistered==14,'all fourteen original Recall UI groups must register')
assert(sliceExecuted==sliceLast-sliceFirst+1,'every selected Recall UI group must execute')
print('RUBY_RECALL_UI_SLICE '..sliceFirst..' '..sliceLast..' '..sliceExecuted)
