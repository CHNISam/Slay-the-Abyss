-- TASK-4.1 diagnostic fixture. Never part of the production manifest.
-- Owns view:update so production feedback can pause at three actual ages.
local M = {}
local Combat, Run = require("abyss_combat"), require("abyss_run")
local marks = {0.02, 0.10, 0.30}
function M.new(view, data, stage)
    local self = {view=view, data=data, case=0, wall=0, phase="boot", hold=0, ownsUpdates=true, samples=0, completed=0}
    local ui, panel = view.battleUI, stage:GetChild("battlePanel")
    local function log(phase, detail)
        self.phase = phase
        panel:GetChild("notice").text = "格挡验收夹具 · 非自然战斗 / 时间线暂停取帧\n" .. self.case .. "/6 " .. phase .. " " .. (detail or "")
        print("M1_BLOCK case=" .. self.case .. " phase=" .. phase .. " wall=" .. string.format("%.2f",self.wall) .. " " .. (detail or ""))
    end
    local function startCase()
        if ui.feedback then ui.feedback:cancel() end
        self.case = self.case + 1
        if self.case > 6 then
            self.done = true
            log("complete", "cases=6 samples=" .. self.samples .. " cancelled=" .. self.completed)
            return
        end
        local enemies = {}
        for i=1,math.min(self.case,5) do enemies[i]="cultist" end
        if self.case==6 then enemies={"guardian"} end
        local run=Run.new(data,41)
        assert(Run.startCombat(run,"cultist_solo"))
        local battle=Combat.new(data,{seed=41,hp=60,deck={"defend","defend","defend","defend","defend"},enemies=enemies})
        battle.player.block=7
        for _,enemy in ipairs(battle.enemies) do
            enemy.ai,enemy.intentIndex,enemy.block=nil,1,7
            enemy.intents={{id="block_probe_defend",kind="defend",effects={{op="block",value=5}}}}
        end
        run.combat,run.hp=battle,battle.player.hp
        view.run,ui.run,view.nodeUI.run=run,run,run
        ui.busy,ui.displayBattle,ui.info,ui.help,ui.selected,ui.target=false,nil,nil,nil,nil,1
        view:refresh();ui:render()
        self.action,self.actionStarted,self.track,self.seen=1,false,nil,{}
        self.hold=1
        log("baseline", "enemies="..#battle.enemies.." boss="..tostring(self.case==6).." hp="..battle.player.hp.." block=7")
    end
    local function defend()
        for slot,card in ipairs(view.run.combat.hand) do
            if card.cardId=="defend" then
                ui:playSlot(slot);ui:playSlot(slot)
                assert(ui.busy,"probe Defend did not start production feedback")
                return
            end
        end
        error("probe has no Defend")
    end
    local function beginAction()
        self.actionStarted,self.seen,self.track=true,{},nil
        if self.action==1 then log("player-gain");defend()
        elseif self.action==2 then log("enemy-gain");ui:endTurn()
        elseif self.action==3 then
            -- Explicit fixture state, then genuine Defend and End Turn commands.
            view.run.combat.player.block=7
            view:refresh();ui:render()
            log("player-gain-before-absorb");defend()
        elseif self.action==4 then
            local battle=view.run.combat
            for i,enemy in ipairs(battle.enemies) do
                enemy.intents={{id="block_probe_hit",kind="attack",effects={{op="damage",value=i==1 and 6 or 0}}}}
                enemy.intentIndex=1
            end
            view:refresh();ui:render()
            log("absorption");ui:endTurn()
        elseif self.action==5 then log("cancel-active-block");defend()
        else startCase() end
    end
    function self:update(dt)
        if self.done then return end
        self.wall=self.wall+dt
        if self.hold>0 then self.hold=self.hold-dt;return end
        if self.cancelAfterHold then
            self.cancelAfterHold=false
            ui.feedback:cancel()
            assert(not ui.busy,"cancel failed to unlock production UI")
            self.completed=self.completed+1
            log("cancelled-restored", "hp="..view.run.combat.player.hp.." block="..view.run.combat.player.block)
            self.hold=1.25
            self.action,self.actionStarted,self.track=6,false,nil
            return
        end
        if not self.actionStarted then beginAction();return end
        -- Advance the real renderer only in small fixed steps. Wall-clock pauses
        -- are diagnostic capture holds, not a performance/real-time claim.
        view:update(math.min(dt,0.02))
        local feedback=ui.feedback
        if not self.track then
            for id,effect in pairs(feedback.effects) do
                if not self.seen[effect] and (effect.kind=="block" or (effect.detail.blocked or 0)>0) then
                    self.seen[effect]=true
                    self.track={id=id,effect=effect,mark=1}
                    break
                end
            end
        end
        local track=self.track
        if track and track.effect.age>=marks[track.mark] then
            local actor=track.id=="player" and (ui.displayBattle or view.run.combat).player
            if not actor then for _,enemy in ipairs((ui.displayBattle or view.run.combat).enemies) do if enemy.id==track.id then actor=enemy end end end
            assert(actor,"missing displayed actor")
            self.samples=self.samples+1
            log("sample", "action="..self.action.." actor="..track.id.." kind="..track.effect.kind.." age="..string.format("%.3f",track.effect.age).." hp="..actor.hp.." block="..actor.block)
            self.hold=0.75
            if self.action==5 then self.cancelAfterHold=true;return end
            track.mark=track.mark+1
            if track.mark>#marks then self.track=nil end
            return
        end
        if not ui.busy and next(feedback.effects)==nil then
            log("action-restored", "action="..self.action.." hp="..view.run.combat.player.hp.." block="..view.run.combat.player.block)
            self.action,self.actionStarted=self.action+1,false
            self.hold=0.75
        end
    end
    startCase()
    return self
end
return M
