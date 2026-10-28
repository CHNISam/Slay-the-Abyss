-- Real map/controller on the generated native tree. Only the platform controls
-- are doubled; route permissions, state transitions and focus use production Lua.
local Map, UI, Controller = require('abyss_map'), require('abyss_map_ui'), require('abyss_controller')
local Theme, Layout = require('abyss_theme'), require('abyss_map_layout')
local function control(spec, parent)
    local c = {spec=spec,parent=parent,children={},visible=spec.visible~=false,
        image=spec.image,imageColor=spec.colour,listeners={},navigation={},
        localScaleX=1,localScaleY=1,raycastTarget=true}
    function c:GetChild(name) return self.children[name] end
    function c:SetVisible(v) self.visible=v end
    function c:SetAnchoredPosition(x,y) self.position={x,y} end
    function c:SetSizeDelta(w,h) self.size={w,h} end
    function c:SetLocalScale(x,y) self.localScaleX,self.localScaleY=x,y end
    function c:SetImage(_,id) self.image=id end
    function c:AddCursorEventListener(event,fn) self.listeners[event]=fn end
    function c:AddNavigationEventListener(event,fn) self.navigation[event]=fn end
    for _,child in ipairs(spec.children or {}) do c.children[child.name]=control(child,c) end
    return c
end
local root=control({children=require('abyss_map_controls').controls})
local panel=root:GetChild('stage'):GetChild('mapPanel')
local function box(index)
    for _,group in pairs(panel.children) do if group.children['node'..index] then return group.children['node'..index] end end
end
local focus
local manager=Controller.new({events={Confirm='confirm',Cancel='cancel'},
    getFocus=function()return focus end,setFocus=function(c)focus=c end,isController=function()return true end})
local map=Map.generate(require('abyss_data'),42)
local calls=0
local ui=UI.new(root,map,function(node)calls=calls+1;return Map.choose(map,node.id)end,'click',{
    controller=manager,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
local function equalColor(actual,want)
    for _,key in ipairs({'r','g','b','a'}) do assert(actual[key]==want[key],'node icon state colour '..key) end
end
local seen={}
local function verify()
    local view=Map.view(map)
    for index,node in ipairs(view.nodes) do
        local b=box(index)
        if b.visible then
            local state=node.id==view.currentNodeId and 'current' or node.visited and 'visited' or node.available and 'available' or 'locked'
            seen[state]=true
            for _,child in pairs(b.children) do
                assert(not child.visible or child.spec.kind~='image' or child.spec.name=='icon' or child.spec.name=='positionToken',
                    'route nodes must not repaint rings or background discs: '..child.spec.name)
            end
            local icon,hit=b:GetChild('icon'),b:GetChild('hit')
            assert(icon.image==Theme.icon.node[node.type],'existing official node icon ID retained')
            local palette=Theme.color.mapCanvas
            equalColor(icon.imageColor,state=='locked' and palette.far or state=='visited' and palette.visited or palette.kind[node.type])
            assert(b:GetChild('positionToken').visible==(state=='current'),'existing token identifies only current node')
            local size=node.type=='boss' and Theme.layout.map.bossNode or Theme.layout.map.node
            assert(hit.size[1]==size and hit.size[2]==size,'unpainted hit target stays full sized')
            local enabled=state=='available' and ui.navigationEnabled
            assert(hit.visible==enabled and hit.canControllerFocus==enabled,'only legal destinations are focusable')
        else
            assert(not b:GetChild('hit').visible and not b:GetChild('hit').canControllerFocus,'offscreen hits stay disabled')
        end
    end
end
verify()
manager:sync('map')
assert(focus and focus.visible and focus.canControllerFocus)
assert(focus.navigation.confirm())
assert(calls==1 and map.floor==1)
verify()
assert(not focus.navigation.confirm() and calls==1,'repeated confirmation must not advance again')
ui:setNavigationEnabled(true)
manager:tick();manager:sync('map')
assert(focus.navigation.confirm())
assert(calls==2 and map.floor==2)
verify()
ui:setNavigationEnabled(true)
for _,invalid in ipairs({map.path[1],map.currentNodeId,'f16_l4','missing'}) do
    assert(not ui:choose(invalid) and calls==2 and map.floor==2,'illegal routes must not become selectable')
end
for offset=0,Layout.maxScroll,120 do ui:setScroll(offset);ui:update(.07);verify() end
ui:setVisible(false);ui:setVisible(true);ui:render();verify()
for _,state in ipairs({'current','visited','available','locked'}) do assert(seen[state],'missing real visual state '..state) end
local function notice()
    for _,group in pairs(panel.children) do if group.children.notice then return group.children.notice end end
end
-- Empty normal maps do not become tutorial billboards on pointer or controller.
ui:setNavigationEnabled(true);ui:render()
assert(notice().text=='' and not notice().visible,'normal route must have no permanent controller teaching')
manager.api.isController=function()return false end
ui:render();assert(notice().text=='' and not notice().visible,'normal route must have no permanent pointer teaching')
ui.entryError='测试错误';ui:render()
assert(notice().text=='测试错误' and notice().visible,'real entry errors must remain visible')
ui.entryError=nil;ui:setNavigationEnabled(false)
assert(notice().text=='请先完成当前节点' and notice().visible,'blocked room state is necessary information')
ui:setNavigationEnabled(true);assert(notice().text=='' and not notice().visible,'resolved errors must not leave stale notices')
local bossMap=Map.generate(require('abyss_data'),42)
for _=1,16 do assert(Map.choose(bossMap,Map.available(bossMap)[1].id)) end
ui.map=bossMap;ui:render();ui:setNavigationEnabled(false)
assert(notice().text=='已抵达首领 · 请完成首领战斗与奖励' and notice().visible)
ui:setNavigationEnabled(true)
assert(notice().text=='首领奖励已处理 · 请选择首领宝箱' and notice().visible,'actual target choice must remain visible')
print('MAP_NOTICE_PASS no teaching; real errors, room locks and reward target retained')
print('MAP_NODE_VISUALS_PASS 4 states, official icons, hit areas, controller and illegal routes')
return {root=root,map=map,ui=ui,controller=manager}
