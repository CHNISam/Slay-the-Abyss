local Theme = require("abyss_theme")
local M = {}

function M.apply(root, width, height)
    assert(type(width) == "number" and width > 0 and width < math.huge, "invalid canvas width")
    assert(type(height) == "number" and height > 0 and height < math.huge, "invalid canvas height")
    local scale = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
    local stage = assert(root:GetChild("stage"), "missing stage")
    local backdrop = assert(root:GetChild("canvasBackdrop"), "missing canvas backdrop")
    backdrop:SetSizeDelta(width, height)
    stage:SetLocalScale(scale, scale, 1)
    return stage, scale
end
return M
