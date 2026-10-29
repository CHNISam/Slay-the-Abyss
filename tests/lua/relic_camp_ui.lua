package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,N,Map,C,UI=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_node_ui')
local D,Layout,Presentation=require('abyss_data'),require('abyss_ui_layout'),require('abyss_presentation')
local _,control=dofile('tests/lua/support/node_ui_cases.lua')(0,0)
local function find(rows,name)for _,row in ipairs(rows)do if row.name==name then return row end;local value=row.children and find(row.children,name);if value then return value end end end
local template=Map.generate(D,42)
local count=0
for _,ids in ipairs({{'Coffee Dripper'},{'Fusion Hammer'},{'Coffee Dripper','Fusion Hammer'}})do
 local r,m=Run.new(D,42),C.copy(template);r.hp=20
 for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id))end
 local first=Map.available(m)[1];for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='camp';node.roomKind=nil end end
 assert(N.enter(r,m,first.id));local root=control(find(Layout,'nodePanel'))
 local p=require('abyss_character_presentation').prepare(Presentation,r.data)
 local ui=UI.new(root,r,m,p,'click',nil,{imageSource='static'})
 ui:setVisible(true)
 if ids[1]=='Coffee Dripper'then
  assert(root:GetChild('campView'):GetChild('rest'):GetChild('description').text:find('无法休息',1,true))
  assert(not ui:press('campView/rest'));assert(r.hp==20)
 end
 if ids[#ids]=='Fusion Hammer'then
  assert(root:GetChild('campView'):GetChild('forge'):GetChild('description').text:find('无法锻造',1,true))
  assert(not ui:press('campView/forge'));assert(ui.picker==nil)
 end
 if #ids==2 then
  assert(root:GetChild('confirm').visible);assert(root:GetChild('confirm'):GetChild('label').text=='继续前进')
  assert(ui:press('confirm'));assert(r.phase=='map'and r.hp==20 and not r.deck[1].upgraded)
 end
 count=count+1
end
print('LUA_RELIC_CAMP_UI_PASS '..count)
