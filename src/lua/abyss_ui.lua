local view, Viewport, background, cardArt, portraits
local canvasWidth, canvasHeight
local attempted = false
local function failed(phase, reason)
    print("ABYSS_UI failed " .. phase .. ": " .. tostring(reason))
    if portraits then pcall(function()portraits:release()end) end
    if cardArt then pcall(cardArt.clear) end
    if background then pcall(function()background:release()end) end
    if view then
        local cleaned,why=pcall(function()view:disable()end)
        if cleaned then view=nil else print('ABYSS_UI cleanup_failed '..tostring(why))end
    end
    script:EnableUpdate(false)
    pcall(function()
        local stage = script.object:GetChild("stage")
        for _, name in ipairs({"battlePanel", "mapPanel", "nodePanel", "deckEntry", "deckPanel",
            "characterPanel", "choicePanel", "potionPanel", "potionEntry", "prologuePanel", "exitPanel", "exitEntry", "combatRewards", "victoryEasterEgg"}) do
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
-- One immutable candidate snapshot; never sourced from player parameters or polled.
local function artFeatures()
    local flags = {cards=false,menuBackground=false,selectionAvatar=false,battlePortrait=false,monsters=false}
    local ok, value = pcall(function()
        local config = require("abyss_art_features")
        assert(type(config)=='table' and config.schemaVersion==2 and type(config.flags)=='table', 'invalid art feature schema')
        for key in pairs(config) do
            assert(key=='schemaVersion' or key=='flags', 'unknown art config field '..tostring(key))
        end
        local snapshot = {}
        for key in pairs(flags) do
            assert(type(config.flags[key])=='boolean', 'invalid art feature '..key)
            snapshot[key] = config.flags[key]
        end
        for key in pairs(config.flags) do assert(flags[key]~=nil, 'unknown art feature '..tostring(key)) end
        return snapshot
    end)
    if ok then return value end
    print('ABYSS_ART config=default_off reason='..tostring(value))
    return flags
end
local function optionalArt(name, create)
    local ok, value = pcall(create)
    if ok then return value end
    print('ABYSS_ART '..name..' phase=unavailable reason='..tostring(value))
end
local function boundIndex(value)
    return type(value)=='number' and value>0 and value<math.huge and value%1==0
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
        local flags = artFeatures()
        local createEasterEggArt
        if not flags.cards then
            -- Legacy static candidates embed nativeArt in presentation. Suppress
            -- that route too, without mutating the cached source for another world.
            local official = {}
            for id, entry in pairs(Presentation) do
                if type(entry)=='table' and entry.nativeArt~=nil then
                    local copy = {}
                    for key, value in pairs(entry) do if key~='nativeArt' then copy[key]=value end end
                    official[id]=copy
                else official[id]=entry end
            end
            Presentation = official
        end
        -- CardDisplay already loads this small shared lifecycle module. Reset
        -- prior ownership even when off; nil cannot create or load asset data.
        -- Use native require, not the desktop-only package.loaded assumption.
        require("abyss_card_art_runtime").configure(nil)
        if flags.menuBackground then
            createEasterEggArt=function()
                local factory=require('abyss_traveler_portraits').createController
                return require('abyss_menu_background').new(stage,print,factory,Color,{standalone=true})
            end
        end
        if flags.selectionAvatar or flags.battlePortrait then
            portraits = optionalArt('portraits', function()return require("abyss_traveler_portraits").new(stage, print, flags)end)
        end
        if flags.cards then
            cardArt = optionalArt('cards', function()
                local binding = require("abyss_ready_card_binding")
                if type(binding)~='table' or binding.enabled~=true
                    or not boundIndex(binding.imageTemplateIndex) or not boundIndex(binding.containerTemplateIndex) then return nil end
                local assets = require("abyss_ready_card_assets")
                local runtime = require("abyss_card_art_runtime")
                -- Validate/bind first, so missing payload cannot enable creation.
                require("abyss_card_display").bindNativeAssets(Presentation, assets)
                runtime.configure({instantiate=game.InstantiateClientUIControl,destroy=game.DestroyClientUIControl,
                    imageTemplateIndex=binding.imageTemplateIndex,containerTemplateIndex=binding.containerTemplateIndex})
                return runtime
            end)
        end
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
              createEasterEggArt=createEasterEggArt,
              characterProfile = (alpha or isTest and testPlay == true) and "competition-candidate" or "production",
              controllerApi = {events=Enum.ControllerNavigationEventType,directions=Enum.ControllerNavigationDir,
                  modes=Enum.ControllerNavigationMode,getFocus=game.GetControllerFocus,setFocus=game.SetControllerFocus,
                  isController=function()
                      local device=game.GetDevice()
                      return device==Enum.Device.Controller or device==Enum.Device.MobileController
                  end},
              monsterActors=setmetatable({instantiate=game.InstantiateClientUIControl,destroy=game.DestroyClientUIControl},
                  {__index=require('abyss_monster_actor_binding')}),
              nativeMonsterArtEnabled=flags.monsters,
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
    if not view or view.disabled then return end
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
    if view then pcall(function()view:onEngineDestroy()end) end
    if cardArt then cardArt.onEngineDestroy() end
    if portraits then portraits:onEngineDestroy() end
    if background then background:onEngineDestroy() end
    background, portraits, cardArt, view = nil, nil, nil, nil
    script:EnableUpdate(false)
end
