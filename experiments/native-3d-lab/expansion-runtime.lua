local M={}
function M.attach(view,root,api)
    local config=require('abyss_3d_expansion_config')
    local Material=require('abyss_3d_material_sample')
    local panel=assert(root:GetChild('stage'):GetChild('expansionPanel'))
    local self={clock=0,seq=0,shapeIndex=0,material=false,bindings={}}
    local function log(message)
        panel:GetChild('status').text=tostring(message)
        api.log('扩展实验 '..tostring(message))
    end
    local selector=require('abyss_3d_selector').attach(view,root,{config=config.selector,
        send=api.send,register=api.register,log=log})
    local function shape(command)
        if self.pending then log('拼装样例仍等待回执，可用原有停止按钮退出');return false end
        self.needsShapeCleanup=true
        if command=='show'then self.cleanupAttempted=false end
        self.seq=self.seq+1;self.pending={seq=self.seq,deadline=self.clock+10,command=command}
        local sent,reason=pcall(api.send,config.shape.commandSignal,{{type='string',value=command},{type='integer',value=self.seq}})
        if not sent or reason==false then
            self.pending=nil
            local ownsScene=self.shapeOn and api.lab.sceneOnlyEnabled
            self.shapeOn=false
            if ownsScene then api.lab:sceneOnly(false)end
            log('拼装发送失败，已恢复原场景：'..tostring(reason));return false
        end
        log('拼装 '..command..' 请求；整体位移不等于骨骼动作')
        return true
    end
    local unregister=api.register(config.shape.ackSignal,function(params)
        if self.destroyed or not self.pending or params[2]~=self.pending.seq then return end
        local message=tostring(params[1]);log('拼装回执 '..message..'；视觉/负载未实测')
        if message:sub(1,10)~='requested:' then
            self.pending=nil
            if message=='hidden' or message:find('death',1,true)then
                local ownsScene=self.shapeOn and api.lab.sceneOnlyEnabled
                self.shapeOn=false;self.needsShapeCleanup=false
                if ownsScene then api.lab:sceneOnly(false)end
            end
        end
    end)
    local function hideShape()
        if not self.shapeOn and not self.needsShapeCleanup then return end
        self.cleanupAttempted=true
        self.pending=nil;shape('hide');self.shapeOn=false
    end
    local function bind(name,callback)
        local hit=assert(panel:GetChild(name):GetChild('hit'))
        local wrapped=function()
            if self.destroyed then return end
            self.awaitOld=nil;self.auto=nil
            local ok,reason=pcall(callback)
            if not ok then log('单项失败 '..tostring(reason))end
        end
        hit:AddCursorEventListener(Enum.CursorEventType.CursorClick,wrapped)
        self.bindings[#self.bindings+1]={control=hit,callback=wrapped}
    end
    bind('shape',function()
        selector:cancel('shape_test')
        if self.material then Material.toggle(root,false);self.material=false end
        if not self.shapeOn then self.shapeIndex=0;api.lab:sceneOnly(true);self.shapeOn=true end
        local commands=config.shape.commands
        local index=self.shapeIndex%#commands+1
        if shape(commands[index])then self.shapeIndex=index end
    end)
    bind('selector',function()
        hideShape();api.lab:sceneOnly(false)
        self.selectorNative=not self.selectorNative
        local mode=self.selectorNative and 'native' or 'classic'
        local ok,why=selector:start(mode)
        if not ok then log('选牌单项不可用 '..tostring(why))else log(selector:status())end
    end)
    bind('assets',function()
        selector:cancel('material_test');hideShape();api.lab:sceneOnly(false)
        self.material=not self.material;log(Material.toggle(root,self.material))
    end)
    local originalRefresh=view.refresh
    local wrappedRefresh=function(owner,...)
        local results=table.pack(originalRefresh(owner,...))
        if self.material and not self.destroyed then Material.toggle(root,true)end
        return table.unpack(results,1,results.n)
    end
    view.refresh=wrappedRefresh
    local originalStop=api.lab.stop
    local wrappedStop=function(owner,...)
        self.awaitOld=nil;self.auto=nil
        selector:cancel('stop');hideShape()
        if self.material then Material.toggle(root,false);self.material=false end
        return originalStop(owner,...)
    end
    -- sceneOnly internally calls stop; avoid recursion by using its original stop
    -- while opening the separate specimen. Public stop still releases ownership.
    local originalScene=api.lab.sceneOnly
    api.lab.sceneOnly=function(owner,on)
        local saved,inside=owner.stop,self.internalScene;owner.stop=originalStop;self.internalScene=true
        local ok,why=pcall(originalScene,owner,on);owner.stop=saved;self.internalScene=inside
        if not ok then error(why)end
    end
    api.lab.stop=wrappedStop
    local originalAll=api.lab.all
    local wrappedAll=function(owner,...)
        wrappedStop(owner)
        local results=table.pack(originalAll(owner,...))
        self.awaitOld=owner.job
        return table.unpack(results,1,results.n)
    end
    api.lab.all=wrappedAll
    local methodWrappers={}
    for _,name in ipairs({'setMode','modelNext','animations','startBattle','cards','performance','tween','animation','playSample'})do
        local original=api.lab[name]
        if original then
            local wrapped=function(owner,...)
                if self.auto and not self.internalScene then wrappedStop(owner)end
                return original(owner,...)
            end
            methodWrappers[#methodWrappers+1]={name=name,original=original,wrapped=wrapped}
            api.lab[name]=wrapped
        end
    end
    local function expandedStages()
        local stages={}
        for _,command in ipairs(config.shape.commands)do
            stages[#stages+1]={name='拼装 '..command,duration=2,ready=function()return not self.pending end,run=function()
                if command=='show'then api.lab:sceneOnly(true);self.shapeOn=true
                elseif not self.shapeOn and command~='hide'then log('跳过 '..command..'：拼装未显示');return end
                shape(command)
            end}
        end
        stages[#stages+1]={name='正式底板',duration=2,run=function()api.lab:sceneOnly(false);Material.toggle(root,false)end}
        stages[#stages+1]={name='官方底板',duration=3,run=function()self.material=true;log(Material.toggle(root,true))end}
        stages[#stages+1]={name='正式奖励界面',duration=3,run=function()
            Material.toggle(root,false);self.material=false
            local ok,why=selector:start('classic',true);if not ok then log('选牌不可用 '..tostring(why))end
        end}
        stages[#stages+1]={name='原生选牌：等待真实选择，超时不领取',duration=1,
            ready=function()return not selector.pending end,run=function()
                local ok,why=selector:start('native');if not ok then log('选牌不可用 '..tostring(why))end
            end}
        return stages
    end
    local function advanceAuto()
        local auto=self.auto;if not auto then return end
        if auto.current and (self.clock<auto.due or auto.current.ready and not auto.current.ready())then return end
        auto.index=auto.index+1;auto.current=auto.stages[auto.index]
        if not auto.current then self.auto=nil;log('扩展连续测试结束；回执不等于视觉/性能验收');return end
        local entry=auto.current;auto.due=self.clock+entry.duration
        log('连续 '..auto.index..'/'..#auto.stages..' '..entry.name)
        local ok,why=pcall(entry.run)
        if not ok then log('连续单项失败 '..tostring(why))end
    end
    function self:update(dt)
        if self.destroyed then return end
        self.clock=self.clock+dt;selector:update(dt)
        if self.shapeOn and not api.lab.sceneOnlyEnabled then hideShape()end
        if self.needsShapeCleanup and not self.shapeOn and not self.pending and not self.cleanupAttempted then hideShape()end
        if self.pending and self.clock>=self.pending.deadline then
            log('拼装回执超时；未证明引擎执行');self.pending=nil
            local ownsScene=self.shapeOn and api.lab.sceneOnlyEnabled
            self.shapeOn=false
            if ownsScene then api.lab:sceneOnly(false)end
        end
        if self.awaitOld and api.lab.job~=self.awaitOld then
            local finished=self.awaitOld.index>#self.awaitOld.stages
            self.awaitOld=nil
            if finished then
                wrappedStop(api.lab)
                self.auto={stages=expandedStages(),index=0}
            else log('原连续测试已中断，不续接扩展样例')end
        end
        advanceAuto()
        panel:SetAsLastSibling()
    end
    function self:destroy()
        if self.destroyed then return end
        self.awaitOld=nil;self.auto=nil
        selector:destroy();hideShape();Material.destroy(root)
        self.destroyed=true
        if view.refresh==wrappedRefresh then view.refresh=originalRefresh end
        if api.lab.stop==wrappedStop then api.lab.stop=originalStop end
        if api.lab.all==wrappedAll then api.lab.all=originalAll end
        for _,method in ipairs(methodWrappers)do
            if api.lab[method.name]==method.wrapped then api.lab[method.name]=method.original end
        end
        api.lab.sceneOnly=originalScene
        if type(unregister)=='function'then pcall(unregister)end
        for _,b in ipairs(self.bindings)do pcall(b.control.RemoveCursorEventListener,b.control,Enum.CursorEventType.CursorClick,b.callback)end
    end
    log('全部连续测试自动续接拼装/底板/选牌；也可单测；命中另演示闪光7，视觉未验收')
    return self
end
return M
