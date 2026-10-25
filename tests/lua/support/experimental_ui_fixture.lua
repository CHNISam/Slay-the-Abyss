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
    local class={name="characterPanel",visible=false,children={{name="blocker"}}}
    for i=1,4 do class.children[#class.children+1]=button("character"..i) end
    class.children[#class.children+1]=button("cancel")
    root.children.characterPanel=F.control(class,root)
    local choice={name="choicePanel",visible=false,children={{name="blocker"},{name="title"},{name="hint"},{name="status"}}}
    for i=1,10 do choice.children[#choice.children+1]=button("card"..i) end
    for _,id in ipairs({"confirm","before","after"}) do choice.children[#choice.children+1]=button(id) end
    root.children.choicePanel=F.control(choice,root)
    local platform={seed=1,imageSource="static",color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,
        prologue=false,experimentalCharacters=options.enabled~=false,cursorEvents=options.cursor,settle=options.settle}
    local ui=F.GameUI.new(root,F.Data,F.Presentation,"click",platform)
    root.ui=ui
    return ui,root
end
M.button=button
return M
