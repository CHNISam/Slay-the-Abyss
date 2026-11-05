local M = {}
local function validDelta(dt)
    return type(dt) == 'number' and dt == dt and dt >= 0 and dt ~= math.huge
end
local function countRunTime(self,dt,openingCovered)
    local run=self.run
    if run and not openingCovered() and run.phase ~= "defeat" and self.mode ~= "victory" and self.mode ~= "defeat" then
        local elapsed=run.elapsedSeconds+dt
        if elapsed==math.huge then return false end
        run.elapsedSeconds=elapsed
    end
    return true
end

function M.onEngineDestroy(self)
    return function(_)
            self.disabled=true
            local ok,why=pcall(self.battleUI.onEngineDestroy,self.battleUI)
            if self.easterEgg then self.easterEgg:onEngineDestroy()end
            assert(ok,why)
        end
end

function M.resize(self,owner)
    return function(_, width, height)
            owner.exitGeneration = owner.exitGeneration + 1
            owner.menuGeneration = owner.menuGeneration + 1
            if self.choiceUI then self.choiceUI:resize() end
            local closed=self.potionUI:close()
            self.battleUI:resize(width, height)
            self.mapUI:resize(width, height)
            self.nodeUI:resize(width, height)
            if closed then self:refresh()end
        end
end

function M.update(self,controller,platform,openingCovered,updateBossEntrance,bgm)
    local function advancePages(dt)
            self.battleUI:update(dt)
            updateBossEntrance(dt)
            if self.battleUI.busy and self.battleUI.feedback.deaths.player then bgm:update("defeat") end
            self.nodeUI:update(dt)
            self.deckUI:update(dt)
            local updated=self.mapUI:update(dt)
            self:syncController()
            return updated
    end
    return function(_, dt)
            if self.disabled then return false,"ui_disabled" end
            if not validDelta(dt) then
                return false, "invalid_delta"
            end
            if self.easterEggOpen then
                self.easterEgg:tick();if controller then controller:tick()end;self:syncController();return true
            end
            if platform.background then platform.background:tick() end
            if platform.portraits then platform.portraits:tick() end
            self:paintArtLoading()
            if controller then controller:tick() end
            if self.exitOpen or self.settlementBusy then self:syncController();return true end
            if self.settlementRequested then self:animate(dt); return true end
            -- Count client update time within this run; menus/results never extend it.
            -- The terminal rule state can precede the last feedback animation.
            if not countRunTime(self,dt,openingCovered) then return false,"invalid_delta" end
            self:animate(dt)
            if self.prologue then self.prologue:update(dt) end
            if openingCovered() then self:syncController();return true end
            return advancePages(dt)
        end
end

function M.disable(self,platform,controller,characterPanel,owner)
    return function(_)
            local wasDisabled=self.disabled
            self.disabled=true
            local eggReleased,eggReason=true,nil
            if self.easterEgg then eggReleased,eggReason=pcall(self.easterEgg.release,self.easterEgg)end
            if wasDisabled then
                if self.monsterCleanupPending then self.battleUI:releaseMonsterSurfaces();self.monsterCleanupPending=nil end
                assert(eggReleased,eggReason)
                return false
            end
            if platform.background then platform.background:release() end
            if platform.portraits then platform.portraits:release() end
            if platform.cardArt then platform.cardArt.clear() end
            if self.prologue then self.prologue:cancel() end
            if controller then controller:disable() end
            owner.exitGeneration=owner.exitGeneration+1;owner.menuGeneration=owner.menuGeneration+1
            self.characterOpen=false
            if characterPanel then characterPanel:SetVisible(false) end
            -- Set every controller inert before cancelling feedback: cancellation
            -- invokes its completion callback synchronously, which now cannot refresh.
            self.battleUI.active=false
            self.mapUI:setVisible(false)
            self.nodeUI:setVisible(false)
            if self.choiceUI then self.choiceUI:close() end
            self.potionUI:close();self.deckUI:close()
            self.battleUI.feedback:cancel()
            local released,reason=pcall(self.battleUI.releaseMonsterSurfaces,self.battleUI)
            self.monsterCleanupPending=not released or nil
            assert(released,reason)
            assert(eggReleased,eggReason)
            return true
        end
end

return M
