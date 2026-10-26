-- Read-only permanent-deck snapshot. No Run commands, combat piles or RNG.
local Combat = require("abyss_combat")
local Theme = require("abyss_theme")
local CardDisplay = require('abyss_card_display')
local OriginalDisplay = require('abyss_original_v4_display')
local M = {}
local Controller = require('abyss_controller')
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }

function M.new(root, presentation, clickEvent, platform, onClose)
    local self = { root = root, visible = false, generation = 0, bindings={} }
    function self:setPresentation(value)
        assert(not self.visible and type(value)=="table", "cannot replace visible deck presentation")
        presentation=value
    end
    local grid = assert(root:GetChild("grid"), "missing deck grid")
    local details,detailHit=root:GetChild('details'),root:GetChild('detailHit')
    local function closeLabel(value)
        for _,state in ipairs({'normal','hover','pressed','disabled'}) do
            root:GetChild('close'):GetChild('hit'):GetChild(state):GetChild('label').text=value
        end
    end
    local function detailPage()
        root:GetChild('title').text=self.detailTitle..' · '..self.detailPage..'/'..#self.detailPages
        details.text=self.detailPages[self.detailPage]..'\n\n点按正文翻页 · 右上角返回'
    end
    function self.showDetails(_,definition,upgraded)
        if not self.visible or self.choiceToken or not definition.originalV4 then return false end
        local raw=OriginalDisplay.describe(definition,upgraded)
        -- Bound each page using the shared viewport/font, counting a CJK codepoint
        -- as a full em. Do not truncate rules; every wrapped line stays reachable.
        local columns=math.max(1,math.floor(Theme.layout.deckView.viewport[3]/Theme.font.body)-2)
        local rows=math.max(1,math.floor(Theme.layout.deckView.viewport[4]/Theme.layout.nativeText.lineHeight)-3)
        local lines,line,n={},'',0
        for ch in raw:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
            if ch=='\n' then lines[#lines+1]=line;line,n='',0
            else line=line..ch;n=n+1;if n>=columns then lines[#lines+1]=line;line,n='',0 end end
        end
        if line~='' then lines[#lines+1]=line end
        self.detailPages={}
        for i=1,#lines,rows do
            local page={};for j=i,math.min(i+rows-1,#lines) do page[#page+1]=lines[j] end
            self.detailPages[#self.detailPages+1]=table.concat(page,'\n')
        end
        self.detailTitle=definition.name..(upgraded and '+' or '')
        self.detailPage=1;grid:SetVisible(false);details:SetVisible(true);detailHit:SetVisible(true)
        closeLabel('返回');detailPage();return true
    end
    function self.inspect(_,run,definition,upgraded)
        if self.visible or not definition.originalV4 then return false end
        self.visible,self.run,self.detailOnly=true,run,true
        self.generation=self.generation+1;root:SetVisible(true);root:SetAsLastSibling()
        root:GetChild('close'):SetVisible(true);root:GetChild('close'):GetChild('hit').interactable=true
        return self:showDetails(definition,upgraded)
    end
    local function colour(value) return platform.color(value.r, value.g, value.b, value.a) end
    local function tint(control, value) control.imageColor = colour(value) end
    local function fill(control, instance, catalog)
        local battle=self.choiceToken and self.battle
        local definition = Combat.cardDefinition(battle or {catalog=catalog}, instance)
        local display = assert(presentation[instance.cardId], "missing deck presentation " .. instance.cardId)
        local face = control:GetChild("face")
        CardDisplay.writeTitle(face:GetChild("name"),display.name,instance.upgraded,
            definition.repeatable and (instance.upgrades or 1) or nil)
        face:GetChild("name").fontColor = colour(instance.upgraded and Theme.color.positive or Theme.color.text)
        -- Permanent cards carry no combat modifiers: fill live tokens with their own values.
        local text=battle and CardDisplay.combatText(display,definition,instance,Combat.cardPreview(battle,instance))
            or CardDisplay.permanentText(display,definition,instance)
        CardDisplay.writeBody(face:GetChild("label"),text)
        face:GetChild("type").text = typeNames[definition.type] or definition.type
        face:GetChild("cost").text = definition.cost == -2 and "" or definition.costMode == "all_energy" and "X" or tostring(definition.cost)
        tint(face:GetChild("border"), Theme.color.rarity[definition.rarity] or Theme.color.line)
        tint(face:GetChild("artPlate"), Theme.color.cardType[definition.type] or Theme.color.panelRaised)
        face:GetChild("art"):SetImage(platform.imageSource, Theme.icon.cardArt[definition.type] or Theme.icon.cardArt.status)
        local selected=false
        for _,uid in ipairs(self.choiceSelected or {}) do if uid==instance.uid then selected=true end end
        control:GetChild("uid").text = "UID " .. instance.uid .. (selected and ' · 已选' or '')
        local hit=control:GetChild('hit')
        hit:SetVisible(self.choiceToken~=nil or definition.originalV4~=nil)
        if not self.bindings[control] then
            self.bindings[control]={}
            local function pick()
                local b=self.bindings[control]
                if self.visible and not self.choiceToken and b.generation==self.generation then
                    return self:showDetails(b.definition,b.upgraded)
                end
                if not self.visible or not self.choiceToken or b.generation~=self.generation
                    or not self.run or self.run.combat~=self.battle
                    or not self.battle.pendingChoice or self.battle.pendingChoice.token~=self.choiceToken then return end
                local callback,token,uid=self.onPick,self.choiceToken,b.uid
                self:close()
                if callback then callback(token,uid) end
            end
            hit:AddCursorEventListener(clickEvent,function()
                if Controller.pointerBlocked(platform.controller)then return false end
                return pick()
            end)
            Controller.bind(platform.controller,hit,'deck',pick,function()
                return self.visible and self.bindings[control].generation==self.generation
            end,10)
        end
        self.bindings[control].generation,self.bindings[control].uid=self.generation,instance.uid
        self.bindings[control].definition,self.bindings[control].upgraded=definition,instance.upgraded
        control:SetVisible(true)
    end
    function self:open(run, choice, onPick)
        if self.visible then return false end
        self.generation = self.generation + 1
        local generation = self.generation
        -- A copied permanent instance never acquires temporary hand cost/growth/status.
        local cards, catalog = Combat.copy(run.deck), {cards={}}
        for _, card in ipairs(run.data.cards.cards) do catalog.cards[card.id] = card end
        self.choiceToken,self.onPick,self.battle=choice and choice.token,onPick,choice and run.combat
        self.multiple,self.choiceSelected=choice and choice.multiple,choice and choice.selected
        if choice then
            cards={}
            for _,uid in ipairs(choice.uids) do
                for _,pile in ipairs({run.combat.hand,run.combat.discard,run.combat.exhaust}) do
                    for _,c in ipairs(pile) do if c.uid==uid then cards[#cards+1]=Combat.copy(c) end end
                end
            end
        end
        self.visible, self.run, self.cards, self.catalog = true, run, cards, catalog
        self.controllerPage=1
        self.detailOnly,self.detailPages=nil,nil
        grid:SetVisible(true);details:SetVisible(false);detailHit:SetVisible(false)
        self.indexBase, self.pending, self.calibrating = nil, false, true
        root:SetVisible(true)
        root:SetAsLastSibling()
        local prompts={exhaustChoose="选择要消耗的牌",recoverExhaust="选择要回收的牌",discardToDraw="选择放回抽牌堆顶的牌",
            exhaustMany='选择任意张手牌消耗（可不选）',discardRedraw='选择任意张手牌丢弃并重抽',discardToHand='选择弃牌回手，本回合费用为0',
            handToDraw="选择放回抽牌堆顶的手牌",upgradeHand="选择要升级的牌",dualWield="选择要复制的攻击或能力牌"}
        root:GetChild("title").text = choice and prompts[choice.op] or "卡组 · " .. #cards .. " 张"
        if self.multiple then root:GetChild('title').text=root:GetChild('title').text..' · 已选'..#choice.selected..(choice.required and '/'..choice.required or '') end
        root:GetChild("close"):SetVisible(not choice or self.multiple == true)
        local close=root:GetChild('close'):GetChild('hit')
        close.interactable=not choice or self.multiple and (not choice.required or #choice.selected==choice.required) or false
        for _,state in ipairs({'normal','hover','pressed','disabled'}) do close:GetChild(state):GetChild('label').text=self.multiple and '确认选择' or '关闭' end
        grid.scrollProgress = 0
        -- Official API leaves index origin unspecified. A single-item callback
        -- reveals it without assuming a Lua (1) or native (0) convention. Fill
        -- the full list on the next update, outside the possibly deferred callback.
        grid:RefreshItems(#cards > 0 and 1 or 0, function(control, index)
            if not self.visible or self.generation ~= generation or not self.calibrating then return end
            self.indexBase, self.pending = index, true
            fill(control, cards[1], catalog)
        end)
        return true
    end
    function self:update()
        if not self.visible then return end
        local mode=platform.controllerApi and platform.controllerApi.isController() or false
        if self.controllerMode~=mode then
            self.controllerMode=mode;self.controllerPage=1
            if not self.calibrating and self.cards then self.generation=self.generation+1;self.pending=true end
        end
        local pageSize=Theme.layout.deckView.columns*2
        local pages=math.max(1,math.ceil(#(self.cards or {})/pageSize))
        for _,name in ipairs({'previous','next','pageHint'})do
            local box=root:GetChild(name)
            if box then
                box:SetVisible(mode and not self.detailPages and pages>1)
                if name=='pageHint' then box.text='摇杆导航 · 确认选择 · 返回关闭 · '..(self.controllerPage or 1)..'/'..pages
                else box:GetChild('hit').interactable=name=='previous' and (self.controllerPage or 1)>1
                    or name=='next' and (self.controllerPage or 1)<pages end
            end
        end
        if not self.pending then return end
        self.pending, self.calibrating = false, false
        local generation, cards, catalog, base = self.generation, self.cards, self.catalog, self.indexBase
        if mode then
            local subset={}
            for i=((self.controllerPage or 1)-1)*pageSize+1,math.min((self.controllerPage or 1)*pageSize,#cards)do subset[#subset+1]=cards[i]end
            cards=subset;grid.scrollProgress=0
        end
        grid:RefreshItems(#cards, function(control, index)
            if not self.visible or self.generation ~= generation then return end
            local instance = cards[index - base + 1]
            if instance then fill(control, instance, catalog) else control:SetVisible(false) end
        end)
    end
    function self.controllerStep(_,delta)
        if not self.visible or not self.controllerMode or self.detailPages or self.calibrating then return false end
        local page=(self.controllerPage or 1)+delta
        if page<1 or page>math.ceil(#self.cards/(Theme.layout.deckView.columns*2))then return false end
        self.generation=self.generation+1
        self.controllerPage,self.pending=page,true;self:update();return true
    end
    function self:close()
        if not self.visible then return false end
        self.generation = self.generation + 1
        self.visible, self.pending, self.calibrating, self.run, self.cards, self.catalog = false, false, false, nil, nil, nil
        self.choiceToken,self.onPick,self.battle=nil,nil,nil
        self.multiple,self.choiceSelected=nil,nil
        self.detailPages,self.detailOnly=nil,nil
        details:SetVisible(false);detailHit:SetVisible(false)
        root:SetVisible(false)
        grid:RefreshItems(0, function() end)
        return true
    end
    root.disableCursorEventPassthrough = true
    root:GetChild("blocker"):AddCursorEventListener(clickEvent, function() return true end)
    local function nextPage()
        if not self.visible or not self.detailPages then return false end
        self.detailPage=self.detailPage%#self.detailPages+1;detailPage();return true
    end
    detailHit:AddCursorEventListener(clickEvent,function()
        if Controller.pointerBlocked(platform.controller)then return false end
        return nextPage()
    end)
    Controller.bind(platform.controller,detailHit,'deck',nextPage,nil,1)
    function self.back(_)
        if not self.visible then return false end
        if self.detailPages and not self.detailOnly then
            self.detailPages=nil;details:SetVisible(false);detailHit:SetVisible(false);grid:SetVisible(true)
            root:GetChild('title').text='卡组 · '..#self.cards..' 张';closeLabel('关闭');return true
        end
        if self.multiple then
            if not root:GetChild('close'):GetChild('hit').interactable or not self.run or self.run.combat~=self.battle
                or not self.battle.pendingChoice or self.battle.pendingChoice.token~=self.choiceToken then return false end
            local callback,token=self.onPick,self.choiceToken
            self:close();return callback(token,0)
        end
        if self.choiceToken then return false end
        return onClose()
    end
    local close=root:GetChild('close'):GetChild('hit')
    close:AddCursorEventListener(clickEvent,function()
        if Controller.pointerBlocked(platform.controller)then return false end
        return self:back()
    end)
    Controller.bind(platform.controller,close,'deck',function()return self:back()end,nil,100)
    for _,name in ipairs({'previous','next'})do
        local box=root:GetChild(name)
        if box then
            local delta=name=='previous' and -1 or 1
            local action=function()return self:controllerStep(delta)end
            box:GetChild('hit'):AddCursorEventListener(clickEvent,function()
                if Controller.pointerBlocked(platform.controller)then return false end
                return action()
            end)
            Controller.bind(platform.controller,box:GetChild('hit'),'deck',action,nil,80)
        end
    end
    root:SetVisible(false)
    return self
end
return M
