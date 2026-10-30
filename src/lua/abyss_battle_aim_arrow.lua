-- Paint the existing pooled arrow controls; no input or card state ownership.
local Theme=require("abyss_theme")
local D,C=Theme.layout.cardDrag,Theme.color
local M={}
    -- STS TargetArrow port (AbstractPlayer.renderTargetingUi/drawCurvedLine): the control
    -- point sits behind the start and overshoots past the end, so the shaft arcs up and
    -- lands on the target from above. Drawn as overlapping tangent-rotated segments so it
    -- reads as one continuous shaft, tapering toward the tip, capped by a V arrowhead.
    local function control(sx, sy, ex, fy)
        return sx - (ex-sx)/4, fy + (fy-sy)/2
    end
    local function bezier(sx, sy, ex, fy, t)
        local u, cx, cy = 1-t, control(sx, sy, ex, fy)
        return u*u*sx + 2*u*t*cx + t*t*ex, u*u*sy + 2*u*t*cy + t*t*fy
    end
    -- Shaft segments are the existing aim1..aim(N-2) diamonds stretched along the tangent
    -- (a long thin diamond is a tapered stroke; overlapped they read as one line). The last
    -- two become the V head's barbs. No new controls, art, or theme keys.
    local ARROW = {width={5,11}, overlap=1.6, head={30,8}, spread=36}
    function M.render(layer, aiming, sx, sy, ex, fy, enemy, tint)
        local n = D.aimDots - 2
        local colour = enemy and C.danger or C.goldBright
        local headL, headR = layer:GetChild("aim" .. (n+1)), layer:GetChild("aim" .. (n+2))
        headL:SetVisible(aiming == true); headR:SetVisible(aiming == true)
        -- The shaft stops at the head's base so the tip is the arrowhead, not a blunt bar.
        local span = math.max(1, math.sqrt((ex-sx)^2 + (fy-sy)^2))
        local stop = math.max(0.5, 1 - ARROW.head[1]*0.5/span)
        local px, py = sx, sy
        for i = 1, n do
            local seg, t = layer:GetChild("aim" .. i), stop*i/n
            seg:SetVisible(aiming == true)
            if aiming then
                local x, y = bezier(sx, sy, ex, fy, t)
                local dx, dy = x-px, y-py
                local w = ARROW.width[1] + (ARROW.width[2]-ARROW.width[1])*t
                seg:SetAnchoredPosition((x+px)/2, (y+py)/2)
                seg:SetSizeDelta(math.max(w*2, math.sqrt(dx*dx+dy*dy)*ARROW.overlap + w), w)
                seg.localRotationZ = math.deg(math.atan(dy, dx))
                tint(seg, colour)
                px, py = x, y
            end
        end
        if not aiming then return end
        -- Head follows the curve's tangent at the tip: dB/dt(1) = 2*(end - control).
        local cx, cy = control(sx, sy, ex, fy)
        local hx, hy = ex-cx, fy-cy
        if hx*hx + hy*hy < 1 then hx, hy = 0, 1 end
        local heading = math.deg(math.atan(hy, hx))
        local len, thick = ARROW.head[1], ARROW.head[2]
        for side, barb in ipairs({headL, headR}) do
            local r = math.rad(heading + 180 + (side == 1 and ARROW.spread or -ARROW.spread))
            barb:SetAnchoredPosition(ex + math.cos(r)*len/2, fy + math.sin(r)*len/2)
            barb:SetSizeDelta(len, thick)
            barb.localRotationZ = math.deg(r)
            tint(barb, colour)
        end
    end
return M
