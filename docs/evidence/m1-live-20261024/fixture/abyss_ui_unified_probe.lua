local probe, blockProbe, previewProbe
local probeStage
local view, Viewport
local canvasWidth, canvasHeight
local attempted = false
local function failed(phase, reason)
    print("ABYSS_UI failed " .. phase .. ": " .. tostring(reason))
    view = nil
    script:EnableUpdate(false)
    pcall(function()
        local stage = script.object:GetChild("stage")
        for _, name in ipairs({"battlePanel", "mapPanel", "nodePanel", "deckEntry", "deckPanel"}) do
            stage:GetChild(name):SetVisible(false)
        end
        local menu = stage:GetChild("menuPanel")
        menu:SetVisible(true)
        menu:GetChild("start"):SetVisible(false)
        local settle = menu:GetChild("settle")
        if settle then settle:SetVisible(false) end
        local result = menu:GetChild("result")
        if result then result:SetVisible(false) end
        menu:GetChild("summary"):SetVisible(true)
        local message = "关卡启动失败，请退出后重新进入。"
        if game.IsTestPlay and game.IsTestPlay() then
            message = message .. "\n测试诊断 · " .. phase .. "\n" .. tostring(reason)
        end
        menu:GetChild("summary").text = message
    end)
end
function OnStart()
    if attempted then return end
    attempted = true
    local ok, reason = pcall(function()
        print("ABYSS_UI init Color=" .. type(Color))
        local GameUI = require("abyss_game_ui")
        local Data = require("abyss_data")
        local Presentation = require("abyss_presentation")
        local Theme = require("abyss_theme")
        Viewport = require("abyss_viewport")
        local width, height = game.GetUICanvasSize()
        local stage = Viewport.apply(script.object, width, height)
        -- Fixture-only facade records the production listeners while forwarding
        -- every real registration, native method and property access unchanged.
        stage = require("abyss_preview_probe").capture(stage, Enum.CursorEventType)
        probeStage = stage
        print("ABYSS_UI viewport_ready")
        -- Opt in only on a candidate containing the ABYSS_BGM graph/signals.
        local hasBgm, enableBgm = pcall(function() return script:GetParam("nativeBgmEnabled") end)
        local music
        if hasBgm and enableBgm == true then
            music = function(signal)
                game.ServerSignal(signal):SendSignal()
                print("ABYSS_BGM_REQUEST " .. signal)
            end
        end
        view = GameUI.new(stage, Data, Presentation, Enum.CursorEventType.CursorClick,
            { music = music, color = Color, imageSource = Enum.ImageSource.StaticReference, cursorEvents = Enum.CursorEventType, sound = function(cue)
                local id = Theme.sound[cue]
                if id and game.PlayAudio2D then
                    local instance = game.PlayAudio2D(id)
                    print("ABYSS_AUDIO " .. cue .. " id=" .. id .. " instance=" .. tostring(instance))
                end
            end, settle = function(victory)
                if victory then game.ServerSignal("ABYSS_WIN"):SendSignal()
                else game.ServerSignal("ABYSS_LOSE"):SendSignal() end
                print("ABYSS_UI settlement_requested " .. (victory and "victory" or "defeat"))
                return true
            end })
        view:resize(width, height)
        canvasWidth, canvasHeight = width, height
        script:EnableUpdate(true)
        print("ABYSS_UI ready")
        probe = require("abyss_m1_probe").new(view, Data, stage)
    end)
    if not ok then failed("startup", reason) end
end
function OnUpdate(dt)
    if not view then return end
    local ok, reason = pcall(function()
        local width, height = game.GetUICanvasSize()
        if width ~= canvasWidth or height ~= canvasHeight then
            Viewport.apply(script.object, width, height)
            view:resize(width, height)
            canvasWidth, canvasHeight = width, height
        end
        if previewProbe then
            previewProbe:update(dt)
        elseif blockProbe then
            blockProbe:update(dt)
            if blockProbe.done then
                print('M1_UNIFIED_PHASE preview')
                previewProbe = require('abyss_preview_probe').new(view, require('abyss_data'), probeStage)
            end
        else
            view:update(dt)
            if probe then probe:update(dt) end
            if probe and probe.done then
                print('M1_UNIFIED_PHASE block')
                blockProbe = require('abyss_block_probe').new(view, require('abyss_data'), probeStage)
            end
        end
    end)
    if not ok then failed("update", reason) end
end
