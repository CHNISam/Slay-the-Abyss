local Theme = require("abyss_theme")
local RoomMotion = require('abyss_node_ui_motion')
local RewardDetail = require('abyss_node_ui_reward_detail')
local C = Theme.color
local layout = Theme.layout.nativeNode
local M = {}

-- Installs the feedback responsibility on one node UI instance.
function M.install(ctx)
    ctx.buttonLooks, ctx.buttonHover, ctx.buttonPress = {}, nil, nil

    function ctx.paintButton(box)
        local look = ctx.buttonLooks[box]
        if not look then return end -- a never-shown view can still receive a late native exit
        local enabled = look.enabled and not look.selected
        local pressed = enabled and ctx.buttonPress and ctx.buttonPress.box == box
        local hover = enabled and ctx.buttonHover == box and not pressed
        local function showButtonState()
            box:GetChild("normal"):SetVisible(look.enabled and not look.selected and not pressed and not hover)
            box:GetChild("hover"):SetVisible(hover == true)
            box:GetChild("pressed"):SetVisible(pressed == true)
            box:GetChild("disabled"):SetVisible(not look.enabled)
            box:GetChild("selected"):SetVisible(look.selected == true)
        end
        showButtonState()
        local function paintButtonFrame()
            ctx.tint(box:GetChild("hover"), look.primary and C.goldBright or C.buttonHover)
            ctx.tint(box:GetChild("pressed"), C.buttonPressedFill)
            ctx.tint(box:GetChild("border"), look.selected and C.goldBright or not look.enabled and C.line
                or (pressed or hover or look.primary) and C.goldBright or C.gold)
            local function paintButtonLabel()
                local label = box:GetChild("label")
                if label then ctx.ink(label, not look.enabled and C.textMuted or pressed and C.buttonPressedText
                        or look.selected and C.goldBright or look.primary and C.textOnLight or C.goldBright) end
            end
            paintButtonLabel()

        end
        paintButtonFrame()
        local scale = pressed and layout.buttonStates.pressedScale or layout.buttonStates.normalScale
        box:SetLocalScale(scale, scale, 1)
    end

    ctx.buttonInputs, ctx.actionInputs = {}, {}

    function ctx.retireAction(entry)
        if not entry or not entry.observe then return end
        if entry.retire then entry.retire() end
        for _, input in pairs(ctx.buttonInputs) do
            for _, gesture in pairs(input.active) do if gesture.action == entry then gesture.action = nil end end
            if input.released and input.released.action == entry then input.released.action = nil end
        end
    end

    function ctx.observeAction(entry)
        if not entry.observe or entry.observe() then return true end
        ctx.retireAction(entry)
        return false
    end

    ctx.inspectCards={}


    ctx.roomMotion = RoomMotion.new(ctx.self,ctx.child,ctx.options)

    ctx.rewardDetail=RewardDetail.new(ctx.self,ctx.child('treasureView'):GetChild('details'),ctx.options)

    ctx.swipe, ctx.swallow = nil, nil

    function ctx.resetButtons()
        ctx.rewardDetail:reset()
        ctx.buttonHover, ctx.buttonPress, ctx.swipe = nil, nil, nil
        ctx.self.inspectPress=nil
        for _, input in pairs(ctx.buttonInputs) do input.active, input.released = {}, nil end
        for box in pairs(ctx.buttonLooks) do ctx.paintButton(box) end
    end

    function ctx.state(box, enabled, selected, primary)
        ctx.buttonLooks[box] = {enabled=enabled == true, selected=selected == true, primary=primary == true}
        ctx.paintButton(box)
    end
end
return M
