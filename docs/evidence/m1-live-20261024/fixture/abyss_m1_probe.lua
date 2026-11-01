-- Diagnostic fixture only. Never included in the production script manifest.
local M = {}
local Actor = require("abyss_actor")
local Combat = require("abyss_combat")
local Run = require("abyss_run")
local cases = {"strength", "dexterity", "vulnerable", "weak", "frail", "poison", "thorns", "regen", "barricade"}
local names = {strength="力量",dexterity="敏捷",vulnerable="易伤",weak="虚弱",frail="脆弱",poison="中毒",thorns="荆棘",regen="再生",barricade="壁垒"}
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function M.new(view, data, stage)
    local self = {time=0, elapsed=0, index=0, step=0, view=view, phase="initial2-player"}
    local panel = stage:GetChild("battlePanel")
    local function note(message)
        panel:GetChild("notice").text = "M1验收夹具 · 非正常获取 / 非通关\n" .. message
        print("M1_PROBE_PHASE case=" .. self.index .. " phase=" .. self.phase .. " elapsed=" .. string.format("%.1f",self.elapsed))
    end
    local function detail(index)
        local ui, id = view.battleUI, cases[self.index]
        ui.help=nil -- A parked mouse must not replace the scripted evidence with a hover tooltip.
        local info=ui.info
        if not info or info.index~=index or info.statusId~=id or info.kind or info.transient then
            local before=Combat.copy(view.run)
            assert(ui:openHelp({index=index,statusId=id},nil,false),"M1 probe: detail did not open")
            assert(same(before,view.run),"M1 probe: opening detail changed the run")
        end
    end
    function self:record(label)
        local battle = view.run.combat
        local p, e = battle.player, battle.enemies[1]
        print("M1_PROBE " .. cases[self.index] .. " " .. label .. " elapsed=" .. string.format("%.1f",self.elapsed) .. " caseTime=" .. string.format("%.1f",self.time) .. " player=" .. tostring(p.statuses[cases[self.index]] or 0)
            .. " enemy=" .. tostring(e.statuses[cases[self.index]] or 0) .. " hp=" .. p.hp .. "/" .. e.hp .. " block=" .. p.block .. "/" .. e.block .. " turn=" .. battle.turn)
        local before = Combat.copy(view.run)
        view:refresh()
        view.battleUI:render()
        assert(same(before,view.run), "M1 probe: UI changed the run state")
        print("M1_PROBE readonly " .. cases[self.index] .. " " .. label)
    end
    function self:begin()
        self.index = self.index + 1
        self.step, self.time, self.phase = 0, 0, "initial2-player"
        if self.index > #cases then
            self.done=true
            note("九状态脚本流程完成，需逐图复核；此副本仅状态验收，不计入通关。")
            print("M1_PROBE complete 9")
            return
        end
        if view.battleUI.feedback then view.battleUI.feedback:cancel() end
        view.battleUI.busy, view.battleUI.displayBattle, view.battleUI.info = false, nil, nil
        local run = Run.new(data, 41)
        assert(Run.startCombat(run,"cultist_solo"))
        local battle = Combat.new(data,{seed=41,hp=60,deck={"strike","defend","defend","defend","strike"},enemies={"cultist"}})
        local enemy = battle.enemies[1]
        battle.player.statuses, enemy.statuses = {}, {}
        enemy.ai, enemy.intentIndex = nil, 1
        enemy.intents={{id="m1_probe_attack",kind="attack",effects={{op="damage",value=6}}}}
        enemy.hp = math.min(enemy.hp, enemy.maxHp - 10)
        battle.player.block, enemy.block = 7, 7
        run.combat, run.hp = battle, battle.player.hp
        view.run, view.battleUI.run = run, run
        view.nodeUI.run, view.battleUI.target, view.battleUI.selected = run, 1, nil
        for _, actor in ipairs({battle.player,enemy}) do Actor.addStatus(actor,cases[self.index],2) end
        self:record("initial2")
        detail(0)
        note(self.index .. "/9 " .. names[cases[self.index]] .. " 初始：双方2（壁垒1）；玩家详情")
    end
    function self:update(dt)
        if self.done then return end
        self.time = self.time + dt
        self.elapsed = self.elapsed + dt
        view.battleUI.help=nil
        local battle = view.run.combat
        if self.step == 0 and self.time >= 4 then
            self.step=1
            self.phase="initial2-enemy"
            view.battleUI.info=nil
            self:record("initial2-enemy")
            detail(1)
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 初始：双方2（壁垒1）；敌人详情")
        elseif self.step == 1 and self.time >= 8 then
            self.step=2
            self.phase="stacked5-player"
            for _, actor in ipairs({battle.player,battle.enemies[1]}) do Actor.addStatus(actor,cases[self.index],3) end
            view.battleUI.info=nil
            self:record("stacked5")
            detail(0)
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 叠加：双方5（壁垒1）；玩家详情")
        elseif self.step == 2 and self.time >= 12 then
            self.step=3
            self.phase="stacked5-enemy"
            view.battleUI.info=nil
            self:record("stacked5-enemy")
            detail(1)
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 叠加：双方5（壁垒1）；敌人详情")
        elseif self.step == 3 and self.time >= 16 then
            self.step=4
            self.phase="defend"
            view.battleUI.info=nil
            view.battleUI:render()
            for i, card in ipairs(battle.hand) do
                if card.cardId == "defend" then
                    view.battleUI:playSlot(i)
                    view.battleUI:playSlot(i)
                    break
                end
            end
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 真实防御牌：敏捷/脆弱及格挡动画")
        elseif self.step == 4 and self.time >= 21 and not view.battleUI.busy then
            self.step=5
            self.phase="strike"
            for i, card in ipairs(battle.hand) do
                if card.cardId == "strike" then
                    view.battleUI:playSlot(i)
                    view.battleUI:playSelected(1)
                    break
                end
            end
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 真实攻击牌：力量/虚弱/易伤及荆棘触发")
        elseif self.step == 5 and self.time >= 27 and not view.battleUI.busy then
            self.step=6
            self.phase="endTurn"
            view.battleUI:endTurn()
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 真实结束回合：敌方行动及状态触发/衰减")
        elseif self.step == 6 and self.time >= 35 and not view.battleUI.busy then
            self.step=7
            self.phase="afterTurn-player"
            self.afterAt=self.time
            assert(battle.turn==2 and battle.phase=="player", "M1 probe: real endTurn did not finish")
            local id=cases[self.index]
            local expected=(id=="barricade" and 1) or ((id=="strength" or id=="dexterity" or id=="thorns") and 5) or 4
            for _,actor in ipairs({battle.player,battle.enemies[1]}) do
                assert(actor.statuses[id]==expected,"M1 probe: unexpected post-turn "..id.."="..tostring(actor.statuses[id]))
            end
            self:record("afterTurn")
            detail(0)
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 回合后：永久保留；持续/毒/再生减1；玩家详情")
        elseif self.step == 7 and self.time >= self.afterAt+4 then
            self.step=8
            self.phase="afterTurn-enemy"
            view.battleUI.info=nil
            self:record("afterTurn-enemy")
            detail(1)
            note(self.index .. "/9 " .. names[cases[self.index]] .. " 回合后；敌人详情（同一真实回合）")
        elseif self.step == 8 and self.time >= self.afterAt+8 then
            view.battleUI.info=nil
            self:begin()
        end
        if not self.done then
            if self.phase:find("-player",1,true) then detail(0)
            elseif self.phase:find("-enemy",1,true) then detail(1) end
        end
    end
    self:begin()
    return self
end
return M
