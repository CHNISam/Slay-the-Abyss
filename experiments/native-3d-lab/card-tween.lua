-- One real hand card, x only. The experiment owns no game state or hitbox math.
local M={}
local owners=setmetatable({},{__mode='k'})
local boxOwners=setmetatable({},{__mode='k'})
local function resolve(view)return view and (view.battleUI or view)end
local function clock()return os and os.clock and os.clock() or 0 end
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function stats(samples)
    if #samples==0 then return 0,0 end
    local values,total={},0
    for i,v in ipairs(samples)do values[i]=v;total=total+v end
    table.sort(values)
    return total/#samples*1000,values[math.max(1,math.ceil(#values*.95))]*1000
end
local function targetCopy(entry)
    local t=entry.target
    return {x=t.x,y=t.y,scale=t.scale,angle=t.angle,restAngle=t.restAngle,baseY=t.baseY}
end
local function sameTarget(entry,target)
    if not entry.target then return false end
    for key,value in pairs(target)do if entry.target[key]~=value then return false end end
    return true
end
local function invalidContext(self,active,held)
    local view,entry=self.view,active.entry
    if view.active==false or entry.box.alive==false or (view.root and view.root.alive==false)then return 'destroy_or_disable' end
    if view.canvasWidth~=active.width or view.canvasHeight~=active.height or view.run~=active.run
        or not view.run or view.run.combat~=active.battle or view.run.phase~=active.phase then return 'battle_or_resize' end
    if held or view.gesture or view.carry then return 'drag' end
    if not sameTarget(entry,active.target)then return 'new_target' end
end
local function currentX(active)
    active.reads=active.reads+1
    local ok,x=pcall(function()return active.entry.box.anchoredPositionX end)
    if ok and finite(x)then active.entry.current.x=x;return true end
    return false
end
local function finish(self,reason,complete)
    local active=self.active;if not active then return end
    if complete then
        local invalid=invalidContext(self,active)
        if invalid then reason,complete=invalid,false end
    end
    if not complete then active.valid=false end
    if complete and active.mode=='tween' then
        active.entry.current.x=active.target.x
        local ok=pcall(self.provider.paint,active.entry)
        if not ok then reason='error:completion_paint';active.valid=false;complete=false end
    end
    self.active=nil;boxOwners[active.entry.box]=nil
    if active.tween and not complete then
        active.setupCalls=active.setupCalls+1
        local ok=pcall(active.tween.Kill,active.tween,false)
        if not ok then reason='error:Kill';active.valid=false end
        currentX(active)
    end
    if complete then active.entry.current.x=active.target.x end
    local mean,p95=stats(active.samples)
    active.meanUpdateMs,active.p95UpdateMs=mean,p95
    active.reason,active.completed=reason,complete==true
    self.last=active
    if complete and active.valid then self.results[active.mode]=active end
end
function M.recordPaint(box)
    local owner=boxOwners[box]
    if owner and owner.active then owner.active.setterWrites=owner.active.setterWrites+7 end
