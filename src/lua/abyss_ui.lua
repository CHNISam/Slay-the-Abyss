local GameUI = require("abyss_game_ui")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local view
function OnStart()
    view = GameUI.new(script.object, Data, Presentation, Enum.CursorEventType.CursorClick)
    print("ABYSS_UI ready")
end
