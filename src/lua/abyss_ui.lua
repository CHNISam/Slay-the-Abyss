local view, Viewport
local canvasWidth, canvasHeight
local attempted = false
local function failed(phase, reason)
    print("ABYSS_UI failed " .. phase .. ": " .. tostring(reason))
    view = nil
    script:EnableUpdate(false)
    pcall(function()
        local stage = script.object:GetChild("stage")
        for _, name in ipairs({"battlePanel", "mapPanel", "nodePanel"}) do
            stage:GetChild(name):SetVisible(false)
        end
        local menu = stage:GetChild("menuPanel")
        menu:SetVisible(true)
        menu:GetChild("start"):SetVisible(false)
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
        Viewport = require("abyss_viewport")
        local width, height = game.GetUICanvasSize()
        local stage = Viewport.apply(script.object, width, height)
        print("ABYSS_UI viewport_ready")
        view = GameUI.new(stage, Data, Presentation, Enum.CursorEventType.CursorClick,
            { color = Color, imageSource = Enum.ImageSource.StaticReference })
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
