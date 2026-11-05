local Run = require("abyss_run")
local Map = require("abyss_map")
local Nodes = require("abyss_nodes")
local CharacterSelect = require("abyss_character_select")
local RunSeed = require("abyss_run_seed")
local NeowHistory=require('abyss_neow_history')
local EndingHistory=require('abyss_ending_history')
local Acts=require('abyss_acts')
local M = {}
local function startBlocked(self)
    return self.exitOpen or self.deckUI.visible or self.settlementRequested or self.settlementBusy
end
local function finishHistory(self,neowHistory)
    if self.run then
        local phase=self.run.phase
        NeowHistory.finish(neowHistory,self.run,(phase=='victory' or phase=='defeat')and phase or 'abandon')
    end
end
local function beginNeow(run,map,neowHistory)
    local history,historyReason=NeowHistory.read(neowHistory,run.character,Acts.isCompetition(run))
    if not history and Acts.isCompetition(run) then history={bossCount=0,source='fresh-start'} end
    if history then
        local ok,why=Nodes.beginNeow(run,map,history);if not ok then return false,why end
        run.neowHistorySource=history.source
    else
        run.neowStatus=Acts.isCompetition(run) and 'disabled' or 'unavailable'
        run.neowUnavailableReason=historyReason
    end
    return true
end

function M.selectionChanged(self,owner)
    return function()
            owner.exitGeneration=owner.exitGeneration+1;owner.menuGeneration=owner.menuGeneration+1
            self:refresh()
        end
end

function M.closeCharacters(self,selectionChanged)
    return function(_)
            if not self.characterOpen or self.starting then return false end
            if self.characterSelection.deckOpen then self.characterSelection.deckOpen=false;selectionChanged();return true end
            self.characterOpen=false;self.characterSelection:clear()
            selectionChanged();return true
        end
end

function M.selectCharacter(self,selectionChanged)
    return function(_,id)
            if not self.characterOpen or self.starting or self.disabled then return false end
            local ok,reason=self.characterSelection:select(id)
            if ok then selectionChanged()end
            return ok,reason
        end
end

function M.selectElement(self,selectionChanged)
    return function(_,id)
            if not self.characterOpen or self.starting or self.disabled then return false end
            local ok,reason=self.characterSelection:selectElement(id)
            if ok then selectionChanged()end
            return ok,reason
        end
end

function M.start(self,selectionChanged)
    return function(_,character)
            if self.easterEggOpen then return false,'easter_egg_open' end
            if self.disabled or self.starting then return false,"ui_disabled" end
            if self.motion.deathReveal then return false,"result_revealing" end
            if startBlocked(self) then return false end
            if self.mode~='menu' and self.mode~='defeat' and self.mode~='victory' then return false end
            if self.characterOpen then return false,'character_choice_open' end
            self.characterOpen=true;self.characterSelection:clear();self.characterSelection.deckOpen=false
            -- Production keeps the select page, but the only open role is already showing.
            if self.characterSelection.profile~='full-source' then self.characterSelection:select('traveler') end
            selectionChanged()
            if character then
                for _,id in ipairs(CharacterSelect.elements)do if id==character then
                    self:selectCharacter('traveler');return self:selectElement(id)
                end end
                return self:selectCharacter(character)
            end
            return true,'character_choice'
        end
end

