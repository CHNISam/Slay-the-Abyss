-- Host for the same-run map, node and battle controllers. Only commands change rules.
local Run = require("abyss_run")
local Map = require("abyss_map")
local Nodes = require("abyss_nodes")
local BattleUI = require("abyss_battle_ui")
local MapUI = require("abyss_map_ui")
local NodeUI = require("abyss_node_ui")
local Theme = require("abyss_theme")
local M = {}

function M.new(root, data, presentation, clickEvent, platform)
    local self = { root = root, data = data, seed = 1, mode = "menu" }
    local function child(name) return assert(root:GetChild(name), "missing game panel " .. name) end
    local menu = child("menuPanel")
    local ready = false
    local function changed() if ready then self:refresh() end end
    self.battleUI = BattleUI.new(child("battlePanel"), data, presentation, clickEvent,
        platform, { embedded = true, onChange = changed })
    self.mapUI = MapUI.new(child("mapPanel"), Map.generate(data, self.seed), function(node)
        if not self.run or self.mode ~= "map" then return false, "not_on_map" end
        local ok, reason = Nodes.enter(self.run, self.map, node.id)
        if ok then changed() end
        return ok, reason
    end, clickEvent, { embedded = true, color = platform.color, imageSource = platform.imageSource })
    self.nodeUI = NodeUI.new(child("nodePanel"), Run.new(data, self.seed), self.mapUI.map,
        presentation, clickEvent, changed)

    function self:refresh()
        local run = self.run
        if run and run.phase == "map" and run.nodeFlow and not run.nodeFlow.complete then
            Nodes.completeCombat(run, self.map)
        end
        if self.battleUI.busy then self.mode = "battle"
        elseif not run then self.mode = "menu"
        elseif run.phase == "defeat" then self.mode = "defeat"
        elseif run.nodeFlow and run.nodeFlow.complete and run.nodeFlow.result == "boss_victory" then self.mode = "victory"
        elseif run.phase == "combat" or run.phase == "reward" then self.mode = "battle"
        elseif run.phase == "node" then self.mode = "node"
        else self.mode = "map" end
        local inMenu = self.mode == "menu" or self.mode == "defeat" or self.mode == "victory"
        local result = self.mode == "defeat" or self.mode == "victory"
        local startFrame = result and Theme.layout.nativeMenu.resultRestart or Theme.layout.nativeMenu.start
        menu:GetChild("start"):SetAnchoredPosition(startFrame[1], startFrame[2])
        menu:GetChild("start"):SetVisible(not self.settlementRequested and not self.settlementBusy)
        menu:GetChild("settle"):SetVisible(result)
        local enabled = result and type(platform.settle) == "function" and not self.settlementRequested and not self.settlementBusy
        local settlement = menu:GetChild("settle")
        settlement:GetChild("normal"):SetVisible(enabled == true)
        settlement:GetChild("disabled"):SetVisible(not enabled)
        settlement:GetChild("selected"):SetVisible(false)
        settlement:GetChild("label").text = self.settlementRequested and "已发送结算请求" or "结束并结算"
        menu:SetVisible(inMenu)
        self.battleUI:setActive(self.mode == "battle")
        self.mapUI:setVisible(self.mode == "map")
        self.nodeUI:setVisible(self.mode == "node")
        if self.mode == "battle" then self.battleUI:render()
        elseif self.mode == "map" then
            self.mapUI:setNavigationEnabled(#Nodes.available(run, self.map) > 0)
        elseif self.mode == "node" then self.nodeUI:render()
        elseif inMenu then
            menu:GetChild("start"):GetChild("label").text = run and "重新启程" or "启程"
            if self.mode == "menu" then
                menu:GetChild("summary").text = "规划路线，构筑卡组\n穿越十五层深渊，挑战终点首领\n\n先点选卡牌，再点敌人；无需目标的牌再点一次确认"
            else
                local title = self.mode == "victory" and "首领已击败" or "旅途暂歇"
                local hp = run.phase == "defeat" and 0 or run.hp
                local seconds = math.floor(run.elapsedSeconds)
                local duration = string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
                menu:GetChild("summary").text = title .. " · 用时 " .. duration
                    .. "\n抵达第 " .. self.map.floor .. " / 15 层 · 胜场 " .. run.victories
                    .. "\n生命 " .. hp .. " / " .. run.maxHp .. " · 金币 " .. run.gold
                    .. "\n卡组 " .. #run.deck .. " 张 · 遗物 " .. #run.relics .. " 件"
                if self.settlementError then
                    menu:GetChild("summary").text = menu:GetChild("summary").text .. "\n结算请求失败，请重试"
                elseif type(platform.settle) ~= "function" then
                    menu:GetChild("summary").text = menu:GetChild("summary").text .. "\n平台结算暂不可用"
                end
            end
        end
    end
    function self:start()
        if self.settlementRequested or self.settlementBusy then return false end
        if self.mode ~= "menu" and self.mode ~= "defeat" and self.mode ~= "victory" then return false end
        self.run, self.map = Run.new(data, self.seed), Map.generate(data, self.seed)
        self.settlementRequested, self.settlementBusy, self.settlementError = false, false, nil
        self.seed = (self.seed + 1) % 65536
        self.battleUI.run, self.battleUI.target = self.run, 1
        self.mapUI.map = self.map
        self.nodeUI.run, self.nodeUI.map = self.run, self.map
        self:refresh()
        return true
    end
    function self:settle()
        if self.mode ~= "victory" and self.mode ~= "defeat" then return false, "not_result" end
        if self.settlementRequested or self.settlementBusy then return false, "settlement_already_requested" end
        if type(platform.settle) ~= "function" then return false, "settlement_unavailable" end
        self.settlementBusy = true
        local called, accepted = pcall(platform.settle, self.mode == "victory")
        self.settlementBusy = false
        if not called or accepted == false then
            self.settlementError = true
            self:refresh()
            return false, "settlement_request_failed"
        end
        self.settlementRequested, self.settlementError = true, nil
        self:refresh()
        return true, "settlement_requested"
    end
    function self:resize(width, height)
        self.battleUI:resize(width, height)
        self.mapUI:resize(width, height)
    end
    function self:update(dt)
        if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt == math.huge then
            return false, "invalid_delta"
        end
        -- Count client update time within this run; menus/results never extend it.
        -- The terminal rule state can precede the last feedback animation.
        local run = self.run
        if run and run.phase ~= "defeat" and self.mode ~= "victory" and self.mode ~= "defeat" then
            local elapsed = run.elapsedSeconds + dt
            if elapsed == math.huge then return false, "invalid_delta" end
            run.elapsedSeconds = elapsed
        end
        self.battleUI:update(dt)
        return self.mapUI:update(dt)
    end
    menu:GetChild("start"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:start() end)
    menu:GetChild("settle"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return self:settle() end)
    ready = true
    self:refresh()
    return self
end
return M
