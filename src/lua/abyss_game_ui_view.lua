local Nodes = require("abyss_nodes")
local PotionDiscardUI = require("abyss_potion_discard_ui")
local Narrative = require("abyss_narrative")
local Bgm = require("abyss_bgm")
local CharacterView = require("abyss_character_select_view")
local MenuView=require("abyss_game_ui_menu_view")
local Theme=require("abyss_theme")
local number = require("abyss_numbers").integer
local NeowHistory=require('abyss_neow_history')
local EndingHistory=require('abyss_ending_history')
local Acts=require('abyss_acts')
local M = {}
local function building(status)
    return status and (status.phase=='building' or status.phase=='revealing')
end
local function currentAvatar(portraits)
    return portraits and (portraits.selection and portraits.selection.phase~='idle' and portraits.selection or portraits.avatar)
end

function M.present(menuView)
    return function() MenuView.present(menuView) end
end

function M.animate(menuView)
    return function(_,dt) MenuView.animate(menuView,dt) end
end

function M.paintArtLoading(platform,menu,self,menuLoading,characterPanel,characterLoading,originalCharacterHint)
    return function(_)
            local bg=platform.background and platform.background:status()
            local portraits=platform.portraits and platform.portraits:status()
            local avatar=currentAvatar(portraits)
            local function percent(s)return math.min(99,math.floor(100*((s.nextIndex or 1)-1)/math.max(1,s.total or 1)))end
            local summary=menu:GetChild('summary')
            if self.mode=='menu' and not self.characterOpen and building(bg) then
                summary.text='正在载入画面… '..percent(bg)..'%';summary:SetVisible(true);menuLoading=true
            elseif menuLoading then summary:SetVisible(false);menuLoading=false end
            local hint=characterPanel:GetChild('hint')
            if self.characterOpen and building(avatar) then
                if not characterLoading then originalCharacterHint=hint.text end
                hint.text='正在载入角色画面… '..percent(avatar)..'%';characterLoading=true
            elseif characterLoading then hint.text=originalCharacterHint or '查看初始信息，确认后开始冒险。';characterLoading=false end
        end
end

function M.syncController(self,controller,openingCovered)
    return function(_)
            if not controller then return end
            local function pageScope()
                local scope=self.mode
                if self.choiceUI and self.choiceUI.visible then scope='choice'
            elseif self.deckUI.visible then scope='deck'
            elseif self.potionUI.visible then scope='potions'
            elseif self.mode=='battle' and self.battleUI.potionMenu then scope='battlePotion'
            elseif self.mode=='battle' and self.battleUI.info then scope='battleInfo'
            elseif self.mode=='battle' and (self.battleUI.selected or self.battleUI.potionAim) then scope='aim' end
                return scope
            end
            local scope
            if self.disabled or self.settlementRequested or self.settlementBusy then scope='blocked'
            elseif self.easterEggOpen then scope='easterEgg'
            elseif self.exitOpen then scope='exit'
            elseif self.motion.deathReveal then scope='blocked'
            elseif self.characterOpen then scope='characters'
            elseif openingCovered() then scope='blocked'
            else scope=pageScope() end
            local function pageBack(backScope)
                if backScope=='potions' then return self:closePotions()
                elseif backScope=='battlePotion' or backScope=='battleInfo' or backScope=='aim' then return self.battleUI:controllerBack()
                elseif backScope=='node' and self.nodeUI.mode=='picker' then return self.nodeUI:press('back')
                elseif backScope=='battle' and self.run and self.run.phase=='reward' and self.battleUI.rewardScreen=='cards' then
                    return self.battleUI:controllerBack()
                elseif backScope~='blocked' then return self:openMenu() end
                return false
            end
            controller:sync(scope,function()
                if scope=='easterEgg' then return self.easterEgg:close()
                elseif scope=='exit' then return self:closeExit()
                elseif scope=='characters' then return self:closeCharacters()
                elseif scope=='blocked' and openingCovered() then return false
                elseif scope=='deck' then
                    if self.deckUI.choiceToken then return false end
                    return self.deckUI:back()
                elseif scope=='choice' then return false -- mandatory core selections cannot be dismissed
                else return pageBack(scope) end
            end)
        end
end

function M.finishRunFlow(neowHistory,endingHistory,self)
    return function(run)
            if run and (run.phase=='victory' or run.phase=='defeat')then NeowHistory.finish(neowHistory,run,run.phase)end
            if run and EndingHistory.finish(endingHistory,run,self.map)then run.endingHistoryResult=EndingHistory.read(endingHistory)end
            if not self.exitOpen and not self.settlementRequested and run and run.phase == "map" and run.nodeFlow and not run.nodeFlow.complete then
                Nodes.completeCombat(run, self.map)
            end
        end
