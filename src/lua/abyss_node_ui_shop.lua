local ShopUI = require("abyss_shop_ui")
local ShopSelection = require('abyss_shop_selection')
local Merchant = require('abyss_merchant')
local M = {}

-- Installs the shop setup responsibility on one node UI instance.
function M.install(ctx)
    ctx.merchant = Merchant.new(ctx.child("merchant"), { color = ctx.options.color, sound = ctx.options.sound })

    ctx.child("merchant"):GetChild("talk"):GetChild("hit"):AddCursorEventListener(ctx.clickEvent, function() return ctx.merchant:tap() end)

    ctx.self.merchant = ctx.merchant

    ctx.shopSelection = ShopSelection.new(ctx.self, ctx.child('shopView'), ctx.options)
    ctx.renderShop = ShopUI.new(ctx.self, {
        selection = ctx.shopSelection,
        child = ctx.child, show = ctx.show, state = ctx.state, ink = ctx.ink, picture = ctx.picture,
        fillCard = ctx.fillCard, cardName = ctx.cardName, relicName = ctx.relicName, relicText = ctx.relicText,
        action = ctx.action, pageArrows = ctx.pageArrows,
        commit = function(...) return ctx.commit(...) end,
    })
    function ctx.shopFooter()
        if ctx.shopSelection.selected then return ctx.shopSelection:footer() end
        local confirmLabel,confirmOk,confirmFn
        confirmLabel, confirmOk = "离开商店", true
        confirmFn = function()
            -- The farewell stays on screen like a camp/event result, so it is actually seen.
            return ctx.commit("leaveShop", nil, function() return "", {} end)
        end
        return nil,confirmLabel,confirmOk,confirmFn,nil,nil
    end
end
return M
