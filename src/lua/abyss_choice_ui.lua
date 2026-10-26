-- A view of an existing core selection. Only the confirm callback issues a command.
local Combat=require("abyss_combat")
local Theme=require("abyss_theme")
local CardDisplay=require("abyss_card_display")
local M={}
local types={attack="攻击",skill="技能",power="能力",status="状态",curse="诅咒"}
local states={"normal","hover","pressed","disabled"}
local fields={potion='pendingPotionChoice',discard="pendingDiscard",scry="pendingScry",hand="pendingHandChoice",pile='pendingPileChoice'}
local function pending(run)
    if not run or run.phase~="combat" or not run.combat or run.combat.phase~="player" then return end
    for _,kind in ipairs({"potion","discard","scry","hand","pile"}) do
        local choice=run.combat[fields[kind]]
        if choice then return kind,choice end
    end
end
local function index(pile)
    local result={}
    for _,card in ipairs(pile or {}) do result[card.uid]=card end
    return result
end
local function candidates(run,kind,choice)
    local battle=run.combat
    if choice.turn~=battle.turn then return end
    if kind=='potion'then
        local view=require('abyss_potion_stance').view(battle,run.combatGeneration)
        return view and view.options
    end
    if kind=='pile' then
        local view=require('abyss_pile_choice').view(battle)
        if not view or view.generation~=run.combatGeneration then return end
        local source=index(battle[view.source]);local result={}
        for i,uid in ipairs(view.candidateUids) do result[i]=source[uid];if not result[i] then return end end
        return result
    end
    local source=kind=="scry" and index(battle.draw) or index(battle.hand)
    local uids=kind=="scry" and choice.candidateUids or choice.handUids
    if type(uids)~="table" then return end
    if kind=="scry" then
        if choice.drawSize~=#battle.draw or #uids>#battle.draw then return end
    elseif #uids~=#battle.hand then return end
    local cards,seen={},{}
    for i,uid in ipairs(uids) do
        local card=source[uid]
        if not card or seen[uid] then return end
        if kind=="scry" then
            if battle.draw[#battle.draw-i+1]~=card then return end
        elseif battle.hand[i]~=card
            or choice.cardIds and choice.cardIds[i]~=card.cardId
            or choice.upgraded and choice.upgraded[i]~=(card.upgraded==true) then return end
        seen[uid]=true;cards[i]=card
    end
    return cards
end
local function facts(cards,kind)
    local result={}
    for i,card in ipairs(cards) do
        result[i]=kind=='potion'and {option=card,id=card.id,name=card.name,text=card.text}
            or {card=card,uid=card.uid,id=card.cardId,upgraded=card.upgraded==true}
    end
    return result
end
local function matches(cards,saved,kind)
    if not cards or #cards~=#saved then return false end
    for i,card in ipairs(cards) do
        local old=saved[i]
        if kind=='potion'then
            if old.option~=card or old.id~=card.id or old.name~=card.name or old.text~=card.text then return false end
        elseif old.card~=card or old.uid~=card.uid or old.id~=card.cardId or old.upgraded~=(card.upgraded==true) then return false end
    end
    return true
end
function M.new(root,presentation,clickEvent,platform,onConfirm)
    assert(type(onConfirm)=="function","missing choice command callback")
    local self={root=root,visible=false,generation=0,selected={},page=1}
    local cursor=platform.cursorEvents or {}
    local pointerObserved=false
    local function child(name) return assert(root:GetChild(name),"missing choice control "..name) end
    local function caption(box,value)
        for _,state in ipairs(states) do box:GetChild("hit"):GetChild(state):GetChild("label").text=value end
    end
    local function colour(c) return platform.color(c.r,c.g,c.b,c.a) end
    local function fresh(duringConfirm)
        local c=self.context
        if not self.visible or not self.enabled or self.confirming and not duringConfirm or not c or self.run~=c.run
            or c.run.phase~="combat" or c.run.combat~=c.battle or c.battle.phase~="player"
            or c.run.combatGeneration~=c.combatGeneration or c.battle.turn~=c.turn then return false end
        local kind,choice=pending(c.run)
        return kind==c.kind and choice==c.pending and choice.token==c.token and choice.turn==c.pendingTurn
            and choice.count==c.count and choice.mode==c.mode
            and #c.battle.hand==c.handSize and #c.battle.draw==c.drawSize
            and matches(candidates(c.run,kind,choice),c.cards,kind)
    end
    local function limit() return self.context.kind=="scry" and #self.cards or self.context.count or 1 end
    local function countAllowed()
        return self.context.kind=="scry" or #self.selected==limit()
    end
    local function selected(uid)
        for i,value in ipairs(self.selected) do if value==uid then return i end end
    end
    local function cardText(instance)
        if self.context.kind=='potion'then
            local order=selected(instance.id)
            return (order and '已选 '..order..' · 'or '')..instance.name..'\n'..instance.text
        end
        local battle=self.context.battle
        local definition=Combat.cardDefinition(battle,instance)
        local display=assert(presentation[instance.cardId],"missing choice presentation "..instance.cardId)
        local text=instance.upgraded and display.upgradeText or display.text
        local live=instance.upgraded and display.upgradeCombatText or not instance.upgraded and display.combatText
        if live then text=CardDisplay.format(live,definition,Combat.cardPreview(battle,instance),Theme.color) end
        assert(type(text)=="string" and #text>0,"empty choice presentation "..instance.cardId)
        local cost=definition.cost==-2 and "不可打出" or definition.costMode=="all_energy" and "X" or tostring(definition.cost)
        local order=selected(instance.uid)
        return (order and "已选 "..order.." · " or "")..display.name..(instance.upgraded and "＋" or "")
            .."\n"..(types[definition.type] or definition.type).." · 费用 "..cost.."\n"..text
    end
    local function render()
        if not self.visible then return end
        local kind=self.context.kind
        child("title").text=kind=='potion'and '姿态药水：选择姿态'or kind=='pile' and (self.context.mode=='omniscience' and '全知：选择免费打出两次的牌' or self.context.mode=='meditate' and '冥想：回收并保留' or self.context.mode=='headbutt' and '回收至牌堆顶' or '回收至手牌')
            or kind=="scry" and "占卜" or kind=="discard" and "选择弃牌"
            or self.context.mode=="put_on_deck" and "放回抽牌堆顶" or "选择消耗"
        local pileName=({draw='抽牌堆',discard='弃牌堆',exhaust='消耗堆'})[self.context.pending.source]
        local hint=kind=='potion'and '选择一种姿态，必须完成选择。'or kind=='pile' and ('从'..(pileName or '牌堆')..'选择 '..limit()..' 张牌。')
            or kind=="scry" and "按选择顺序弃置；可不弃置。首张为抽牌堆顶。"
            or kind=="discard" and "选择 "..limit().." 张手牌弃置。" or "选择 1 张手牌。"
        child("hint").text=hint.." 已选 "..#self.selected..(kind=='potion'and ' 种。'or " 张。")
        child("status").text=self.error and "选择未提交，请重新确认。" or ""
        for slot=1,10 do
            local box=child("card"..slot)
            local card=self.cards[(self.page-1)*10+slot]
            box:SetVisible(card~=nil)
            box:GetChild("hit").interactable=card~=nil and not self.confirming
            if card then
                caption(box,cardText(card))
                local picked=selected(kind=='potion'and card.id or card.uid)~=nil
                for _,state in ipairs(states) do
                    local face=box:GetChild("hit"):GetChild(state)
                    local border=face:GetChild("border")
                    if border then border.imageColor=colour(picked and Theme.color.goldBright or Theme.color.goldDim) end
                end
            end
        end
        local confirm=child("confirm")
        caption(confirm,kind=="scry" and (#self.selected==0 and "全部保留" or "确认弃置") or "确认选择")
        confirm:GetChild("hit").interactable=countAllowed() and not self.confirming
        for _,name in ipairs({"before","after"}) do
            local box=root:GetChild(name)
            if box then
                box:SetVisible(#self.cards>10)
                box:GetChild("hit").interactable=not self.confirming and (name=="before" and self.page>1 or name=="after" and self.page*10<#self.cards)
            end
        end
    end
    function self:close()
        local visible=self.visible
        self.generation=self.generation+1
        self.visible,self.enabled,self.run,self.context=false,false,nil,nil
        self.cards,self.selected,self.page,self.error={}, {},1,nil
        root:SetVisible(false)
        return visible
    end
    function self:refresh(run,enabled)
        local kind,choice=pending(run)
        if enabled~=true or not choice then self:close();return false end
        local cards=candidates(run,kind,choice)
        if not cards or #cards==0 then self:close();return false,"stale_choice_candidates" end
        if #cards>10 and (not root:GetChild("before") or not root:GetChild("after")) then
            self:close();return false,"choice_page_controls_missing"
        end
        local old=self.context
        self.enabled=true
        if not old or self.run~=run or old.pending~=choice or not fresh(true) then
            self.generation=self.generation+1
            self.run,self.cards,self.selected,self.page,self.error=run,cards,{},1,nil
            local battle=run.combat
            self.context={run=run,battle=battle,turn=battle.turn,combatGeneration=run.combatGeneration,
                kind=kind,pending=choice,token=choice.token,pendingTurn=choice.turn,count=choice.count,mode=choice.mode,
                cards=facts(cards,kind),handSize=#battle.hand,drawSize=#battle.draw}
        end
        self.visible=true;root:SetVisible(true);root:SetAsLastSibling();render()
        return true
    end
    function self:resize()
        self.generation=self.generation+1
        return self.visible
    end
    function self:setPresentation(value)
        assert(type(value)=="table","invalid choice presentation")
        presentation=value;self.generation=self.generation+1;render()
    end
    function self:select(slot)
        if not fresh() then return false,"stale_choice" end
        if type(slot)~="number" or slot%1~=0 or slot<1 or slot>10 then return false,"invalid_choice_slot" end
        local card=self.cards[(self.page-1)*10+slot]
        if not card then return false,"invalid_choice_slot" end
        local key=self.context.kind=='potion'and card.id or card.uid
        local at=selected(key)
        if at then table.remove(self.selected,at)
        elseif limit()==1 then self.selected={key}
        elseif #self.selected<limit() then self.selected[#self.selected+1]=key
        else return false,"too_many_choices" end
        self.generation=self.generation+1;self.error=nil;render();return true
    end
    function self:confirm()
        if not fresh() then return false,"stale_choice" end
        if not countAllowed() then return false,"invalid_choice_count" end
        local c=self.context
        local uids={};for i,uid in ipairs(self.selected) do uids[i]=uid end
        self.confirming=true;self.generation=self.generation+1;render()
        local called,ok,reason=pcall(onConfirm,c.kind,uids,c.token,c.combatGeneration,c.battle)
        self.confirming=false
        if not called then reason,ok=ok,false end
        if not ok then
            -- A callback can synchronously refresh or replace the Run. Never put
            -- an old selection back onto a replacement battle.
            if self.context==c then self.error=reason or "choice_rejected";render() end
            return false,reason
        end
        self:refresh(c.run,true)
        return true,reason
    end
    local function bind(box,action)
        local hit=box:GetChild("hit")
        local held,released
        local function valid(token)
            return fresh() and hit.interactable~=false and (not token or token.generation==self.generation and token.context==self.context)
        end
        local function touch(event) return event and event.touchId end
        if cursor.CursorDown and cursor.CursorUp then
            hit:AddCursorEventListener(cursor.CursorDown,function(event)
                pointerObserved=true
                if held and not valid(held) then held=nil end
                if held and held.touch~=touch(event) then return false end
                held,released=nil,nil
                if valid() then held={generation=self.generation,context=self.context,touch=touch(event)} end
            end)
            hit:AddCursorEventListener(cursor.CursorUp,function(event)
                if not held or held.touch~=touch(event) then return false end
                released=valid(held) and held or nil;held=nil
            end)
            for _,event in pairs({cursor.CursorExit,cursor.CursorEndDrag}) do
                if event then hit:AddCursorEventListener(event,function(pointer)
                    local owner=held or released
                    if not pointer or owner and owner.touch==touch(pointer) then held,released=nil,nil end
                end) end
            end
        end
        hit:AddCursorEventListener(clickEvent,function(event)
            if pointerObserved or cursor.CursorDown and cursor.CursorUp and touch(event)~=nil then
                local token=released
                if not token or token.touch~=touch(event) or not valid(token) then return false end
                held,released=nil,nil
            elseif not valid() then return false end
            return action()
        end)
    end
    for i=1,10 do local slot=i;bind(child("card"..i),function() return self:select(slot) end) end
    bind(child("confirm"),function() return self:confirm() end)
    for _,name in ipairs({"before","after"}) do
        local box=root:GetChild(name)
        if box then
            local delta=name=="before" and -1 or 1
            bind(box,function()
                local page=self.page+delta
                if page<1 or (page-1)*10>=#self.cards then return false,"invalid_choice_page" end
                self.page=page;self.generation=self.generation+1;render();return true
            end)
        end
    end
    root.disableCursorEventPassthrough=true
    child("blocker"):AddCursorEventListener(clickEvent,function() return true end)
    root:SetVisible(false)
    return self
end
return M