end

function M.selectMode(self)
    return function(run)
            if self.battleUI.busy then self.mode = "battle"
            elseif not run then self.mode = "menu"
            elseif require('abyss_relic_pending').owner(run)then self.mode='node'
            elseif run.phase == "defeat" then self.mode = "defeat"
            elseif run.phase == "victory" then self.mode = "victory"
            elseif run.phase == "combat" or run.phase == "reward" then self.mode = "battle"
            elseif run.phase == "node" or run.phase == 'act_transition' or run.phase=='ending_proceed' then self.mode = "node"
            -- Camp/event results stay on screen until the player presses 继续.
            elseif self.nodeUI.run == run and self.nodeUI:holding() then self.mode = "node"
            else self.mode = "map" end
        end
end

function M.syncMenuContext(self,owner)
    local menuRun,menuMode
    return function(run,inMenu)
            if menuRun ~= run or menuMode ~= self.mode then
                owner.menuGeneration = owner.menuGeneration + 1
                menuRun, menuMode = run, self.mode
            end
            if self.characterOpen and (not inMenu or self.settlementRequested or self.settlementBusy) then
                self.characterOpen=false;owner.exitGeneration=owner.exitGeneration+1;owner.menuGeneration=owner.menuGeneration+1
            end
        end
end

function M.syncCardChoice(self)
    return function(run)
            if self.choiceUI then
                self.choiceUI:refresh(run,not self.battleUI.busy and not self.exitOpen and not self.settlementRequested
                    and not self.settlementBusy and not self.deckUI.visible and not self.potionUI.visible)
            end
        end
end

function M.closeStaleDeck(self)
    return function(run,inMenu)
            if self.deckUI.visible and (inMenu or run and run.phase=='ending_proceed' or self.battleUI.busy or self.deckUI.run ~= run
            or self.deckUI.pileKind and (run.phase~='combat' or run.combat~=self.deckUI.battle))then self.deckUI:close()end
        end
end

function M.openCardChoice(self)
    return function(run)
            if run and run.phase=="combat" and run.combat.pendingChoice and not self.battleUI.busy
                and not self.deckUI.visible and not self.exitOpen then
                self.deckUI:open(run,run.combat.pendingChoice,function(token,uid)
                    self.battleUI:chooseCard(token,uid)
                    self:refresh()
                end)
            end
        end
end

function M.syncRewardReturn(self)
    return function(run,deckOpen,potionOpen,blocked,covering)
            local returnAvailable = self.mode == "map" and run and run.pendingCombatRewards ~= nil
                and not deckOpen and not potionOpen and not blocked and not covering or false
            if self.rewardReturnAvailable ~= returnAvailable then
                self.rewardReturnAvailable = returnAvailable
                self.rewardReturnGeneration = (self.rewardReturnGeneration or 0) + 1
            end
            return returnAvailable
        end
end

function M.refreshPotionEntry(child,inCombat,canManagePotions,platform)
    return function(run)
            local potionHit=child("potionEntry"):GetChild("open"):GetChild("hit")
            potionHit.interactable=not inCombat() and canManagePotions(run);potionHit.raycastTarget=potionHit.interactable
            PotionDiscardUI.refreshEntry(potionHit,run,platform)
        end
end

