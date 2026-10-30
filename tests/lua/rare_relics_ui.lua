local Run,N,Map,C,UI=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_node_ui')
local D,Layout,P=require('abyss_data'),require('abyss_ui_layout'),require('abyss_presentation')
local _,control=dofile('tests/lua/support/node_ui_cases.lua')(0,0)
local function find(rows,name)
 for _,row in ipairs(rows)do if row.name==name then return row end;local x=row.children and find(row.children,name);if x then return x end end
end
local function camp(ids)
 local r,m=Run.new(D,42),Map.generate(D,42)
 for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id))end
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='camp'end end
 assert(N.enter(r,m,first.id));local root=control(find(Layout,'nodePanel'))
 local ui=UI.new(root,r,m,require('abyss_character_presentation').prepare(P,r.data),'click',nil,{imageSource='static'})
 ui:setVisible(true);return ui,r,root
end
local ui,r,root=camp({'Girya','Shovel'})
assert(ui:press('confirm'));assert(root:GetChild('campView'):GetChild('rest'):GetChild('name').text=='锻炼')
assert(ui:press('campView/rest'));assert(r.relicCounters.girya==1 and r.phase=='map')
ui,r,root=camp({'Shovel'})
assert(ui:press('confirm'));assert(ui:press('campView/rest'));assert(r.nodeFlow.digReward and not r.nodeFlow.complete)
assert(root:GetChild('campView'):GetChild('rest'):GetChild('name').text=='领取遗物')
assert(ui:press('campView/rest'));assert(r.phase=='map'and #r.relics==3)
ui,r,root=camp({'Peace Pipe'})
assert(ui:press('confirm'));assert(ui:press('campView/rest'));assert(ui.picker=='toke')
local n=#r.deck;assert(ui:press('pickerView/card1'));assert(ui:press('confirm'));assert(#r.deck==n-1 and r.phase=='map')
print('RARE_RELICS_UI_PASS 3')
