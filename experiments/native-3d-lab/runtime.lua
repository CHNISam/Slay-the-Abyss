-- Experimental presentation adapter. Core rules and committed events are read-only.
local M={}
local function finite(x)return type(x)=='number' and x==x and x<math.huge and x>-math.huge end
function M.statistics(samples)
    if #samples==0 then return nil end
    local copy,total={},0
    for _,dt in ipairs(samples)do copy[#copy+1]=dt;total=total+dt end
    table.sort(copy)
    local mean=total/#copy
    return {count=#copy,seconds=total,meanMs=mean*1000,fps=1/mean,
        p95Ms=copy[math.max(1,math.ceil(#copy*.95))]*1000,p99Ms=copy[math.max(1,math.ceil(#copy*.99))]*1000}
end
local function child(parent,name)
    if not parent then return nil end
    local ok,value=pcall(parent.GetChild,parent,name)
    return ok and value or nil
end
local function visible(control,value)if control then control:SetVisible(value)end end
local function text(control,value)if control then control.text=value end end
local function actorIndex(battle,id)
    if id=='player' then return 0 end
    for i,a in ipairs(battle.enemies)do if a.id==id then return i end end
end
function M.trace(run)
    local s=run.combat;if not s then return run.phase end
    local out={run.phase,s.phase,tostring(s.turn),tostring(s.energy),tostring(s.player.hp),tostring(s.player.block)}
    for _,a in ipairs(s.enemies)do out[#out+1]=a.id..':'..a.hp..':'..a.block end
    for _,pile in ipairs({'hand','draw','discard','exhaust'})do
        local cards={};for _,card in ipairs(s[pile])do cards[#cards+1]=card.cardId..':'..card.uid end
        out[#out+1]=pile..'='..table.concat(cards,',')
    end
    return table.concat(out,'|')
end
function M.attach(view,root,api)
    api=api or {}
    local Config=api.config or require('abyss_3d_lab_config')
    local Run=api.Run or require('abyss_run')
    local Combat=api.Combat or require('abyss_combat')
    local Map=api.Map or require('abyss_map')
    local data=api.data or require('abyss_data')
    local stage=assert(child(root,'stage'),'lab stage missing')
    local panel=assert(child(stage,'labPanel'),'lab panel missing')
    local menu,diagnostics=child(panel,'menu'),child(panel,'diagnostics')
    local cardSamples=child(panel,'cardSamples')
    local self={clock=0,seq=0,model=1,mode='2D',wanted='2D',logs={},queue={},samples={},
        traces={},results={},bindings={},sampleBindings={},cardMode=0,frameCount=0,frameSeconds=0,liveFps=0}
    local restoreControls={}
    local tweenModule=api.tween
    local function log(message)
        message=tostring(message):gsub('[\r\n]+',' ')
        -- Cut at a UTF-8 boundary; byte slicing can produce invalid native text.
        local cutoff=utf8.offset(message,109)
        if cutoff then message=message:sub(1,cutoff-1)..'…' end
        self.logs[#self.logs+1]=string.format('%05.1f ',self.clock)..message
        if #self.logs>12 then table.remove(self.logs,1)end
        text(child(diagnostics,'log'),table.concat(self.logs,'\n'))
        if api.log then api.log(message)else print('ABYSS_3D_LAB '..message)end
    end
    local function status(message)self.status=message;text(child(diagnostics,'status'),message)end
    local function safe(label,fn,...)
        local ok,value,why=pcall(fn,...)
        if not ok then status(label..'失败；其他实验可继续');log('ERROR '..label..': '..tostring(value));return false,value end
        return true,value,why
    end
    local function cancelTween(reason)
        self.tweenWatching=false
        if tweenModule and type(tweenModule.cancel)=='function'then
            local ok,why=pcall(tweenModule.cancel,view,reason)
            if not ok then log('ERROR Tween取消：'..tostring(why))end
        end
    end
    local function restore()
        for control,was in pairs(restoreControls)do
            if control.alive~=false then pcall(control.SetVisible,control,was)end
        end
        restoreControls={}
        if view.refresh then view:refresh()end
    end
    local function conceal(control)
        if not control then return end
        if restoreControls[control]==nil then restoreControls[control]=control.activeInHierarchy~=false end
        control:SetVisible(false)
    end
    local function masks()
        if self.mode~='3D' then return end
        conceal(child(root,'canvasBackdrop'));conceal(child(root,'backdrop'))
        conceal(child(stage,'officialBattleBackdrop'))
        local battle=child(stage,'battlePanel')
        for _,name in ipairs({'backdrop','battleBackground','officialBackground','lowpolyScene','vista','sceneArt'})do conceal(child(battle,name))end
        -- Preserve all names/HP/intent/target cursor surfaces. Only artwork is hidden.
        local hero=child(battle,'hero')
        for _,name in ipairs({'portrait','officialFigure','battlePose','monsterArt','border','plate','shadow','glow'})do conceal(child(hero,name))end
        local ok,surfaces=pcall(function()return require('abyss_monster_surfaces').get(battle)end)
        if ok and surfaces then
            for _,record in pairs(surfaces.records)do
                for _,name in ipairs({'portrait','monsterArt','artSamples','border','plate','shadow','glow'})do conceal(child(record.box,name))end
            end
        end
    end
    local function updateMode()
        local model=Config.models and Config.models[self.model]
        text(child(menu,'mode'),'当前：'..self.mode..' · '..(model and model.name or '未装配模型'))
    end
    local function clearNative()
        self.queue={};self.pending=nil
    end
    local function invalidateSample(reason)
        local sample=self.sampleSession
        if not sample or sample.finished then return end
        if sample.valid then log('UNVERIFIED '..sample.label..' 样本作废：'..reason)end
        sample.valid=false;sample.failureReason=sample.failureReason or reason
        self.sampleActive=false;self.pairValid=false
        local entry=self.job and self.job.current
        if entry and entry.sample then entry.failed=true end
    end
    local function issue(command,actor,kind)
        if not Config.nativeAvailable then log('UNAVAILABLE '..(Config.reason or '本候选未装配原生桥'));return false end
        if type(api.send)~='function' then log('UNAVAILABLE 原生信号发送接口');return false end
        self.seq=self.seq+1
        self.pending={command=command,seq=self.seq,deadline=self.clock+14,kind=kind or 'action'}
        local ok,result=pcall(api.send,command,self.model,actor or 1,self.seq)
        if not ok or result==false then
            invalidateSample('原生信号发送失败')
            self.pending=nil;status('信号发送失败，菜单仍可使用');log('ERROR send '..tostring(result));return false
        end
        log('请求 #'..self.seq..' '..command..'（等待服务端回执）')
        return true
    end
    local function enqueue(command,actor)
        if actor==0 then
            if not self.heroWarned then self.heroWarned=true;log('UNAVAILABLE 玩家攻击clip；卡牌结算与其他演出继续')end
            return false
        end
        if actor and actor>(Config.maxActors or 3) then
            if not self.multiWarned then self.multiWarned=true;log('UNAVAILABLE 超过本实验原生敌人槽上限')end
            return false
        end
        if #self.queue>=32 then log('ERROR 原生演出队列已满，跳过额外演出');return false end
        self.queue[#self.queue+1]={command=command,actor=actor or 1}
        return true
    end
    function self:ack(message,sequence)
        if self.destroyed or not self.pending or sequence~=self.pending.seq then return false end
        message=tostring(message);log('回执 #'..sequence..' '..message)
        local pending=self.pending
        local done=message=='ready' or message=='hidden' or message:sub(1,10)=='completed:'
            or message:sub(1,12)=='unsupported:' or message:sub(1,6)=='error:'
            or message:sub(1,14)=='missing_actor:' or message:sub(1,5)=='busy:'
        if not done then return true end
        self.pending=nil
        if message=='ready' and pending.kind=='show' then
            self.mode='3D';self.readyMode='3D';masks();updateMode();status('3D 已就绪；回执可见，视觉效果待本机观察')
            local battle=view.run and view.run.combat
            for i=2,math.min(battle and #battle.enemies or 0,Config.maxActors or 3)do enqueue('show',i)end
        elseif message=='hidden' then self.readyMode='2D';status('2D；原生展示实体已移除/禁用回执')
        elseif message:sub(1,12)=='unsupported:' then invalidateSample('原生动作不可用：'..message:sub(13));status('部分能力不可用：'..message:sub(13))
        elseif message:sub(1,6)=='error:' then invalidateSample('原生单项失败：'..message:sub(7));status('原生单项失败：'..message:sub(7))
        elseif message:sub(1,14)=='missing_actor:' then
            invalidateSample('原生展示实体不存在');self.queue={};self.readyMode=nil
            status('原生实体不存在；点怪物展示或完整战斗重建')
        elseif message:sub(1,5)=='busy:' then
            invalidateSample('原生仍忙，本条动作未播放');self.queue={}
            status('原生仍在初始化/播放；本条已跳过，稍后可重试')
        end
        return true
    end
    function self:setMode(mode)
        assert(mode=='2D' or mode=='3D','invalid lab mode')
        invalidateSample('采样期间切换/重建表现模式')
        clearNative();self.wanted=mode;self.readyMode=nil
        if mode=='2D' then
            self.mode='2D';restore();updateMode();issue('hide',0,'hide')
            if not Config.nativeAvailable then self.readyMode='2D'end
            status('2D · 原生模型退场；规则和卡牌保持相同')
        elseif Config.nativeAvailable then
            self.mode='2D';restore();updateMode();status('原生模型初始化，等待 ready（约 4.5 秒）')
            if not issue('show',1,'show')then self.wanted='2D'end
        else
            self.wanted='2D'
            status('3D 不可用：'..(Config.reason or '未装配'));log('UNAVAILABLE '..(Config.reason or '原生桥未装配'))
            return false
        end
        return true
    end
    function self:startBattle()
        invalidateSample('采样期间重置战斗')
        cancelTween('battle_reset')
        if view.battleUI.feedback and view.battleUI.feedback.cancel then view.battleUI.feedback:cancel()end
        local run=Run.new(data,42)
        assert(Run.startCombat(run,'cultist_solo'))
        local map=Map.generate(data,42)
        view.run,view.map,view.prologueSeen=run,map,true
        view.battleUI.run=run;view.mapUI.map=map;view.nodeUI.run,view.nodeUI.map=run,map
        view.characterOpen,view.exitOpen,view.easterEggOpen=false,false,false
        view.battleUI.selected,view.battleUI.target=nil,1
        self.trace={M.trace(run)};self.automatedActions=0;self.actionClock=0;self.heroWarned=nil
        view:refresh();masks()
        log('战斗重置 seed=42 / cultist_solo；沿用正式初始牌组')
        return run
    end
    local function automate()
        local ui,run=view.battleUI,view.run
        if not run or run.phase~='combat' or ui.busy or ui.gesture then return false end
        local battle=run.combat
        if battle.pendingChoice then log('自动战斗暂停：当前牌需要手动选择');return false end
        for _,instance in ipairs(battle.hand)do
            for target=1,math.max(1,#battle.enemies)do
                if Combat.canPlay(battle,instance.uid,target)then
                    ui.selected=instance.uid;ui:playSelected(target)
                    self.trace[#self.trace+1]=M.trace(run);self.automatedActions=self.automatedActions+1
                    return true
                end
            end
        end
        ui:endTurn();self.trace[#self.trace+1]=M.trace(run);self.automatedActions=self.automatedActions+1
        return true
    end
    local function stop(reason)
        invalidateSample(reason or '采样被停止')
        cancelTween('stop')
        self.job=nil;self.sampleActive=false;clearNative();self.cardMode=0;visible(cardSamples,false)
        if view.battleUI.feedback and view.battleUI.feedback.cancel then view.battleUI.feedback:cancel()end
        self:setMode('2D');status(reason or '已停止，回到 2D；手动实验仍可使用');log(reason or 'STOP')
    end
    function self:stop()stop('已停止自动测试；恢复 2D')end
    local function endSample(label)
        self.sampleActive=false
        local session=self.sampleSession
        local valid=session and session.label==label and session.valid==true
        local reason=session and session.failureReason
        if self.mode~=label or self.wanted~=label or self.readyMode~=label then valid=false;reason=reason or '采样模式或初始化回执失效'end
        if self.automatedActions~=8 then valid=false;reason=reason or '未完成固定八条命令'end
        if self.pending or #self.queue>0 or view.battleUI.busy then valid=false;reason=reason or '演出或回执未完成'end
        local metrics=valid and M.statistics(self.samples) or nil
        if not metrics then valid=false;reason=reason or '没有有效帧间隔样本'end
        local result={label=label,valid=valid==true,failureReason=reason,metrics=metrics,
            mode=self.mode,readyMode=self.readyMode,trace=table.concat(self.trace or {},'\n'),actions=self.automatedActions or 0}
        if session then session.finished=true end
        self.results[label]=result
        if metrics then
            log(string.format('%s OnUpdate %.1fFPS / %.1fms p95 %.1f p99 %.1f n=%d',label,metrics.fps,metrics.meanMs,metrics.p95Ms,metrics.p99Ms,metrics.count))
        else log('UNVERIFIED '..label..'：'..tostring(reason))end
        return result
    end
    local function stageJob(stages,kind)
        stop('准备 '..kind);self.job={stages=stages,index=0,kind=kind,elapsed=0};self.results={};self.comparison=nil;self.pairValid=false
        log(kind..' 开始；手机/GPU/内存仍待设备证据')
    end
    local function performanceStages()
        local stages={}
        for _,mode in ipairs({'2D','3D'})do
            stages[#stages+1]={name=mode..' 初始化与预热',duration=2,run=function()self:startBattle();self:setMode(mode)end,ready=mode}
            stages[#stages+1]={name=mode..' 同种子自动采样',duration=12,maxDuration=45,targetActions=8,sample=mode,automate=true,
                run=function()
                    self.samples={};self.sampleActive=false;self.actionClock=0
                    self.automatedActions=0
                    self.sampleSession={label=mode,valid=false,failureReason='未收到初始化完成回执'}
                    if self.readyMode~=mode then error(mode..' 未收到初始化完成回执；不记录伪对比')end
                    self.sampleSession.valid=true;self.sampleSession.failureReason=nil
                    self.sampleActive=true
                end,
                finish=function()endSample(mode)end}
        end
        stages[#stages+1]={name='性能配对结果',duration=1,run=function()
            local a,b=self.results['2D'],self.results['3D']
            local valid=a and b and a.valid==true and b.valid==true and a.metrics and b.metrics
                and a.actions==8 and b.actions==8 and a.mode=='2D' and a.readyMode=='2D'
                and b.mode=='3D' and b.readyMode=='3D' and a.trace==b.trace
            self.pairValid=valid==true
            if valid then
                local function line(result)
                    local m=result.metrics
                    return string.format('%s %.1fFPS mean %.1fms\np95 %.1fms p99 %.1fms',result.label,m.fps,m.meanMs,m.p95Ms,m.p99Ms)
                end
                self.comparison=line(a)..'\n'..line(b)..'\nGPU/内存/官方负载：无接口\n手机未验证；仅 OnUpdate 间隔'
                text(child(diagnostics,'metrics'),self.comparison)
            end
            if valid then
                log('PASS 核心状态轨迹相同，动作数 '..a.actions..'；仅比较脚本帧间隔')
                status('2D/3D 核心轨迹一致；GPU/内存/手机未验证')
            else
                self.comparison='本次性能配对无效\n2D：'..tostring(a and (a.valid and '有效' or a.failureReason) or '缺少采样')..'\n3D：'..tostring(b and (b.valid and '有效' or b.failureReason) or '缺少采样')
                log('UNVERIFIED 样本失效/轨迹不同/命令不完整，本次性能不能公平比较');status('性能配对无效，查看屏内原因')
            end
        end}
        return stages
    end
    function self:performance()stageJob(performanceStages(),'性能配对测试')end
    function self:animation(command)
        if command=='death'then log('死亡clip不可直接调用；本项测试原生销毁表现')end
        if command=='hit' and Config.models and Config.models[self.model] and Config.models[self.model].hit==false then
            log('UNAVAILABLE 当前模型未找到官方受击clip');status('当前模型无受击clip；可切换遗迹守卫');return false
        end
        if self.wanted~='3D'then self:setMode('3D')end
        if self.wanted~='3D'then return false end
        return enqueue(command,1)
    end
    function self:animations()
        self.job=nil
        if not self:setMode('3D')then return false end
        for _,command in ipairs({'idle','attack','hit','death'})do self:animation(command)end
        status('动画队列：待机 → 攻击 → 受击 → 原生销毁；等待回执')
    end
    function self:modelNext()
        self.model=self.model%math.max(1,#(Config.models or {}))+1
        updateMode();self:setMode('3D')
    end
    local function paintCardSamples()
        local ui=view.battleUI;local run=view.run;local battle=run and run.phase=='combat' and run.combat
        local battlePanel=child(stage,'battlePanel')
        self.sampleBindings={}
        for i=1,3 do
            local box=child(cardSamples,'sample'..i);local card=battle and battle.hand[i]
            local def=card and battle.catalog.cards[card.cardId]
            local source=child(battlePanel,'card'..i)
            local live=def and not ui.busy
            local hit=child(box,'hit');if hit then hit.raycastTarget=live==true end
            if live then
                for _,key in ipairs({'name','type','label','cost'})do
                    local formal=child(source,key)
                    local value=formal and formal.text or (key=='name' and def.name or key=='cost' and tostring(def.cost) or key=='type' and (def.type or '') or '效果请查看正式卡牌')
                    local target=child(box,key)
                    if target and target.text~=value then target.text=value end
                end
                text(child(box,'note'),'点击出牌 · 目标1')
                self.sampleBindings[i]={uid=card.uid,battle=battle}
            elseif not def then
                text(child(box,'name'),'暂无手牌');text(child(box,'type'),'');text(child(box,'label'),'')
                text(child(box,'cost'),'');text(child(box,'note'),'')
            else text(child(box,'note'),'效果结算中')end
        end
    end
    function self:playSample(index)
        local binding=self.sampleBindings[index];local ui=view.battleUI
        local run=view.run;local battle=run and run.phase=='combat' and run.combat
        if self.cardMode~=1 or ui.busy or not binding or binding.battle~=battle then return false end
        local card=battle.hand[index]
        if not card or card.uid~=binding.uid or not Combat.canPlay(battle,card.uid,1)then return false end
        ui.selected=card.uid;ui:playSelected(1)
        paintCardSamples()
        return true
    end
    function self:cards()
        self.cardMode=(self.cardMode+1)%3
        visible(cardSamples,self.cardMode==1)
        if self.cardMode==0 then status('卡牌 A：正式卡牌、点选/拖拽与现有动画')
        elseif self.cardMode==1 then
            status('卡牌 B：正式完整文本，分组变换；点击样张按原规则出牌')
            text(child(cardSamples,'sampleTitle'),'同一手牌完整文本 · 分组变换 · 点击出牌')
            paintCardSamples()
            log('卡牌B为动效候选；完整效果与类型沿用正式显示，未证实性能优胜')
        else status('卡牌 C：UNAVAILABLE 真3D卡牌缺少成熟资产/文本/命中映射');log('UNAVAILABLE 3D卡牌：需要额外资产、世界空间文字与输入映射，当前无更简单方案')end
    end
    function self:tween(mode)
        mode=mode or self.tweenNext or 'manual'
        self.tweenNext=mode=='manual' and 'tween' or 'manual'
        if not tweenModule then
            local ok,value=pcall(require,'abyss_3d_card_tween')
            if not ok then status('Tween 对比不可用：候选模块缺失');log('UNAVAILABLE Tween：'..tostring(value));return false end
            tweenModule=value
        end
        local called,ok,reason=pcall(tweenModule.start,view,mode)
        if not called or not ok then
            self.tweenWatching=false
            status('Tween '..(mode=='manual' and 'A手动' or 'B原生')..'不可用：'..tostring(called and reason or ok))
            log('UNAVAILABLE '..self.status)
            return false
        end
        self.tweenWatching=true;self.lastTweenStatus=nil
        status('Tween '..(mode=='manual' and 'A：现有手动驱动' or 'B：原生Tween')..'，观察当前真实手牌')
        log(self.status..'；规则/命中仍由正式卡牌负责')
        return true
    end
    function self:all()
        local stages={
            {name='2D 基线',duration=5,run=function()self:startBattle();self:setMode('2D')end},
            {name='3D 场景',duration=8,run=function()self:setMode('3D')end},
        }
        for i=1,#(Config.models or {})do
            stages[#stages+1]={name='怪物 '..i,duration=7,run=function()self.model=i;self:setMode('3D')end}
        end
        stages[#stages+1]={name='四种动画',duration=25,run=function()self.model=1;self:animations()end}
        stages[#stages+1]={name='真实卡牌自动战斗',duration=22,automate=true,run=function()self:startBattle();self:setMode('3D')end}
        stages[#stages+1]={name='卡牌A',duration=4,run=function()self.cardMode=2;self:cards()end}
        stages[#stages+1]={name='卡牌B',duration=5,run=function()self:cards()end}
        stages[#stages+1]={name='卡牌C',duration=4,run=function()self:cards()end}
        stages[#stages+1]={name='Tween A手动',duration=4,run=function()self:tween('manual')end}
        stages[#stages+1]={name='Tween B原生',duration=4,run=function()self:tween('tween')end}
        for _,entry in ipairs(performanceStages())do stages[#stages+1]=entry end
        stageJob(stages,'全部连续测试')
    end
    local function observe(before,battle,first)
        if self.wanted~='3D'then return end
        local death={}
        for i=first,#battle.events do
            local entry=battle.events[i];local d=entry.detail or {}
            if entry.kind=='intent'then enqueue('attack',actorIndex(battle,d.enemy))
            elseif entry.kind=='play'then enqueue('attack',0)
            elseif entry.kind=='damage' or entry.kind=='hp_loss' or entry.kind=='status_damage'then
                local index=actorIndex(battle,d.target)
                if index and (d.amount or 0)>0 then enqueue('hit',index)end
            end
        end
        for i,a in ipairs(battle.enemies)do
            local old=before.enemies[i]
            if old and old.hp>0 and a.hp<=0 and not death[a.id]then death[a.id]=true;enqueue('death',i)end
        end
    end
    local feedback=view.battleUI.feedback
    local originalStart=feedback and feedback.start
    if originalStart then
        self.feedbackWrapper=function(owner,before,battle,first,...)
            safe('原生表现观察',observe,before,battle,first)
            return originalStart(owner,before,battle,first,...)
        end
        feedback.start=self.feedbackWrapper
    end
    local function bind(parent,name,fn)
        local control=child(parent,name);local hit=child(control,'hit')or control
        if not hit then return end
        local callback=function()if not self.destroyed then safe(name,fn)end end
        hit:AddCursorEventListener(api.clickEvent or Enum.CursorEventType.CursorClick,callback)
        self.bindings[#self.bindings+1]={control=hit,callback=callback}
    end
    bind(panel,'fold',function()
        self.folded=not self.folded;visible(menu,not self.folded)
        text(child(child(panel,'fold'),'label'),self.folded and '3D 实验室 · 展开' or '3D 实验室 · 收起')
    end)
    bind(menu,'compare',function()self.job=nil;self:setMode(self.wanted=='3D' and '2D' or '3D')end)
    bind(menu,'model',function()self.job=nil;self:modelNext()end)
    bind(menu,'animations',function()self:animations()end)
    bind(menu,'combat',function()self.job=nil;self:startBattle();self:setMode('3D')end)
    bind(menu,'cards',function()self.job=nil;self:cards()end)
    bind(menu,'performance',function()self:performance()end)
    bind(menu,'all',function()self:all()end)
    bind(menu,'stop',function()self:stop()end)
    bind(menu,'reset',function()self:stop();self:startBattle()end)
    bind(menu,'logs',function()self.logsHidden=not self.logsHidden;visible(diagnostics,not self.logsHidden)end)
    bind(menu,'tween',function()self:stop();self:tween()end)
    for _,command in ipairs({'idle','attack','hit','death'})do bind(menu,command,function()self.job=nil;self:animation(command)end)end
    for i=1,3 do bind(cardSamples,'sample'..i,function()self:playSample(i)end)end
    if api.register then
        local ok,unregister=pcall(api.register,function(message,sequence)self:ack(message,sequence)end)
        if ok then self.unregister=unregister else log('ERROR 回执订阅 '..tostring(unregister))end
    end
    local function nextStage(job)
        local previous=job.stages[job.index]
        if previous and previous.finish then safe(previous.name..'结果',previous.finish)end
        job.index=job.index+1;job.elapsed=0;job.waitElapsed=0
        local entry=job.stages[job.index]
        if not entry then self.job=nil;self.sampleActive=false;log(job.kind..'结束；可继续单项测试');return end
        job.current=entry;status(string.format('%s %d/%d：%s',job.kind,job.index,#job.stages,entry.name));log(entry.name)
        if entry.run then
            local savedJob=self.job
            local ok=safe(entry.name,entry.run)
            if not ok then self.sampleActive=false;entry.failed=true end
            -- Animation queue uses no job internally; preserve the outer all-tests owner.
            if not self.destroyed then self.job=savedJob end
        end
    end
    function self:update(dt)
        if self.destroyed or not finite(dt) or dt<0 then return end
        self.clock=self.clock+dt
        if dt>0 then
            self.frameCount=self.frameCount+1;self.frameSeconds=self.frameSeconds+dt
            if self.sampleActive and #self.samples<6000 then self.samples[#self.samples+1]=dt end
        end
        if self.pending and self.clock>=self.pending.deadline then
            log('TIMEOUT #'..self.pending.seq..' '..self.pending.command..'；未证明原生执行')
            invalidateSample('原生动作回执超时：'..self.pending.command)
            self.pending=nil;self.queue={};self.sampleActive=false;self.readyMode=nil
            if self.wanted=='3D'then self.mode='2D';self.wanted='2D';restore();updateMode()end
            status('原生回执超时；2D 与其他测试仍可用')
        end
        if not self.pending and self.mode=='3D' and #self.queue>0 then
            local entry=table.remove(self.queue,1);issue(entry.command,entry.actor)
        end
        local job=self.job
        if job then
            if not job.current then nextStage(job)
            else
                local entry=job.current
                local setupReady=not entry.ready or self.readyMode==entry.ready
                local setupFailed=false
                if not setupReady then
                    job.waitElapsed=job.waitElapsed+dt
                    if not self.pending or job.waitElapsed>=15 then
                        log(entry.name..'失败：未得到匹配的完成回执；继续其余实验')
                        setupFailed=true
                    end
                else
                    if entry.ready and not entry.setupLogged then
                        entry.setupLogged=true
                        log(entry.ready..' 初始化回执等待 '..string.format('%.1fs',job.waitElapsed)..'（非文件加载计时）')
                    end
                    job.elapsed=job.elapsed+dt
                end
                if entry.automate and not entry.failed and (not entry.targetActions or self.automatedActions<entry.targetActions) then
                    self.actionClock=self.actionClock+dt
                    if self.actionClock>=1.8 then
                        local ok,did=safe('自动出牌',automate)
                        if ok and did then self.actionClock=0 end
                    end
                end
                local actionsDone=not entry.targetActions or self.automatedActions>=entry.targetActions
                    or view.run and view.run.phase~='combat'
                local playbackDone=not entry.sample or not view.battleUI.busy
                    and (entry.sample~='3D' or not self.pending and #self.queue==0)
                if entry.sample and entry.failed or setupFailed or setupReady and job.elapsed>=entry.duration and (actionsDone or entry.failed) and (playbackDone or entry.failed)then nextStage(job)
                elseif entry.maxDuration and job.elapsed>=entry.maxDuration then
                    invalidateSample('达到采样最长时限，固定动作或演出未完成');self.samples={};entry.failed=true
                    log('UNVERIFIED 固定动作脚本未完成，本组样本作废');nextStage(job)
                end
            end
        end
        if self.cardMode==1 and cardSamples then
            paintCardSamples()
            local lift=math.sin(self.clock*2)*7
            cardSamples:SetAnchoredPosition(0,10+lift)
            cardSamples:SetLocalScale(1,1,1)
        end
        masks();panel:SetAsLastSibling()
        if self.frameSeconds>=.5 then
            if self.tweenWatching and tweenModule and type(tweenModule.status)=='function'then
                local ok,message=pcall(tweenModule.status,view)
                if ok and message~=self.lastTweenStatus then
                    self.lastTweenStatus=message;status(tostring(message));log(tostring(message))
                elseif not ok then self.tweenWatching=false;log('ERROR Tween结果：'..tostring(message))end
            end
            self.liveFps=self.frameCount/self.frameSeconds
            text(child(diagnostics,'metrics'),self.comparison or string.format('OnUpdate %.1f FPS / %.1f ms（脚本间隔）\nGPU / 内存 / 官方负载：UNAVAILABLE\n手机：UNVERIFIED · 队列 %d',self.liveFps,1000/self.liveFps,#self.queue))
            self.frameCount,self.frameSeconds=0,0
        end
    end
    function self:destroy()
        if self.destroyed then return end
        cancelTween('destroy')
        self.job=nil;self.sampleActive=false;clearNative();restore()
        if feedback and feedback.start==self.feedbackWrapper then feedback.start=originalStart end
        self.destroyed=true
        if type(self.unregister)=='function'then pcall(self.unregister)end
        for _,binding in ipairs(self.bindings)do
            if binding.control.RemoveCursorEventListener then
                pcall(binding.control.RemoveCursorEventListener,binding.control,api.clickEvent or Enum.CursorEventType.CursorClick,binding.callback)
            end
        end
        self.bindings={};visible(panel,false)
    end
    self.log=log
    log('候选 '..tostring(Config.buildId or 'unknown')..'；官方视觉/手机未验证')
    log('原生动画来自官方；本实验不产生原生伤害')
    safe('初始战斗',function()self:startBattle()end);updateMode()
    return self
end
return M