function M.beginRun(platform,data,self,newSeed,presentation,endingHistory,neowHistory,prologuePanel,owner)
    local function publishRun(run,map,rawSeed,runPresentation,explicitSeed,seed)
            self.characterOpen=false;owner.exitGeneration=owner.exitGeneration+1;owner.menuGeneration=owner.menuGeneration+1
            self.battleUI.feedback:cancel()
            self.battleUI:setData(run.data,runPresentation)
            self.nodeUI.presentation=runPresentation
            self.deckUI:setPresentation(runPresentation)
            if self.choiceUI then self.choiceUI:close();self.choiceUI:setPresentation(runPresentation) end
            self.run, self.map, self.runSeed = run, map, rawSeed
            self.settlementRequested, self.settlementBusy, self.settlementError = false, false, nil
            if explicitSeed then self.seed = type(seed)=='number' and (seed + 1) % 65536 or RunSeed.increment(rawSeed) end
            print("ABYSS_RUN seed=" .. rawSeed
                .. " source=" .. (explicitSeed and "explicit" or "clock"))
            self.battleUI.run, self.battleUI.target = self.run, 1
            self.mapUI.map = self.map
            self.nodeUI.run, self.nodeUI.map = self.run, self.map
            self.nodeUI:render()
            if prologuePanel then prologuePanel:SetVisible(false) end
            self:refresh()
            return true
    end
    return function(character)
            local selection=CharacterSelect.options(character)
            -- Native entry selects the competition profile; explicit full-source
            -- hosts retain future chapters without changing same-run ownership.
            if platform.campaign == true then
                selection = selection or {}
                selection.experimental, selection.campaign = true, true
                selection.campaignProfile=platform.campaignProfile
            end
            if not require('abyss_run_admission').accepts(data,selection)then return false,'competition_character_unavailable'end
            local explicitSeed = self.seed ~= nil
            local seed = explicitSeed and self.seed or newSeed()
            local rawSeed=RunSeed.normalize(seed)
            local run = Run.new(data,rawSeed,selection)
            local runPresentation = (selection and selection.character or run.data.colorlessCards) and require("abyss_character_presentation").prepare(presentation,run.data) or presentation
            local ending=EndingHistory.begin(endingHistory,run,{seedSet=explicitSeed,
                isDailyRun=platform.isDailyRun or false,isTrial=platform.isTrial or false})
            run.endingUnlocked,run.endingHistory=ending.unlocked,ending
            local context,contextReason=Run.freezeMapContext(run)
            if not context then return false,contextReason end
            local map = Map.generate(run.data,rawSeed,run.act or 1,context)
            local started,why=beginNeow(run,map,neowHistory)
            if not started then return false,why end
            return publishRun(run,map,rawSeed,runPresentation,explicitSeed,seed)
        end
end

function M.confirmCharacter(self,beginRun)
    return function(_)
            if not self.characterOpen or self.starting or self.disabled or self.exitOpen or self.characterSelection.deckOpen
                or self.settlementRequested or self.settlementBusy then return false,'character_choice_unavailable' end
            local info=self.characterSelection.info
            if not info then return false,'character_required' end
            if not self.characterSelection:canConfirm()then return false,'competition_character_unavailable'end
            self.starting=true
            -- Latch before seed generation and Run.new; a native duplicate cannot re-enter.
            local ok,accepted,reason=pcall(beginRun,info.id)
            self.starting=false
            if not ok then error(accepted)end
            return accepted,reason
        end
end

function M.advanceAct(self)
    return function()
            if self.disabled or not self.run or self.run.phase ~= 'act_transition' then return false,'act_transition_unavailable' end
            if self.exitOpen or self.deckUI.visible or self.potionUI.visible or self.battleUI.busy
                or self.settlementRequested or self.settlementBusy then return false,'ui_busy' end
            local ok, reason = Nodes.advanceAct(self.run, self.map)
            if ok then
                self.nodeUI.result, self.nodeUI.notice = nil, ''
                self.battleUI.selected, self.battleUI.target = nil, 1
                self.presentedBattle = nil
                if self.choiceUI then self.choiceUI:close() end
            else
                self.nodeUI.notice = '暂时无法前往下一幕，请重试。'
            end
            self:refresh()
            return ok, reason
        end
end

function M.settle(self,owner)
    return function(_)
            if self.easterEggOpen then return false,'easter_egg_open' end
            if self.disabled then return false,"ui_disabled" end
            if self.motion.deathReveal then return false,"result_revealing" end
            if self.characterOpen then return false, "character_choice_open" end
            if self.exitOpen then return false, "exit_open" end
            if self.deckUI.visible then return false, "deck_open" end
            if self.mode ~= "victory" and self.mode ~= "defeat" then return false, "not_result" end
            return owner.requestSettlement(self.mode == "victory")
        end
end

function M.requestSettlement(self,platform,neowHistory,owner)
    return function(victory)
            if self.disabled then return false,"ui_disabled" end
            if self.motion.deathReveal or self.run and self.run.phase == "defeat" and self.battleUI.busy then return false,"result_revealing" end
            if self.settlementRequested or self.settlementBusy then return false, "settlement_already_requested" end
            if type(platform.settle) ~= "function" then
                self.exitError = self.exitOpen == true
                self:refresh()
                return false, "settlement_unavailable"
            end
            self.settlementBusy = true
            local called, accepted = pcall(platform.settle, victory)
            self.settlementBusy = false
            if not called or accepted == false then
                self.settlementError, self.motion.shake = true, 0
                self.exitError = self.exitOpen == true
                self:refresh()
                return false, "settlement_request_failed"
            end
            self.settlementRequested, self.settlementError, self.exitError = true, nil, nil
            if self.prologue then self.prologue:cancel() end
            finishHistory(self,neowHistory)
            owner.exitGeneration = owner.exitGeneration + 1
            self:refresh()
            return true, "settlement_requested"
        end
end

return M
