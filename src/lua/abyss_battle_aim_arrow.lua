-- Paint the existing pooled aim controls; no input or card state ownership.
-- Pan 2026-10-31: restore the star-chain TargetArrow (e7098ac) over the dense
-- continuous shaft (fb1ce50) — the dense line tested worse on device.
local Theme=require("abyss_theme")
local D,C=Theme.layout.cardDrag,Theme.color
local M={}
-- STS TargetArrow behaviour: the dot chain flows along a quadratic Bezier toward
-- the target (phase advances with dt), the last dot pins to the end point, and the
-- control point sits behind the start / above the end (aimBend) for a soft arc.
function M.render(layer, aiming, sx, sy, ex, fy, enemy, tint, phase)
    phase = phase or 1
    local n = D.aimDots
    local bend = D.aimBend or {0, 0}
    local cx, cy = sx - (ex-sx)*bend[1], fy + (fy-sy)*bend[2]
    for i = 1, n do
        local dot = layer:GetChild("aim" .. i)
        local t = i == n and 1 or (i-1+phase)/n
        dot:SetVisible(aiming == true)
        if aiming then
            local u = 1-t
            local size = D.aimDot[1] + (D.aimDot[2]-D.aimDot[1])*t
            dot:SetAnchoredPosition(u*u*sx + 2*u*t*cx + t*t*ex, u*u*sy + 2*u*t*cy + t*t*fy)
            dot:SetSizeDelta(size, size)
            -- Light polish: stars stay upright (no leftover rotation from the shaft
            -- variant); gold trail whose tail turns red once an enemy is locked.
            dot.localRotationZ = 0
            tint(dot, (enemy and t > 0.6) and C.danger or C.goldBright)
        end
    end
end
return M
