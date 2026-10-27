local NativeContract = dofile('tests/lua/support/native_ui_contract.lua')
return function(first,last)
local registered=0
-- Real generated NodeUI + Nodes commands. Prior route/history are staged, not earned/persistent evidence.
local UI,Nodes,Run,Map=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map')
local Copy,Data=require('abyss_combat').copy,require('abyss_data')
local SourceFixture=dofile('tests/lua/support/sapphire_source_fixture.lua')
local Layout,Presentation=require('abyss_ui_layout'),require('abyss_presentation')
local events={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'}
local count=0
local function test(name,fn)
    registered=registered+1
    if registered<first or registered>last then return end
    fn();count=count+1;print('ok sapphire treasure UI '..registered..' - '..name)
end
local function same(a,b,path,forward,backward)
    if a==b then return end
    path=path or 'state';assert(type(a)==type(b),path..' type')
    if type(a)~='table' then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
    forward,backward=forward or {},backward or {}
    if forward[a] then assert(forward[a]==b,path..' alias');return end
    assert(not backward[b],path..' unexpected alias');forward[a],backward[b]=b,a
    for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k),forward,backward)end
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
local function beforeNode(kind,act)
    local key=kind..act
    if not maps[key] then
        local map=Map.generate(Data,'42',act)
        while true do
            local available=Map.available(map);assert(#available>0,'fixture route missing')
            local target
            for _,node in ipairs(available)do
                if (kind=='boss_treasure' and node.roomKind==kind)
                    or (node.type==kind and node.roomKind~='boss_treasure') then target=node;break end
            end
            if target then maps[key]={map=map,id=target.id};break end
            assert(Map.choose(map,available[1].id)) -- navigation-only, not played prior rooms
        end
    end
    return Copy(maps[key].map),maps[key].id
end
local function room(kind,options)
    options=options or {};local act=options.act or 1
    local run=Run.new(Data,'42',not options.standalone and {experimental=true,campaign=true,character=options.character} or nil)
    if not options.standalone then run.act=act;run.endingUnlocked=options.qualified~=false end
    if options.owned then run.keys.sapphire=true end
    if options.exhausted then
        for _,relic in ipairs(run.data.relics.relics)do
            if relic.rarity=='common' or relic.rarity=='uncommon' or relic.rarity=='rare' then run.relics[#run.relics+1]=relic.id end
        end
    end
    SourceFixture.stage(run,{exhausted=options.exhausted,boss=kind=='boss_treasure'})
    local map,id=beforeNode(kind,act)
    if kind=='boss_treasure' then
        run.nodeFlow={id=map.currentNodeId,floor=map.floor,type='boss',complete=true,result='boss_victory',
            mapSeed=map.seed,mapSignature=map.sourceSignature} -- staged victory, not earned
    end
    assert(Nodes.enter(run,map,id));return run,map
end
local function treasure(options)return room('treasure',options)end
local function setup(run,map,clickOnly)
    local host=control({name='host',children={assert(find(Layout,'nodePanel'))}})
    local root=host:GetChild('nodePanel');local changes={}
    local ui=UI.new(root,run,map,Presentation,'click',function(ok,reason)changes[#changes+1]={ok=ok,reason=reason}end,
        {cursorEvents=clickOnly and {} or events,imageSource='static'})
    ui:setVisible(true)
    local function get(path)
        local node=root;for part in path:gmatch('[^/]+')do node=assert(node:GetChild(part),path)end;return node
    end
    local function shown(path)
        local node=get(path);while node do if not node.visible then return false end;node=node.parent end;return true
    end
    local function click(path,id)
        assert(shown(path),'hidden '..path);local hit=get(path):GetChild('hit');id=id or 1
        if not clickOnly and hit.listeners.down then hit:emit('down',id);hit:emit('up',id)end
        return hit:emit('click',id)
    end
    return ui,get,shown,click,changes,root
end
local function unchanged(run,map,fn,label)
    local before,mapBefore=Copy(run),Copy(map);local roots={};for key,value in pairs(run)do if type(value)=='table' then roots[key]=value end end
    local nodes,path=map.nodes,map.path;local ok,why=fn()
    assert(ok==false and type(why)=='string',(label and label..': ' or '')..tostring(why));same(run,before);same(map,mapBefore)
    for key,value in pairs(roots)do assert(run[key]==value,'refusal replaced '..key)end
    assert(map.nodes==nodes and map.path==path);return why
end
local function parity(run,map,choice,click)
    local expected,expectedMap=Copy(run),Copy(map)
    assert(Nodes.chooseTreasure(expected,expectedMap,assert(Nodes.treasureSource(expected,expectedMap)),choice))
    assert(click());same(run,expected);same(map,expectedMap)
end
local function legacy(run,map,command,arg,click)
    local expected,expectedMap=Copy(run),Copy(map);assert(Nodes[command](expected,arg));assert(click())
    same(run,expected);same(map,expectedMap)
end
local paths={relic='treasureView/take',sapphire='confirm'}
local function opened(options,clickOnly)
    local run,map=treasure(options);local ui,get,shown,click,changes,root=setup(run,map,clickOnly)
    assert(click('treasureView/chest'));return run,map,ui,get,shown,click,changes,root
end

test('standalone keeps exact closed/open states and legacy displayed reward action',function()
    local run,map=treasure({standalone=true});local before,mapBefore=Copy(run),Copy(map)
    local ui,get,shown,click=setup(run,map);same(run,before);same(map,mapBefore)
    assert(shown('treasureView/closed') and not shown('treasureView/open') and not shown('treasureView/take') and not shown('confirm'))
    assert(get('notice').text=='小型宝箱就在眼前；可以打开或直接离开。')
    assert(Nodes.openTreasure(before));assert(click('treasureView/chest'));same(run,before);same(map,mapBefore)
    assert(shown('treasureView/open') and not shown('treasureView/closed') and shown('treasureView/reward') and not shown('confirm'))
    assert(get('treasureView/take/label').text=='领取奖励' and get('notice').text=='领取所需奖励，或离开宝箱。')
    unchanged(run,map,function()return ui:press('confirm')end)
    legacy(run,map,'claimTreasureReward',assert(Nodes.treasureRewardSource(run,run.nodeFlow.reward.items[1].slot)),function()return click('treasureView/take')end)
end)

test('opened eligible chest privately binds the exact rendered token for BOTH public choices',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local run,map=treasure();local before,mapBefore=Copy(run),Copy(map);assert(Nodes.openTreasure(before))
        local project,command=Nodes.treasureSource,Nodes.chooseTreasure;local projections,renderSource=0,nil
        Nodes.treasureSource=function(...)local token,reason=project(...);projections=projections+1;renderSource=token;return token,reason end
        local ui,get,shown,click=setup(run,map);assert(projections==0 and not shown('confirm'))
        assert(click('treasureView/chest'));Nodes.treasureSource=project
        assert(projections==1 and shown('confirm') and shown('treasureView/take') and ui.treasureSource==nil)
        assert(get('confirm/label').text=='蓝钥匙' and get('treasureView/take/label').text=='领取遗物')
        local relicName=get('treasureView/reward/name').text:match('遗物 · (.+)')
        assert(get('notice').text=='遗物与蓝钥匙只能选一项 · 选择蓝钥匙将放弃遗物「'..relicName..'」')
        same(run,before);same(map,mapBefore)
        local received,selected
        Nodes.chooseTreasure=function(r,m,token,option)received,selected=token,option;return command(r,m,token,option)end
        parity(run,map,choice,function()return click(paths[choice])end);Nodes.chooseTreasure=command
        assert(received==renderSource and selected==choice,'must submit the unchanged private render token')
    end
end)

test('Sapphire grants only its canonical key result and explicitly reports forfeited relic',function()
    local run,map,ui,get,_,click=opened();run.hp=17;run.gold=231;run.potions={'block_potion'}
    local hp,gold,relics=run.hp,run.gold,#run.relics
    local obtain,gainGold=Run.obtainRelic,Run.gainGold
    Run.obtainRelic=function()error('UI key path obtained relic')end;Run.gainGold=function()error('UI key path gave gold')end
    parity(run,map,'sapphire',function()return click('confirm')end)
    Run.obtainRelic,Run.gainGold=obtain,gainGold
    assert(run.keys.sapphire and not run.keys.ruby and not run.keys.emerald and run.hp==hp and run.gold==gold and #run.relics==relics)
    assert(run.nodeFlow.reward.relicId==nil and run.nodeFlow.reward.sapphireKey==nil)
    assert(get('notice').text:find('已获得蓝钥匙 · 已放弃遗物「',1,true)==1 and not ui:holding())
    assert(get('confirm/label').text=='返回路线' and run.nodeFlow.treasureChoice=='sapphire')
end)

test('both choices expire the opposite reward and stale repeats never take a second action',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local run,map,ui,get,_,click=opened();local old={ui.actions.confirm.handler,ui.actions['treasureView/take'].handler}
        local hit=get(paths[choice]..'/hit');parity(run,map,choice,function()return click(paths[choice],3)end)
        unchanged(run,map,function()return hit:emit('click',3)end)
        for _,handler in ipairs(old)do unchanged(run,map,handler)end
        assert(not Nodes.treasureSource(run,map))
    end
end)

test('missing history owned key malformed eligibility never offers a key or invents qualification',function()
    for _,options in ipairs({{qualified=false},{owned=true},{standalone=true}})do
        local run,map,ui,get,shown,click=opened(options);assert(not shown('confirm'))
        unchanged(run,map,function()return ui:press('confirm')end)
        assert(get('treasureView/take/label').text=='领取奖励')
        legacy(run,map,'claimTreasureReward',assert(Nodes.treasureRewardSource(run,run.nodeFlow.reward.items[1].slot)),function()return click('treasureView/take')end)
    end
    local run,map=treasure();local ui,_,shown,click=setup(run,map)
    assert(click('treasureView/chest'));run.keys.emerald='false';ui:render()
    assert(not shown('confirm'));unchanged(run,map,function()return ui:press('confirm')end)
end)

test('missing core API or absent/malformed token has no UI fallback key grant',function()
    local project,command=Nodes.treasureSource,Nodes.chooseTreasure
    for _,missing in ipairs({'projection','command','nilToken','malformedToken'})do
        local run,map=treasure()
        if missing=='projection' then Nodes.treasureSource=nil elseif missing=='command' then Nodes.chooseTreasure=nil
        elseif missing=='nilToken' then Nodes.treasureSource=function()return nil end
        else Nodes.treasureSource=function()return {}end end
        local ui,_,shown,click=setup(run,map);assert(click('treasureView/chest') and not shown('confirm'))
        unchanged(run,map,function()return ui:press('confirm')end)
        Nodes.treasureSource,Nodes.chooseTreasure=project,command
    end
end)

test('source gold-only after relic removal and Boss chest retain independent claims without Sapphire',function()
    local run,map,_,get,shown,click=opened({exhausted=true});assert(not shown('confirm'))
    assert(get('treasureView/reward/description').text=='独立领取宝箱金币。')
    legacy(run,map,'claimTreasureReward',assert(Nodes.treasureRewardSource(run,run.nodeFlow.reward.items[1].slot)),function()return click('treasureView/take')end)
    run,map=room('boss_treasure');local ui;ui,get,shown,click=setup(run,map);assert(click('treasureView/chest'))
    assert(not shown('confirm') and shown('back') and get('back/label').text=='跳过遗物')
    assert(click('treasureView/next'));local selected=ui.treasureChoice
    legacy(run,map,'claimBossTreasure',selected,function()return click('treasureView/take')end)
    assert(not run.keys.sapphire)
end)

test('rerender never lets an old relic or key Down acquire a new action identity',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local run,map,ui,get,_,click=opened();local hit=get(paths[choice]..'/hit');hit:emit('down',4);ui:render()
        unchanged(run,map,function()hit:emit('up',4);return hit:emit('click',4)end)
        parity(run,map,choice,function()return click(paths[choice],5)end)
    end
end)

test('run map and chapter replacement never adopt a new source at late Click',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local run,map,ui,get,_,click=opened();local hit=get(paths[choice]..'/hit');hit:emit('down',6)
        local nextRun,nextMap=treasure({act=2});ui.run,ui.map=nextRun,nextMap
        unchanged(nextRun,nextMap,function()hit:emit('up',6);return hit:emit('click',6)end)
        assert(not run.keys.sapphire and not nextRun.keys.sapphire);ui:render();assert(click('treasureView/chest'))
        parity(nextRun,nextMap,choice,function()return click(paths[choice],7)end)
    end
    -- Opening also spends source RNG and may run permanent curse hooks. An old
    -- closed chest callback must not open an entirely different current room.
    local run,map=treasure();local ui,_,_,click=setup(run,map)
    local stale=ui.actions['treasureView/chest'].handler
    local nextRun,nextMap=treasure({act=2});ui.run,ui.map=nextRun,nextMap
    unchanged(nextRun,nextMap,stale)
    ui:render();local expected=Copy(nextRun);assert(Nodes.openTreasure(expected))
    assert(click('treasureView/chest'));same(nextRun,expected)
end)

test('generation flow reward link relic and map source changes invalidate both choices',function()
    for _,choice in ipairs({'relic','sapphire'})do
        for _,change in ipairs({'generation','flow','reward','link','relic','map'})do
            local run,map,ui,get=opened();local hit=get(paths[choice]..'/hit');hit:emit('down',8)
            if change=='generation' then run.roomGeneration=run.roomGeneration+1
            elseif change=='flow' then run.nodeFlow=Copy(run.nodeFlow)
            elseif change=='reward' then run.nodeFlow.reward=Copy(run.nodeFlow.reward)
            elseif change=='link' then run.nodeFlow.reward.sapphireKey=Copy(run.nodeFlow.reward.sapphireKey)
            elseif change=='relic' then run.nodeFlow.reward.relicId=run.nodeFlow.reward.relicId=='strawberry' and 'vajra' or 'strawberry'
            else map.sourceSignature='changed' end
            unchanged(run,map,function()hit:emit('up',8);return hit:emit('click',8)end);assert(not run.keys.sapphire)
        end
    end
end)

test('observed invalid eligibility stays retired after repair at every pointer stage',function()
    for _,choice in ipairs({'relic','sapphire'})do
        for _,stage in ipairs({'down','heldUpdate','up','releasedUpdate','enter'})do
            local run,map,ui,get,_,click=opened();local hit=get(paths[choice]..'/hit')
            if stage=='down' then run.endingUnlocked=false end;hit:emit('down',9)
            if stage=='heldUpdate' or stage=='up' or stage=='enter' then run.endingUnlocked=false end
            if stage=='heldUpdate' then ui:update(0.01) elseif stage=='enter' then hit:emit('enter',9) end
            if stage=='up' or stage=='releasedUpdate' then hit:emit('up',9)end
            if stage=='releasedUpdate' then run.endingUnlocked=false;ui:update(0.01)end
            run.endingUnlocked=true
            unchanged(run,map,function()if stage~='up' and stage~='releasedUpdate' then hit:emit('up',9)end;return hit:emit('click',9)end)
            parity(run,map,choice,function()return click(paths[choice],10)end)
        end
    end
end)

test('observed hidden detached disabled and replaced host owners stay retired after repair',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local changes={'hidden','root','busy','parent','host','child'}
        if choice=='relic' then changes[#changes+1]='ancestor';changes[#changes+1]='foreignAncestor'end
        for _,change in ipairs(changes)do
            local run,map,ui,get,_,click,_,root=opened();local hit=get(paths[choice]..'/hit');local host=root.parent
            local box=get(paths[choice]);local parent=box.parent;local chest=get('treasureView');hit:emit('down',11)
            if change=='hidden' then root.visible=false elseif change=='root' then ui.root={}
            elseif change=='busy' then ui.busy=true elseif change=='parent' then root.parent=nil
            elseif change=='host' then host.children.nodePanel=nil
            elseif change=='ancestor' then chest.parent=nil
            elseif change=='foreignAncestor' then
                local foreign={parent=root,visible=true,children={take=box}}
                function foreign:GetChild(name)return self.children[name]end
                root.children.treasureView=foreign
            else parent.children[box.name]=nil end
            ui:update(0.01)
            root.visible=true;ui.root=root;ui.busy=false;root.parent=host;host.children.nodePanel=root;parent.children[box.name]=box
            chest.parent=root;root.children.treasureView=chest
            unchanged(run,map,function()hit:emit('up',11);return hit:emit('click',11)end,choice..' observed '..change..' then repaired')
            parity(run,map,choice,function()return click(paths[choice],12)end)
        end
    end
end)

test('cancel resize hide and chest close retire both armed meanings before recovery',function()
    for _,choice in ipairs({'relic','sapphire'})do
        for _,cancel in ipairs({'exit','endDrag','resize','hide','close'})do
            local run,map,ui,get,_,click=opened();local hit=get(paths[choice]..'/hit');hit:emit('down',13)
            if cancel=='resize' then ui:resize(1600,900) elseif cancel=='hide' then ui:setVisible(false)
            elseif cancel=='close' then ui.opened=false;ui:update(0.01);ui.opened=true else hit:emit(cancel,13)end
            unchanged(run,map,function()hit:emit('up',13);return hit:emit('click',13)end)
            ui:setVisible(true);parity(run,map,choice,function()return click(paths[choice],14)end)
        end
    end
end)

test('native path and final host attachment reads cannot reenter a new paint or detach then commit',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local changes={'render','detach'};if choice=='relic' then changes[#changes+1]='detachAncestor'end
        for _,readAt in ipairs({'path','host'})do for _,change in ipairs(changes)do
            local run,map,ui,get,_,click,_,root=opened();local host=root.parent;local hit=get(paths[choice]..'/hit');local chest=get('treasureView')
            hit:emit('down',15);hit:emit('up',15)
            local owner=readAt=='host' and host or root;local original=owner.GetChild;local once=true
            owner.GetChild=function(o,key)
                local target=readAt=='host' and 'nodePanel' or choice=='sapphire' and 'confirm' or 'treasureView'
                if key==target and once then
                    once=false
                    if change=='render' then ui:render()elseif change=='detachAncestor' then chest.parent=nil else host.children.nodePanel=nil end
                end
                return original(o,key)
            end
            unchanged(run,map,function()return hit:emit('click',15)end,choice..' native '..readAt..' '..change)
            owner.GetChild=original;host.children.nodePanel=root;chest.parent=root
            parity(run,map,choice,function()return click(paths[choice],16)end)
        end end
    end
end)

test('Sapphire Recall and forge footer confirmations never exchange an old gesture meaning',function()
    for _,from in ipairs({'sapphire','recall','forge'})do for _,to in ipairs({'sapphire','recall','forge'})do
        if from~=to then
            local run,map
            if from=='sapphire' then run,map=treasure()else run,map=room('camp')end
            local ui,get,_,click=setup(run,map)
            local function prepare(which)
                if which=='sapphire' then assert(click('treasureView/chest'))
                elseif which=='forge' then assert(click('campView/forge'));assert(click('pickerView/card1'))end
            end
            prepare(from);local hit=get('confirm/hit');hit:emit('down',17)
            local nextRun,nextMap;if to=='sapphire' then nextRun,nextMap=treasure()else nextRun,nextMap=room('camp')end
            ui.run,ui.map=nextRun,nextMap;ui:render();prepare(to)
            unchanged(nextRun,nextMap,function()hit:emit('up',17);return hit:emit('click',17)end)
            if to=='sapphire' then parity(nextRun,nextMap,'sapphire',function()return click('confirm',18)end)
            elseif to=='recall' then
                local expected,expectedMap=Copy(nextRun),Copy(nextMap)
                assert(Nodes.recall(expected,expectedMap,assert(Nodes.recallSource(expected,expectedMap))))
                assert(click('confirm',18));same(nextRun,expected);same(nextMap,expectedMap)
            else legacy(nextRun,nextMap,'upgrade',ui.selected,function()return click('confirm',18)end)end
        end
    end end
end)

test('click-only accessibility still uses canonical source-bound choices',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local run,map,_,_,_,click=opened(nil,true)
        parity(run,map,choice,function()return click(paths[choice])end)
    end
end)

test('core rejection after the last guard remains a full graph-preserving UI refusal',function()
    for _,choice in ipairs({'relic','sapphire'})do
        local run,map,_,get=opened();local command=Nodes.chooseTreasure;local hit=get(paths[choice]..'/hit')
        Nodes.chooseTreasure=function(r,m,token,option)
            local invalid=Copy(token);invalid.relicId='not_the_linked_relic';return command(r,m,invalid,option)
        end
        unchanged(run,map,function()hit:emit('down',19);hit:emit('up',19);return hit:emit('click',19)end)
        Nodes.chooseTreasure=command
    end
end)

print('SAPPHIRE_TREASURE_UI_PASS '..count)
assert(registered==17,'all original Sapphire UI groups must remain registered')
return registered, control
end
