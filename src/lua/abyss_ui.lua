local view, Viewport
local canvasWidth, canvasHeight
local attempted = false
local function failed(phase, reason)
    print("ABYSS_UI failed " .. phase .. ": " .. tostring(reason))
    if view then pcall(function()view:disable()end) end
    view = nil
    script:EnableUpdate(false)
    pcall(function()
        local stage = script.object:GetChild("stage")
        for _, name in ipairs({"battlePanel", "mapPanel", "nodePanel", "deckEntry", "deckPanel",
            "characterPanel", "choicePanel", "potionPanel", "potionEntry", "prologuePanel", "releaseNotesPanel", "exitPanel", "exitEntry", "combatRewards"}) do
            local panel=stage:GetChild(name)
            if panel then panel:SetVisible(false) end
        end
        local menu = stage:GetChild("menuPanel")
        menu:SetVisible(true)
        menu:SetAsLastSibling()
        menu:GetChild("start"):SetVisible(false)
        local notices, codeVersion = menu:GetChild('releaseNotes'), menu:GetChild('codeVersion')
        if notices then notices:SetVisible(false) end
        if codeVersion then codeVersion:SetVisible(false) end
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
        print("ABYSS_UI viewport_ready")
        -- Opt in only on a candidate containing the ABYSS_BGM graph/signals.
        local hasBgm, enableBgm = pcall(function() return script:GetParam("nativeBgmEnabled") end)
        local hasClasses, enableClasses = pcall(function() return script:GetParam("experimentalCharacters") end)
        local music
        if hasBgm and enableBgm == true then
            music = function(signal)
                game.ServerSignal(signal):SendSignal()
                print("ABYSS_BGM_REQUEST " .. signal)
            end
        end
        view = GameUI.new(stage, Data, Presentation, Enum.CursorEventType.CursorClick,
            { music = music, experimentalCharacters = hasClasses and enableClasses==true, originalCharacters = not (hasClasses and enableClasses==true),
              controllerApi = {events=Enum.ControllerNavigationEventType,directions=Enum.ControllerNavigationDir,
                  modes=Enum.ControllerNavigationMode,getFocus=game.GetControllerFocus,setFocus=game.SetControllerFocus,
                  isController=function()
                      local device=game.GetDevice()
                      return device==Enum.Device.Controller or device==Enum.Device.MobileController
                  end},
              color = Color, imageSource = Enum.ImageSource.StaticReference, cursorEvents = Enum.CursorEventType, keyEvents = Enum.KeyEventType,
              cursorPosition = function() return game.GetCursorUIPos() end,
              touchScreen = function() return game.GetDevice() == Enum.Device.Mobile end,
              sound = function(cue)
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
        view:update(dt)
    end)
    if not ok then failed("update", reason) end
end
