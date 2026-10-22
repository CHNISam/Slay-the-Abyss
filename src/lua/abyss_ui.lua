local GameUI = require("abyss_game_ui")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Viewport = require("abyss_viewport")
local view
function OnStart()
    if view then return end
    local width, height = game.GetUICanvasSize()
    local stage = Viewport.apply(script.object, width, height)
    view = GameUI.new(stage, Data, Presentation, Enum.CursorEventType.CursorClick)
    print("ABYSS_UI ready")
end
