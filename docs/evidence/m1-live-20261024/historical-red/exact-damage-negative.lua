package.preload["abyss_combat"] = function()
    return dofile("F:/New folder/.artifacts/m1-live-sprint/audit/source/src/lua/abyss_combat.lua")
end
package.preload["abyss_battle_ui"] = function()
    return dofile("F:/New folder/.artifacts/m1-live-sprint/audit/source/src/lua/abyss_battle_ui.lua")
end
dofile("tests/lua/card_preview.lua")
