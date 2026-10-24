package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local UI=require("abyss_battle_ui")
local C=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local Theme=require("abyss_theme")
local Presentation=require("abyss_presentation")
local Layout=require("abyss_ui_layout")
-- Instantiate the actual generated native tree; fail on unknown controls.
local function control(d)
    local c={name=d.name,visible=d.visible~=false,children={},text="",sizeDeltaX=d.size[1],sizeDeltaY=d.size[2],interactable=true,
        x=d.position and d.position[1] or 0,y=d.position and d.position[2] or 0}
    for _,v in ipairs(d.children or {}) do c.children[v.name]=control(v) end
    function c:GetChild(k)return assert(self.children[k],"missing control "..self.name.."/"..k)end
    function c:SetVisible(v)assert(type(v)=="boolean");self.visible=v end
    function c:AddCursorEventListener(event,fn)self.listeners=self.listeners or {};self.listeners[event]=fn;if event=="click"then self.click=fn end end
    function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
    function c:SetSizeDelta(x,y)self.sizeDeltaX,self.sizeDeltaY=x,y end
    function c:SetLocalScale(x,y)self.localScaleX,self.localScaleY=x,y end
    function c:SetImage(...)assert(select("#",...)==2);local source,id=...;assert(source=="static" and type(id)=="number");self.imageId=id end
    function c:SetAsLastSibling()self.raised=true end
    return c
end
local function same(a,b)
    assert(type(a)==type(b));if type(a)~="table"then assert(a==b);return end
    for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local root=control({name="root",size={1280,720},children=Layout})
local stage=root:GetChild("stage"):GetChild("battlePanel")
local ui=UI.new(stage,Data,Presentation,"click",{imageSource="static",color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end},{embedded=true})
ui.run=Run.new(Data,42);ui.run.floor=6;assert(Run.startCombat(ui.run,"elite_sentries"));ui:render()
local function click(name)
    local box=stage:GetChild(name)
    if box.click then if box.interactable then box.click()end else box:GetChild("hit").click()end
    if ui.feedback and ui.feedback.busy then for _=1,400 do if not ui.busy then break end;ui:update(.05)end;assert(not ui.busy)end
end
local function expect(outerBolt)
    for i=1,3 do local bolt=(i%2==1)==outerBolt;local box=stage:GetChild("enemy"..i)
        assert(box:GetChild("intent").text==(bolt and "" or "9"),"Sentry compact intent "..i..": "..box:GetChild("intent").text)
        assert(box:GetChild("intentIcon").imageId==(bolt and Theme.icon.intent.debuff or Theme.icon.intent.attack))
        local row=box:GetChild("statusRow")
        assert(row:GetChild("icon1").visible and row:GetChild("icon1").imageId==Theme.icon.status.artifact and row:GetChild("count1").text=="1")
    end
end
expect(true)
local before=C.copy(ui.run.combat)
for _=1,4 do
    click("enemy1");assert(stage:GetChild("notice").text:find("准备对你施加负面效果",1,true))
end
same(ui.run.combat,before)
click("endTurn");expect(false);assert(ui.run.combat.player.hp==71)
click("enemy2");assert(stage:GetChild("notice").text:find("准备对你施加负面效果",1,true))
click("endTurn");expect(true);assert(ui.run.combat.player.hp==53)
print("SENTRIES_GENERATED_UI_PASS compact/detail/icons/Artifact/readonly/two real rounds")
