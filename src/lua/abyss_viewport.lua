local Theme = require("abyss_theme")
local M = {}

function M.apply(root, width, height)
    assert(type(width) == "number" and width > 0 and width < math.huge, "invalid canvas width")
    assert(type(height) == "number" and height > 0 and height < math.huge, "invalid canvas height")
    local scale = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
    local stage = assert(root:GetChild("stage"), "missing stage")
    -- The generated backdrop stretches with horizontal bleed beyond its native parent.
    -- Canvas dimensions belong only to the uniformly scaled content stage.
    assert(root:GetChild("canvasBackdrop"), "missing canvas backdrop")
    stage:SetLocalScale(scale, scale, 1)
    return stage, scale
end
return M
