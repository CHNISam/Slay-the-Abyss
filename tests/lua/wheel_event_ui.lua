package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local UI,Nodes,Run,Map,R=require('abyss_node_ui'),require('abyss_nodes'),require('abyss_run'),require('abyss_map'),require('abyss_sts_random')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function state(n)return R.restore({words={'0000000000000000',string.format('%016x',n)},counter=0})end
local function fixture(outcome)
 local run,map=Run.new(F.Data,42),Map.generate(F.Data,42)
 run.deck={{uid=7,cardId='strike',upgraded=true},{uid=8,cardId='bash',upgraded=false,inBottleFlame=true}}
 local first=Map.available(map)[1];for _,n in ipairs(map.nodes)do if n.id==first.id then n.type='event';n.eventId='wheel' end end
 assert(Nodes.enter(run,map,first.id));run.miscRng=state(outcome);run.relicPool.rng=state(0)
 local q=run.relicPool.queues.common;for i,v in ipairs(q)do if v=='Anchor'then table.remove(q,i);break end end;table.insert(q,1,'Anchor')
 local root=F.control(spec(F.Layout,'nodePanel'))
 local ui=UI.new(root,run,map,F.Presentation,'click',nil,{color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,imageSource='static'})
 local function get(path)local n=root;for key in path:gmatch('[^/]+')do n=assert(n:GetChild(key),path)end;return n end
 local function click(path)get(path):GetChild('hit').click()end
 return run,ui,get,click
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS wheel UI '..count..' '..name)end
test('native wheel forces one spin and removal enters the existing mandatory purge picker',function()
 local r,ui,get,click=fixture(4);eq(get('eventView/name').text,'变化转轮');eq(get('eventView/option2').visible,false)
 click('eventView/option1');eq(r.nodeFlow.event.outcome,4);eq(r.nodeFlow.event.stage,'wheel_result');eq(get('pickerView').visible,false)
 click('eventView/option1');eq(get('pickerView').visible,true);eq(get('back').visible,false);eq(get('pickerView/card2').visible,false)
 click('pickerView/card1');eq(get('confirm/label').text,'确认移除');click('confirm')
 eq(#r.deck,1);eq(r.deck[1].uid,8);eq(get('eventView').visible,true);eq(r.nodeFlow.event.stage,'result')
 click('eventView/option1');eq(r.phase,'map');eq(ui:holding(),false)
end)
test('native relic reward names the drawn item before offering claim or skip',function()
 local r,ui,get,click=fixture(1);click('eventView/option1');click('eventView/option1');eq(r.nodeFlow.event.stage,'relic_reward')
 local name;for _,def in ipairs(r.data.relics.relics)do if def.id=='anchor'then name=def.name end end
 assert(name and get('eventView/body').text:find(name,1,true));eq(get('eventView/option2').visible,true)
 click('eventView/option2');eq(r.nodeFlow.event.stage,'result');eq(r.nodeFlow.event.obtainedRelicId,nil)
 click('eventView/option1');eq(r.phase,'map');eq(ui:holding(),false)
end)
print('WHEEL_EVENT_UI '..count..' passed')
