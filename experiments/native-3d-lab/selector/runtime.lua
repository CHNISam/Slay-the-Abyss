-- Experimental native reward window. All grants go through Run.claimCardReward.
local M={}
local function integer(x)return type(x)=='number' and x==x and x%1==0 and math.abs(x)<math.huge end
function M.attach(view,root,api)
    api=api or {}
    local Run=require('abyss_run')
    local Owner=require('abyss_battle_reward_owner')
    local Rewards=require('abyss_relic_card_rewards')
    local Fixture=api.fixture or require('abyss_3d_selector_fixture')
    local config=assert(api.config,'selector config required')
    local self={clock=0,serial=0,generation=0,phase='classic',lastStatus='原生选择器：尚未测试'}
    local ui=view.battleUI
    local lookup={}
    for _,card in ipairs(config.cards or {})do lookup[card.cardId..':'..tostring(card.upgraded==true)]=card end
    local function log(message)
        self.lastStatus=message
        if api.log then api.log('选牌对照 '..message)else print('ABYSS_SELECTOR '..message)end
    end
    local function send(name,params)
        if type(api.send)~='function'then return false,'信号接口不可用'end
        local ok,value=pcall(api.send,name,params)
        return ok and value~=false,ok and value or tostring(value)
    end
    local function param(value)return {type='integer',value=value}end
    local function restore()
        local cover=self.cover;self.cover=nil
        if not cover then return end
        ui.rewardEpoch=(ui.rewardEpoch or 0)+1 -- reject pointer releases from before/during the native modal
        ui.active=cover.active
        if api.hideRoot then pcall(api.hideRoot,false)
        else
            for _,item in ipairs(cover.children)do
                if item.control.alive~=false then pcall(item.control.SetVisible,item.control,item.visible)end
            end
        end
        if view.refresh then view:refresh()end
    end
    local function hide()
        local saved={active=ui.active,children={}}
        if api.hideRoot then
            local ok,why=pcall(api.hideRoot,true)
            if not ok or why==false then return false,tostring(why)end
        else
            if not root or type(root.GetChildren)~='function'then return false,'没有根控件枚举能力，无法移开正式界面'end
            local ok,children=pcall(root.GetChildren,root)
            if not ok or type(children)~='table'then return false,'无法枚举完整自定义界面'end
            for _,control in ipairs(children)do
                saved.children[#saved.children+1]={control=control,visible=control.activeInHierarchy~=false}
            end
            self.cover=saved
            for _,item in ipairs(saved.children)do
                local accepted,why=pcall(item.control.SetVisible,item.control,false)
                if not accepted or why==false then restore();return false,tostring(why)end
            end
        end
        -- Do not invent runtime blockCursor/blockKeys properties from the layout schema.
        -- Root script stays active for replies/timeouts; every visual/input child is hidden.
        ui.active=false;self.cover=saved
        return true
    end
    local function unsupported(run)
        if not run or run.phase~='reward' or not run.rewards or run.rewards.cardResolved then return '没有未领取的战后卡牌奖励'end
        if Rewards.managed(run)or run.pendingCardRewardSelection then return '特殊奖励组/歌唱碗/祈祷转轮仍使用正式界面'end
        if run.pendingBottledRelic or run.shopRelicChoice or run.pendingBossRelic or run.shopRelicRewards then return '其他奖励事务仍在处理'end
        if run.combat and run.combat.originalV4 or run.data and run.data.originalV4Role then return '原版V4候选仍使用正式界面'end
        local cards=Run.rewardOptions(run)
        if #cards<1 or #cards>3 then return '仅适用普通1至3候选卡牌奖励'end
        for i,id in ipairs(cards)do
            local flag=run.rewards.cardUpgrades and run.rewards.cardUpgrades[i]
            if flag~=nil and type(flag)~='boolean'then return '非布尔升级状态不在本实验范围'end
            if not lookup[id..':'..tostring(flag==true)]then return '当前候选不在同源六条库：'..id..'，保留正式界面'end
        end
    end
    local function current(pending)
        local run=view.run
        return pending and not pending.consumed and pending.generation==self.generation
            and pending.run==run and pending.roomGeneration==run.roomGeneration
            and pending.combatGeneration==run.combatGeneration and Owner.ready(ui,pending.owner)
    end
    local function finish(reason)
        if self.pending then self.pending.consumed=true end
        self.pending=nil;self.phase='classic';restore();log(reason)
    end
    function self:reply(params)
        if self.destroyed or type(params)~='table'then return false end
        local token,result,reason=params[1],params[2],params[3]
        local pending=self.pending
        if not pending or not integer(token) or token~=pending.token then return false end
        if type(reason)~='string'then return false end
        if reason=='opened:await_selection' or reason=='closing:await_native_event'then
            log(reason=='opened:await_selection' and '原生窗口已请求打开；等待玩家选择，显示/遮挡仍待本轮实机' or '正在关闭原生窗口')
            return true
        end
        if reason~='selected'then
            finish((reason=='timeout' and '原生超时，未自动领取；已恢复正式奖励' or '原生选择未提交：'..reason..'；已恢复正式奖励'))
            return true
        end
        if not current(pending)then finish('STALE 旧奖励/代次已失效，未提交卡牌');return false end
        local choice=integer(result) and result-token*16 or nil
        if not choice or choice<1 or choice>#pending.cards then finish('INVALID 原生结果与当前token/候选不符，未提交卡牌');return false end
        -- Consume before the transaction so reentrant/duplicate callbacks cannot grant twice.
        pending.consumed=true
        local called,ok,detail=pcall(Run.claimCardReward,pending.run,choice)
        if not called or not ok then
            finish('奖励事务拒绝：'..tostring(called and detail or ok)..'；已恢复正式界面')
            return false
        end
        local id=pending.cards[choice]
        finish('已按正式奖励事务领取 '..id..'；新UID由原Run分配，重复回执无效')
        return true
    end
    function self:cancel(reason)
        local pending=self.pending
        if not pending then restore();return false end
        send('LAB_SELECTOR_CANCEL',{param(pending.token)})
        finish((reason or '取消/跳过')..'；不消耗奖励，已恢复正式界面')
        return true
    end
    function self:classic()
        self:cancel('切回正式选牌')
        restore();self.phase='classic'
        if view.refresh then view:refresh()end
        log('正式奖励界面；点卡牌奖励进入现有完整选牌，规则不变')
        return true
    end
    function self:fixture()
        self:cancel('新建奖励对照')
        self.generation=self.generation+1
        local data=api.data or view.data or require('abyss_data')
        local run,meta=Fixture.make(data,config.seed or 42)
        if ui.feedback and ui.feedback.cancel then ui.feedback:cancel()end
        local map=require('abyss_map').generate(data,config.seed or 42)
        view.run,view.map,view.prologueSeen=run,map,true
        ui.run=run;view.mapUI.map=map;view.nodeUI.run,view.nodeUI.map=run,map
        view.characterOpen,view.exitOpen,view.easterEggOpen=false,false,false
        view:refresh()
        self.fixtureMeta=meta
        log('真实Run奖励夹具：seed='..meta.seed..'，'..meta.commands..'条原规则命令击败邪教徒；并非自然游玩进度')
        return run,meta
    end
    function self:open()
        if self.destroyed then return false,'selector_destroyed'end
        if self.pending then return false,'selector_already_open'end
        if config.available~=true then log('UNAVAILABLE 选择器未装配');return false,'selector_unavailable'end
        local run=view.run;local why=unsupported(run)
        if why then log('UNAVAILABLE '..why);return false,why end
        if self.serial>=100000000 then log('UNAVAILABLE 请求token已用尽；请重新进入实验');return false,'token_exhausted'end
        self.serial=self.serial+1
        ui.rewardEpoch=(ui.rewardEpoch or 0)+1 -- old formal reward buttons no longer own this pointer sequence
        local owner=Owner.capture({battle=run.combat},ui,run)
        local cards=Run.rewardOptions(run) -- detached candidate IDs, no rule edits
        local references={}
        for i,id in ipairs(cards)do references[i]=lookup[id..':'..tostring(run.rewards.cardUpgrades and run.rewards.cardUpgrades[i]==true or false)].number end
        local pending={token=self.serial,generation=self.generation,run=run,owner=owner,cards=cards,
            roomGeneration=run.roomGeneration,combatGeneration=run.combatGeneration,deadline=self.clock+32}
        local hidden,reason=hide()
        if not hidden then log('UNAVAILABLE 原生窗口打开前无法移开完整自定义界面：'..tostring(reason));return false,reason end
        self.pending=pending;self.phase='native'
        local sent,error=send('LAB_SELECTOR_OPEN',{param(pending.token),param(#cards),param(references[1]),param(references[2] or 0),param(references[3] or 0)})
        if not sent then finish('ERROR 原生请求发送失败：'..tostring(error));return false,error end
        log('原生选牌请求 #'..pending.token..'；全文同源/动态子集，原生窗口可交互性待实机')
        return true,pending.token
    end
    function self:start(mode,fresh)
        mode=mode or 'native'
        if fresh or not view.run or view.run.phase~='reward' or view.run.rewards.cardResolved then self:fixture()end
        if mode=='classic'then return self:classic()end
        if mode~='native'then return false,'invalid_selector_mode'end
        return self:open()
    end
    function self:update(dt)
        if self.destroyed or type(dt)~='number' or dt~=dt or dt<0 or dt==math.huge then return end
        self.clock=self.clock+dt
        if self.pending and not current(self.pending)then self:cancel('STALE 奖励所有权改变')
        elseif self.pending and self.clock>=self.pending.deadline then self:cancel('TIMEOUT 未收到原生完成回执')end
    end
    function self:status()return self.lastStatus end
    function self:destroy()
        if self.destroyed then return end
        self:cancel('实验销毁');self.destroyed=true
        if type(self.unregister)=='function'then pcall(self.unregister)end
    end
    if type(api.register)=='function'then
        local ok,value=pcall(api.register,'LAB_SELECTOR_REPLY',function(params)return self:reply(params)end)
        if ok then self.unregister=value else log('ERROR 原生回执订阅失败：'..tostring(value))end
    end
    return self
end
return M
