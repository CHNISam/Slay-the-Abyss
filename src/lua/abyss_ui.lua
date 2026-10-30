local view, Viewport, background, cardArt, portraits
local canvasWidth, canvasHeight
local attempted = false
local function failed(phase, reason)
    print("ABYSS_UI failed " .. phase .. ": " .. tostring(reason))
    if portraits then pcall(function()portraits:release()end) end
    if cardArt then pcall(cardArt.clear) end
    if background then pcall(function()background:release()end) end
    if view then pcall(function()view:disable()end) end
    view = nil
    script:EnableUpdate(false)
    pcall(function()
        local stage = script.object:GetChild("stage")
        for _, name in ipairs({"battlePanel", "mapPanel", "nodePanel", "deckEntry", "deckPanel",
            "characterPanel", "choicePanel", "potionPanel", "potionEntry", "prologuePanel", "exitPanel", "exitEntry", "combatRewards"}) do
            local panel=stage:GetChild(name)
            if panel then panel:SetVisible(false) end
        end
        local menu = stage:GetChild("menuPanel")
        menu:SetVisible(true)
        menu:SetAsLastSibling()
        menu:GetChild("start"):SetVisible(false)
        local codeVersion = menu:GetChild('codeVersion')
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
        background = require("abyss_menu_background").new(stage, print)
        portraits = require("abyss_traveler_portraits").new(stage, print)
        cardArt = require("abyss_card_art_runtime")
        local artBinding = require("abyss_ready_card_binding")
        if artBinding.enabled and artBinding.imageTemplateIndex > 0 and artBinding.containerTemplateIndex > 0 then
            cardArt.configure({instantiate=game.InstantiateClientUIControl,destroy=game.DestroyClientUIControl,
                imageTemplateIndex=artBinding.imageTemplateIndex,containerTemplateIndex=artBinding.containerTemplateIndex})
            require("abyss_card_display").bindNativeAssets(Presentation,require("abyss_ready_card_assets"))
        else cardArt.configure(nil) end
        -- Opt in only on a candidate containing the ABYSS_BGM graph/signals.
        local hasBgm, enableBgm = pcall(function() return script:GetParam("nativeBgmEnabled") end)
        local music
        if hasBgm and enableBgm == true then
            music = function(signal)
                game.ServerSignal(signal):SendSignal()
                print("ABYSS_BGM_REQUEST " .. signal)
            end
        end
        local isTest, testPlay = pcall(function()return game.IsTestPlay()end)
        local build = require('abyss_narrative').build
        local alpha = type(build)=='table' and build.workKey=='alpha-test'
        view = GameUI.new(stage, Data, Presentation, Enum.CursorEventType.CursorClick,
            { background = background, portraits = portraits, cardArt = cardArt, music = music, campaign = true, campaignProfile = "competition-two-act",
              characterProfile = (alpha or isTest and testPlay == true) and "competition-candidate" or "production",
              controllerApi = {events=Enum.ControllerNavigationEventType,directions=Enum.ControllerNavigationDir,
                  modes=Enum.ControllerNavigationMode,getFocus=game.GetControllerFocus,setFocus=game.SetControllerFocus,
                  isController=function()
                      local device=game.GetDevice()
                      return device==Enum.Device.Controller or device==Enum.Device.MobileController
                  end},
              color = Color, imageSource = Enum.ImageSource.StaticReference, cursorEvents = Enum.CursorEventType, keyEvents = Enum.KeyEventType,
              imageTypes = Enum.ImageType and {basic=Enum.ImageType.Basic,stretch=Enum.ImageType.Stretch},
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
        if cardArt then cardArt.update() end
    end)
    if not ok then failed("update", reason) end
end

function OnDestroy()
    if cardArt then pcall(cardArt.clear) end
    if portraits then portraits:onEngineDestroy() end
    if background then background:onEngineDestroy() end
    background, portraits, cardArt, view = nil, nil, nil, nil
    script:EnableUpdate(false)
end
