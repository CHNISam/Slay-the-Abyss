-- Minimal host controls for controller tests. Layout geometry has separate JS checks.
local F=require("support.game_ui_fixture")
local M={}
local function button(name)
    local states={}
    for _,state in ipairs({"normal","hover","pressed","disabled"}) do
        states[#states+1]={name=state,children={{name="label"},{name="border"},{name="plate"}}}
    end
    return {name=name,children={{name="hit",kind="presetButton",children=states}}}
end
function M.new(options)
    options=options or {}
    local canvas=F.control({children=F.Layout})
    local root=F.Viewport.apply(canvas,1280,720)
    local platform={seed=1,imageSource="static",color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,
        prologue=false,experimentalCharacters=options.enabled~=false,cursorEvents=options.cursor,settle=options.settle}
    local ui=F.GameUI.new(root,F.Data,F.Presentation,"click",platform)
    root.ui=ui
    return ui,root
end
M.button=button
return M
