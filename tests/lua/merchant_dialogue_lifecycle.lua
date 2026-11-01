local _,control=dofile('tests/lua/support/node_ui_cases.lua')(math.huge,math.huge)
local UI,Run,Map,Nodes=require('abyss_node_ui'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local data,Layout=require('abyss_data'),require('abyss_ui_layout')
local function find(nodes,name)for _,n in ipairs(nodes)do if n.name==name then return n end local v=n.children and find(n.children,name);if v then return v end end end
local function setup()
 local run,map=Run.new(data,42),Map.generate(data,42)
 while not run.nodeFlow do
  local choices=Map.available(map);local chosen
  for _,node in ipairs(choices)do if node.type=='shop'then chosen=node;break end end
  if chosen then assert(Nodes.enter(run,map,chosen.id))else assert(Map.choose(map,choices[1].id))end
 end
 run.gold=10000
 local root=control(find(Layout,'nodePanel'))
 local presentation=require('abyss_character_presentation').prepare(require('abyss_presentation'),run.data)
 local ui=UI.new(root,run,map,presentation,'click',nil,{color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,imageSource='static'})
 ui:setVisible(true)
 return ui,root
end
local failures=0
local function test(name,fn)local ok,err=pcall(fn);print((ok and 'ok 'or'FAIL ')..name);if not ok then print(err);failures=failures+1 end end
test('hidden shop rejects delayed merchant tap and resumes same dialogue',function()
 local ui,root=setup();ui:update(.05)
 local merchant=ui.merchant;local old=merchant.current;local shown=old.shown
 local tap=root:GetChild('merchant'):GetChild('talk'):GetChild('hit').click
 ui:setVisible(false)
 assert(not tap(),'hidden shop consumed delayed dialogue tap')
 ui:update(1);assert(merchant.current==old and old.shown==shown,'hidden dialogue advanced')
 ui:setVisible(true);ui:update(.05)
 assert(merchant.current==old and old.shown>shown,'reopen must resume without restarting narration')
 assert(ui:press('shopView/card1'));assert(ui:press('confirm'),'dialogue must not block buying')
end)
test('new transaction replaces prior portrait gesture',function()
 local ui=setup()
 assert(ui:press('shopView/card1'));assert(ui:press('confirm'));ui:update(.05)
 assert(ui.merchant.nod~=nil)
 ui.run.gold=0;ui:render();assert(not ui:press('shopView/card2'))
 assert(ui.merchant.current.kind=='poor' and ui.merchant.shake~=nil)
 assert(ui.merchant.nod==nil,'refusal still nods for previous purchase')
 ui.run.gold=10000;ui:render();assert(ui:press('shopView/card2'));assert(ui:press('confirm'))
 assert(ui.merchant.current.kind=='buy' and ui.merchant.nod~=nil and ui.merchant.shake==nil,'purchase still shakes for previous refusal')
end)
assert(failures==0,tostring(failures)..' merchant lifecycle failures')