end
function M.attach(view,provider)
    local previous=owners[view];if previous then previous:cancel('rebind')end
    local self={view=view,provider=provider,results={}}
    function self:cancel(reason)finish(self,reason or 'stop',false)end
    function self:removed(entry)if self.active and self.active.entry==entry then self:cancel('removed')end end
    function self:holdRender(entry,box,count,index,hot)
        local a=self.active;if not a or a.entry~=entry then return false end
        local invalid=invalidContext(self,a)
        if invalid then self:cancel(invalid);return false end
        local layout=entry.labLayout or {}
        if box~=entry.box or layout.count~=count or layout.index~=index or layout.hot~=hot or not sameTarget(entry,a.target)then self:cancel('new_target');return false end
        if a.mode=='tween' and not currentX(a)then self:cancel('error:position_read');return false end
        return true
    end
    function self:before(entry,dt,held)
        local a=self.active;if not a or a.entry~=entry then return false end
        a.driveStart=clock()
        local invalid=invalidContext(self,a,held)
        if invalid then self:cancel(invalid);return false end
        a.frames=a.frames+1;a.seconds=a.seconds+dt;a.samples[#a.samples+1]=dt
        if a.mode=='tween' then
            if not currentX(a)then self:cancel('error:position_read');return false end
            if a.seconds>1.5 then self:cancel('error:Tween_timeout');return false end
            return true
        end
        return false
    end
    function self:after(entry)
        local a=self.active;if not a or a.entry~=entry then return end
        a.driveCpuMs=a.driveCpuMs+(clock()-(a.driveStart or clock()))*1000
        if a.mode=='manual' and math.abs(entry.current.x-a.target.x)<.001 then finish(self,'completed:manual',true)end
    end
    owners[view]=self
    return self
end
function M.start(view,mode)
    local owner=owners[resolve(view)]
    if not owner then return false,'不可用：真实手牌视图尚未建立' end
    owner:cancel('restart')
    if mode~='manual' and mode~='tween' then return false,'未知Tween对比模式' end
    local v=owner.view
    if not v.run or not v.run.combat or v.gesture or v.carry or v.busy or v.active==false then return false,'请等待玩家回合，停止拖牌后重试' end
    if mode=='tween' and (not game or type(game.Tween)~='function')then return false,'不可用：客户端缺少官方game.Tween' end
    local selected
    for _,entry in pairs(owner.provider.entries())do
        if entry.visible and entry.box and entry.box.alive~=false and entry.target and entry.labLayout then
            local settled=true
            for _,key in ipairs({'x','y','scale','angle'})do if math.abs(entry.current[key]-entry.target[key])>.001 then settled=false end end
            if settled and (not selected or tostring(entry.labUid)<tostring(selected.labUid))then selected=entry end
        end
    end
    if not selected then return false,'请先进入战斗并等待真实手牌归位' end
    if owner.last and (owner.last.battle~=v.run.combat or owner.last.entry.labUid~=selected.labUid)then owner.results={}end
    local active={entry=selected,mode=mode,target=targetCopy(selected),run=v.run,battle=v.run.combat,phase=v.run.phase,width=v.canvasWidth,height=v.canvasHeight,
        setterWrites=0,setupCalls=0,reads=0,driveCpuMs=0,frames=0,seconds=0,samples={},valid=true}
    owner.active=active;boxOwners[selected.box]=owner
    selected.current.x=selected.target.x+72
    local ok,why=pcall(owner.provider.paint,selected)
    if not ok then active.valid=false;finish(owner,'error:initial_paint',false);return false,tostring(why)end
    if mode=='tween' then
        local created,err=pcall(function()
            active.setupCalls=active.setupCalls+1
            active.tween=game.Tween(selected.box,{anchoredPositionX=selected.target.x},.24)
            assert(active.tween and type(active.tween.Kill)=='function','Tween.Kill缺失')
            active.setupCalls=active.setupCalls+1
            active.tween:SetOnComplete(function()
                if owner.active==active then finish(owner,'completed:tween',true)end
            end)
            active.setupCalls=active.setupCalls+1;active.tween:Play()
        end)
        if not created then active.valid=false;finish(owner,'error:Tween_create',false);return false,'官方Tween不可用：'..tostring(err)end
    end
    return true
end
function M.cancel(view,reason)local owner=owners[resolve(view)];if owner then owner:cancel(reason)end end
function M.result(view)
    local owner,result=owners[resolve(view)],{}
    local a=owner and (owner.active or owner.last);if not a then return nil end
    for _,key in ipairs({'mode','setterWrites','setupCalls','reads','driveCpuMs','frames','seconds','valid','reason','completed','meanUpdateMs','p95UpdateMs'})do result[key]=a[key]end
    result.bridgeCalls=a.setterWrites+a.setupCalls+a.reads
    result.cardUid=a.entry.labUid
    result.sample='真实手牌横向+72归位；A保留原指数插值，B官方Tween0.24秒；时长曲线不同'
    result.boundary='OnUpdate回调间隔/本实验Lua驱动耗时；非GPU帧时间或原生引擎成本'
    result.comparisons={}
    for mode,value in pairs(owner.results)do
        result.comparisons[mode]={bridgeCalls=value.setterWrites+value.setupCalls+value.reads,
            frames=value.frames,seconds=value.seconds,meanUpdateMs=value.meanUpdateMs,p95UpdateMs=value.p95UpdateMs,driveCpuMs=value.driveCpuMs}
    end
    return result
end
function M.status(view)
    local r=M.result(view);if not r then return 'Tween对比：等待真实手牌；A原逐帧 / B官方0.24s' end
    local owner=owners[resolve(view)];local a=owner.active or owner.last
    local mean,p95=stats(a.samples)
    local aResult,bResult=r.comparisons.manual,r.comparisons.tween
    local comparison=aResult and bResult and string.format('；完成样本A%d/B%d次桥调用',aResult.bridgeCalls,bResult.bridgeCalls) or ''
    return string.format('%s %s | Lua桥调用%d（写%d/读%d/控制%d）%s\nOnUpdate均值%.2f / P95 %.2f ms；Lua驱动%.3f ms\nA原曲线/B0.24s；非GPU数据，流畅度待实机',r.mode=='manual' and 'A原逐帧' or 'B官方Tween',r.reason or '运行中',r.bridgeCalls,r.setterWrites,r.reads,r.setupCalls,comparison,mean,p95,r.driveCpuMs)
end
return M
