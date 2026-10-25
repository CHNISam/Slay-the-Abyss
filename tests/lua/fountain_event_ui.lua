package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,C=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_combat')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fixture(deck)
 local r,m=Run.new(F.Data,42),Map.generate(F.Data,42);r.deck=C.copy(deck)
 local first=Map.available(m)[1];for _,node in ipairs(m.nodes)do if node.id==first.id then node.type='event';node.eventId='fountain' end end
 assert(Nodes.enter(r,m,first.id))
 local root=F.control(spec(F.Layout,'nodePanel'))
 local ui=UI.new(root,r,m,F.Presentation,'click',nil,{color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,imageSource='static'})
 local function get(path)local v=root;for part in path:gmatch('[^/]+')do v=assert(v:GetChild(part))end;return v end
 return r,ui,get,function(path)get(path):GetChild('hit').click()end
end
local r,ui,get,click=fixture({{uid=1,cardId='regret'},{uid=2,cardId='strike'}})
eq(get('eventView/name').text,'净化之泉');eq(get('eventView/option3').visible,false)
assert(get('eventView/option1/description').text:find('诅咒',1,true))
click('eventView/option1');eq(r.phase,'map');eq(#r.deck,1);eq(r.deck[1].uid,2);eq(get('pickerView').visible,false)
assert(get('eventView/body').text:find('已移除诅咒：1 张',1,true));ui:press('eventView/option1');eq(#r.deck,1)
print('PASS fountain UI cleanse immediately commits and displays actual count')
r,ui,get,click=fixture({{uid=1,cardId='regret',inBottleFlame=true}})
click('eventView/option1');eq(r.phase,'map');eq(#r.deck,1);assert(get('eventView/body').text:find('已移除诅咒：0 张',1,true))
print('PASS fountain UI zero removals finish without a dead picker')
r,ui,get,click=fixture({{uid=1,cardId='regret'}})
click('eventView/option2');eq(r.phase,'map');eq(#r.deck,1);eq(get('eventView').visible,true)
print('PASS fountain UI leave preserves the curse and holds result')
print('FOUNTAIN_UI 3 passed')
