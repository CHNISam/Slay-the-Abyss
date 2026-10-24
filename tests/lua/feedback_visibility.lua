-- Reproduce a real flying Defend crossing HP, using the generated native tree
-- and native sibling-order semantics instead of a SetAsLastSibling no-op.
local F=dofile("tests/lua/support/game_ui_fixture.lua")
local Run=require("abyss_run")
local Combat=require("abyss_combat")
local Theme=require("abyss_theme")
local function fixture()
    local canvas=F.control({children=F.Layout})
    local function bind(c,spec)
        c.order={}
        for _,child in ipairs(spec.children or {}) do
            c.order[#c.order+1]=child.name;bind(c.children[child.name],child)
        end
        function c:SetAsLastSibling()
            local order=assert(self.parent).order
            for i,name in ipairs(order) do if name==self.name then table.remove(order,i);break end end
            order[#order+1]=self.name
        end
    end
    bind(canvas,{children=F.Layout})
    local stage=F.Viewport.apply(canvas,1280,720)
    local host=F.GameUI.new(stage,F.Data,F.Presentation,"click",{imageSource="static",color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
    host:resize(1280,720)
    return host,stage:GetChild("battlePanel")
end
local function top(control,panel)
    while control.parent~=panel do control=assert(control.parent) end
    for i,name in ipairs(panel.order) do if name==control.name then return i end end
    error("unmapped native sibling")
end
local function rect(c,panel)
    local x,y,sx,sy=c.x or 0,c.y or 0,c.localScaleX or 1,c.localScaleY or 1
    local w,h=c.sizeDeltaX*sx,c.sizeDeltaY*sy
    local parent=c.parent
    while parent and parent~=panel do
        x=(parent.x or 0)+x*(parent.localScaleX or 1);y=(parent.y or 0)+y*(parent.localScaleY or 1)
        w=w*(parent.localScaleX or 1);h=h*(parent.localScaleY or 1);parent=parent.parent
    end
    return {x-w/2,y-h/2,x+w/2,y+h/2}
end
local function overlaps(a,b)return a[1]<b[3] and a[3]>b[1] and a[2]<b[4] and a[4]>b[2]end
local crossings=0
for count=1,6 do
    local host,panel=fixture()
    local ui=host.battleUI
    local enemies={}
    for i=1,math.min(count,5) do enemies[i]="cultist" end
    if count==6 then enemies={"guardian"} end
    local run=Run.new(F.Data,41);assert(Run.startCombat(run,"cultist_solo"))
    run.combat=Combat.new(F.Data,{seed=41,deck={"defend"},enemies=enemies})
    run.combat.player.block=7
    host.run,ui.run,host.nodeUI.run=run,run,run;host:refresh();ui:render()
    local card=panel:GetChild("feedback"):GetChild("playedCard")
    ui:playSlot(1);ui:playSlot(1)
    for tick=1,300 do
        if card.visible then
            local flight=rect(card,panel)
            for _,name in ipairs({"hero","enemy1","enemy2","enemy3","enemy4","enemy5"}) do
                local actor=panel:GetChild(name)
                if actor.visible then
                    for _,part in ipairs({"hpBorder","hp","blockEdge","blockIcon","block"}) do
                        local label=actor:GetChild(part)
                        if label.visible and overlaps(flight,rect(label,panel)) then
                            crossings=crossings+1
                            assert(top(card,panel)<top(actor,panel),"flying Defend hides "..name.."/"..part.." at "..(tick*0.005).."s")
                        end
                    end
                end
            end
        end
        ui:update(0.005)
        if not ui.busy and not card.visible then break end
    end
    assert(not ui.busy and not card.visible,"flight did not finish")
    assert(run.combat.player.block==12,"real Defend result changed")
    -- Foreground announcements stay in front after flight completion/cancel.
    ui:endTurn()
    local banner=panel:GetChild("feedbackForeground"):GetChild("banner")
    assert(banner.visible and top(banner,panel)>top(panel:GetChild("hero"),panel))
    ui.feedback:cancel()
    assert(not ui.busy and not card.visible and not banner.visible,"cancel left an overlay or input lock")
end
assert(crossings>0,"fixture did not reproduce a card crossing an actor's information")
print("LUA_FEEDBACK_VISIBILITY_PASS 6 layouts; native-order crossing protection; banner/cancel retained")
