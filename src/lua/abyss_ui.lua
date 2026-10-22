local GameUI = require("abyss_game_ui")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Viewport = require("abyss_viewport")
local view
local canvasWidth, canvasHeight
function OnStart()
    if view then return end
    local width, height = game.GetUICanvasSize()
    local stage = Viewport.apply(script.object, width, height)
    view = GameUI.new(stage, Data, Presentation, Enum.CursorEventType.CursorClick,
        { color = Color, imageSource = Enum.ImageSource.StaticReference })
    view:resize(width, height)
    canvasWidth, canvasHeight = width, height
    script:EnableUpdate(true)
    print("ABYSS_UI ready")
end
function OnUpdate(dt)
    if not view then return end
    local width, height = game.GetUICanvasSize()
    if width ~= canvasWidth or height ~= canvasHeight then
        Viewport.apply(script.object, width, height)
        view:resize(width, height)
        canvasWidth, canvasHeight = width, height
    end
    view:update(dt)
end
