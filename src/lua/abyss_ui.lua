local BattleUI = require("abyss_battle_ui")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local view
function OnStart()
    view = BattleUI.new(script.object, Data, Presentation, Enum.CursorEventType.CursorClick,
        { color = Color, imageSource = Enum.ImageSource.StaticReference })
    local width, height = game.GetUICanvasSize()
    view:resize(width, height)
    script:EnableUpdate(true)
    print("ABYSS_UI ready")
end
function OnUpdate()
    local width, height = game.GetUICanvasSize()
    if view and (width ~= view.canvasWidth or height ~= view.canvasHeight) then view:resize(width, height) end
end