function M.refreshDeckEntry(child,self)
    return function(run)
            local deckHit = child("deckEntry"):GetChild("open"):GetChild("hit")
            deckHit.interactable = not self.battleUI.busy;deckHit.raycastTarget=deckHit.interactable
            -- The shared deck button carries the deck size, so no screen repeats it as loose text.
            for _, state in ipairs({ "normal", "hover", "pressed", "disabled" }) do
                local variant = deckHit:GetChild(state)
                if variant then
                    variant:GetChild("label").text = run and "卡组 " .. #run.deck or "卡组"
                    variant:GetChild('count').text=run and number(#run.deck) or ''
                end
            end
        end
end

function M.refreshUtilities(child,self,inCombat,refreshPotionEntry,refreshDeckEntry)
    return function(run,inMenu,deckOpen,potionOpen,blocked,covering,returnAvailable)
            local ending=run and run.phase=='ending_proceed'
            local utilitiesVisible=not ending and not inMenu and not deckOpen and not potionOpen and not blocked and not covering
            child("combatRewards"):SetVisible(returnAvailable)
            -- Route preview raises the full-page map. Restore this sibling above it
            -- when returning to navigation; visibility alone leaves it occluded.
            if returnAvailable then child("combatRewards"):SetAsLastSibling() end
            child("deckEntry"):SetVisible(utilitiesVisible)
            -- STS has no separate relic button: the discs under the HP row are the one control.
            child("relicEntry"):SetVisible(false)
            self.relicUI:refreshBar(run,utilitiesVisible)
            for _,state in ipairs({'normal','hover','pressed','disabled'})do
                local variant=child('relicEntry'):GetChild('open'):GetChild('hit'):GetChild(state)
                variant:GetChild('label').text=run and '遗物 '..#run.relics or '遗物'
                variant:GetChild('count').text=run and number(#run.relics) or ''
            end
            child("potionEntry"):SetVisible(not inCombat() and utilitiesVisible)
            refreshPotionEntry(run)
            child("nodePanel"):GetChild("potions"):SetVisible(false)
            if potionOpen then self.potionUI:render()end
            refreshDeckEntry(run)
        end
end

function M.refreshMapResources(child)
    return function(run)
            if run then
                local resources = child("mapPanel"):GetChild("resources")
                resources:GetChild("hp").text = number(run.hp) .. "/" .. number(run.maxHp)
                resources:GetChild("gold").text = number(run.gold)
            end
        end
end

function M.suspendBattle(self,openingCovered)
    return function(run,deckOpen,potionOpen)
            return self.mode=='battle' and run and run.phase=='combat'
                and (deckOpen or potionOpen or self.exitOpen) and not self.disabled
                and not self.settlementRequested and not self.settlementBusy and not openingCovered()
        end
end

function M.refreshPageVisibility(menu,self,suspendBattle,child,refreshMapResources)
    return function(run,inMenu,deckOpen,potionOpen,blocked)
            menu:SetVisible(inMenu and not self.characterOpen and not self.easterEggOpen)
            self.battleUI:setActive(self.mode == "battle" and not deckOpen and not potionOpen and not blocked,
                suspendBattle(run,deckOpen,potionOpen))
            child("battlePanel"):SetVisible(self.mode == "battle")
            self.mapUI:setVisible(self.mode == "map" and not deckOpen and not potionOpen and not blocked)
            child("mapPanel"):SetVisible(self.mode == "map")
            refreshMapResources(run)
            self.nodeUI:setVisible(self.mode == "node" and not deckOpen and not potionOpen and not blocked)
            child("nodePanel"):SetVisible(self.mode == "node")
        end
end

function M.renderBattlePage(self,child)
    return function(run)
            self.battleUI:render()
            if run.phase == "combat" and self.presentedBattle ~= run.combat then
                self.presentedBattle = run.combat
                local guardian = false
                for _, enemy in ipairs(run.combat.enemies) do
                    if enemy.definitionId == "guardian" then guardian = true end
                end
                child("battlePanel"):GetChild("notice").text = guardian
                    and Narrative.flow.bossEntrance.full or ""
                self.bossEntrance=guardian and {battle=run.combat,remaining=6} or nil
            end
        end
end

function M.updateBossEntrance(self,child)
    return function(dt)
            local entrance=self.bossEntrance
            if not entrance then return end
            local notice=child("battlePanel"):GetChild("notice")
            entrance.remaining=entrance.remaining-dt
            if not self.run or self.run.combat~=entrance.battle or self.run.phase~="combat"
                or notice.text~=Narrative.flow.bossEntrance.full or entrance.remaining<=0 then
                if notice.text==Narrative.flow.bossEntrance.full then notice.text="" end
                self.bossEntrance=nil
            end
        end
end

function M.renderMapPage(self)
    return function(run,deckOpen,potionOpen,blocked,covering)
            -- While the cinematic's last fade uncovers the map, the map is visible but inert.
            self.mapUI:setNavigationEnabled(not deckOpen and not potionOpen and not blocked and not covering and #Nodes.available(run, self.map) > 0)
            if run.neowStatus=='unavailable' and self.map.floor==0 and not self.mapUI.entryError then
                self.mapUI.entryError='开局恩赐暂不可用：未取得上一局历史；本次保持原开局资源。'
                self.mapUI:render()
            end
        end
end

function M.renderCurrentPage(self,renderBattlePage,renderMapPage)
    return function(run,deckOpen,potionOpen,blocked,covering)
            if self.mode == "battle" then
                renderBattlePage(run)
            elseif self.mode == "map" then
                renderMapPage(run,deckOpen,potionOpen,blocked,covering)
            elseif self.mode == "node" then self.nodeUI:render() end
        end
end

function M.exitDialogOwnsForeground(self)
    return function()
            return self.exitOpen == true and not self.routeOpen and (not self.menuOpen or self.controlsOpen == true)
        end
end

function M.refreshExitDialog(exitDialogOwnsForeground,exitPanel,self)
    return function()
            if exitDialogOwnsForeground() then
                exitPanel:SetAsLastSibling()
                local message = self.run and "确认退出本局？退出后本局结束，进度无法恢复。\n将进入平台结算，随后可选择离开。"
                    or "确认结束当前关卡？\n将进入平台结算，随后可选择离开。"
                if self.mode == "victory" then message = "确认结束本局并结算胜利？\n随后可在平台结算页选择离开。" end
                exitPanel:GetChild("message").text = message
                -- Lv.4 局内存档未开放：仅在进行中的一局里，用一行小字说明原因。
                local why = self.run ~= nil and self.mode ~= "victory"
                exitPanel:GetChild("whyText"):SetVisible(why)
                exitPanel:GetChild("whyText").text = why and "存档功能需作者达到创作者 4 级后开放，喜欢的话欢迎点赞支持。帮助作者提升等级。" or ""
                exitPanel:GetChild("status").text = self.settlementRequested and "结算请求已发送，等待平台结算界面。"
                    or self.exitError and "退出请求失败，请重试或继续游戏。" or ""
                local enabled = not self.settlementRequested and not self.settlementBusy
                for _, name in ipairs({"cancel", "confirm"}) do
                    local hit=exitPanel:GetChild(name):GetChild("hit");hit.interactable,hit.raycastTarget=enabled,enabled
                end
            end
        end
end

function M.syncPortraits(platform,self)
    return function()
            if not platform.portraits then return end
            local character
            if self.characterOpen and self.characterSelection.info then character=self.characterSelection.info.id
            elseif self.run then character=self.run.character or 'ironclad'end
            platform.portraits:sync(self.mode,self.characterOpen,self.settlementRequested or self.settlementBusy,character,
                self.mode=='menu' and not self.characterOpen)
        end
end

function M.exitEntryVisible(self)
    return function()
            return not self.easterEggOpen and not self.exitOpen and not self.settlementRequested and not self.settlementBusy
        end
end

function M.refreshForeground(characterPanel,self,platform,exitEntry,exitEntryVisible,exitPanel,exitDialogOwnsForeground,runMenu,canViewRoute,child,refreshExitDialog)
    return function()
            if characterPanel then
                characterPanel:SetVisible(self.characterOpen==true)
                if self.characterOpen then
                    CharacterView.render(characterPanel,self.characterSelection,platform)
                    characterPanel:SetAsLastSibling()
                end
            end
            if self.choiceUI and self.choiceUI.visible then self.choiceUI.root:SetAsLastSibling() end
            -- Shared utilities stay above the deck overlay; the confirmation stays
            -- above every page, including an in-flight battle presentation.
            exitEntry:SetVisible(exitEntryVisible())
            exitEntry:SetAsLastSibling()
            exitPanel:SetVisible(exitDialogOwnsForeground())
            runMenu:SetVisible(self.exitOpen == true and self.menuOpen == true and not self.controlsOpen and not self.routeOpen)
            -- TASK-4.16 AC#2：未启程时地图入口整颗隐藏（不再挂「启程后可用」的灰按钮）。
            local routeBox=runMenu:GetChild('map')
            local routeHit=routeBox:GetChild('hit')
            local routeEnabled=canViewRoute()
            routeBox:SetVisible(routeEnabled)
            routeHit.interactable,routeHit.raycastTarget=routeEnabled,routeEnabled
            -- Pan 2026-10-31：首页（未启程）收起「查看地图」那一格，面板与下方控件上提不留空洞。
            do
                local R=Theme.layout.runMenu
                local gap=routeEnabled and 0 or (R.help[2]-R.map[2])
                local function at(name,spec,dy)local c=runMenu:GetChild(name);if c then c:SetAnchoredPosition(spec[1],spec[2]+dy)end end
                at('rule',R.rule,gap);at('abandon',R.abandon,gap);at('dismissHint',R.dismissHint,gap)
                local h=R.panel[4]-gap
                for _,name in ipairs({'border','face','catch'})do
                    local c=runMenu:GetChild(name)
                    if c then c:SetAnchoredPosition(R.panel[1],R.panel[2]+gap/2)
                        local inset=name=='face' and Theme.space.border*2 or 0
                        c:SetSizeDelta(R.panel[3]-inset,h-inset)end
                end
            end
            if runMenu.visible then runMenu:SetAsLastSibling() end
            local back = child('mapPanel'):GetChild('previewBack')
            back:SetVisible(self.routeOpen == true)
            if self.routeOpen then
                self.mapUI.map = self.map
                self.mapUI:setVisible(true)
                self.mapUI:setNavigationEnabled(false)
                child('mapPanel'):SetAsLastSibling()
            end
            refreshExitDialog()
        end
end

function M.overlaysBlocked(self)
    return function()
            local blocked = self.easterEggOpen or self.exitOpen or self.settlementRequested or self.settlementBusy or self.characterOpen
                or self.choiceUI and self.choiceUI.visible
            return blocked
        end
end

function M.syncOpening(self,openingCovered)
    return function(run)
            if self.prologue and (self.settlementRequested or run and (run.phase=='defeat' or run.phase=='victory')) then self.prologue:cancel() end
            return openingCovered()
        end
end

function M.openingForeground(self,child,prologuePanel,runMenu,exitPanel)
    return function(covering)
            if self.prologue and self.prologue:opaque() then
                child('mapPanel'):SetVisible(false);child('nodePanel'):SetVisible(false)
            end
            if not covering then return end
            prologuePanel:SetAsLastSibling();child('exitEntry'):SetAsLastSibling()
            if self.menuOpen then runMenu:SetAsLastSibling()
            elseif self.exitOpen then exitPanel:SetAsLastSibling() end
        end
end

function M.syncOfficialBattleScene(root,self)
    local lastBackdropVisible,lastBackdrop
    return function(run)
            local scenes=root:GetChild('officialBattleBackdrop')
            if not scenes then return end
            local visible=self.mode=='battle'
            if visible~=lastBackdropVisible then scenes:SetVisible(visible);lastBackdropVisible=visible end
            local floor=math.max(1,run and run.floor or 1)
            local act,row=Acts.forFloor(floor);local chapter=math.min(2,act)
            local key=floor==Acts.get(act).boss and 'boss'..chapter or 'act'..chapter..'_'..((row-1)%3+1)
            if key==lastBackdrop then return end
            for _,name in ipairs({'act1_1','act1_2','act1_3','act2_1','act2_2','act2_3','boss1','boss2'})do
                scenes:GetChild(name):SetVisible(name==key)
            end
            lastBackdrop=key
        end
end

function M.refresh(self,finishRunFlow,syncOpening,selectMode,syncOfficialBattleScene,syncMenuContext,platform,syncCardChoice,closeStaleDeck,openCardChoice,canManagePotions,overlaysBlocked,syncRewardReturn,refreshUtilities,refreshPageVisibility,renderCurrentPage,bgm,present,refreshForeground,syncPortraits,openingForeground)
    return function(_)
            if self.disabled then return false,"ui_disabled" end
            local run = self.run
            finishRunFlow(run)
            local covering = syncOpening(run)
            selectMode(run)
            syncOfficialBattleScene(run)
            local inMenu = self.mode == "menu" or self.mode == "defeat" or self.mode == "victory"
            syncMenuContext(run,inMenu)
            if platform.background then platform.background:sync(self.mode,self.characterOpen,self.settlementRequested or self.settlementBusy) end
            syncCardChoice(run)
            closeStaleDeck(run,inMenu)
            openCardChoice(run)
            local deckOpen = self.deckUI.visible
            if self.potionUI.visible and not canManagePotions(self.potionUI.run)then self.potionUI:close()end
            local potionOpen=self.potionUI.visible
            local blocked=overlaysBlocked() or covering
            local returnAvailable=syncRewardReturn(run,deckOpen,potionOpen,blocked,covering)
            refreshUtilities(run,inMenu,deckOpen,potionOpen,blocked,covering,returnAvailable)
            refreshPageVisibility(run,inMenu,deckOpen,potionOpen,blocked)
            renderCurrentPage(run,deckOpen,potionOpen,blocked,covering)
            bgm:update(self.settlementRequested and "stop" or Bgm.scene(self.mode, run, self.battleUI.busy, bgm.cue))
            present()
            refreshForeground()
            if self.easterEgg then self.easterEgg:refresh()end
            syncPortraits()
            openingForeground(covering)
            self:syncController()
        end
end

return M
