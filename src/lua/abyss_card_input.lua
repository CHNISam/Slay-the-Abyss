-- Behavioral translation of AbstractPlayer.updateInput/clickAndDragCards/
-- updateSingleTargetInput, pinned ButterflyGame fc379c875c11 (see port report).
-- Coordinates here are centered, Y-up. Original constants use a 1920x1080 base.
-- Native event ownership, card rules and rendering remain in their adapters.
local M = {}
function M.begin(g, height, touchScreen, width)
    g.touchScreen, g.width = touchScreen == true, width
    g.sourceScale = height / 1080
    g.hoverStartLine = g.sy + 140 * g.sourceScale
    g.dropStart = -height / 2 + (g.touchScreen and 350 or 300) * g.sourceScale
    g.dropEnd = height * 0.31 -- Settings.CARD_DROP_END_Y = HEIGHT * .81
    g.cancelFloor = -height / 2 + 50 * g.sourceScale
    g.elapsed = 0
end
function M.sample(g, x, y, target, targeted)
    g.x, g.y = x, y
    -- updateInput: a living monster's hit box also counts as the drop zone.
    local above = g.touchScreen and y > g.dropStart or not g.touchScreen and (y > g.hoverStartLine or y > g.dropStart)
    g.dropZone = target ~= nil or above and y < g.dropEnd
    -- Native events can report off-canvas coordinates; never play outside the canvas.
    if g.width and math.abs(x) > g.width / 2 then g.dropZone = false end
    -- The native hand sits above the source's bottom-edge cancellation floor.
    -- Once lifted into the field, returning to that visible hand row is an
    -- explicit cancel, including a quick no-target return before 0.4 seconds.
    if g.dropZone then g.enteredField = true end
    if g.enteredField and g.handCancelY and y <= g.handCancelY then g.cancelled = true end
    if targeted and g.dropZone then g.aiming = true end
    if g.aiming and (y < g.cancelFloor or y < g.hoverStartLine - 400 * g.sourceScale) then
        g.cancelled = true
    end
end
function M.release(g, playable)
    if g.cancelled then return 'cancel' end
    -- A lifted finger has no cursor to continue carrying or aiming with.
    -- Only an explicit valid release submits; a drag never turns into C-mode.
    if g.touchScreen then return playable and (g.aiming or g.dropZone) and 'play' or 'cancel' end
    if g.aiming then return playable and 'play' or 'target' end
    if g.dropZone then return playable and 'play' or 'cancel' end
    if g.elapsed < 0.4 then return 'carry' end
    return 'cancel'
end
return M
