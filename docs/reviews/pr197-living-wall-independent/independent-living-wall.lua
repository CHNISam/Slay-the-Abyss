-- Independent transactional/UI review at PR197 efd3feb; no production mutations.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes,R,UI=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes'),require('abyss_sts_random'),require('abyss_node_ui')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local pools=dofile('tests/lua/support/living_wall_source_pools.lua')
local count,failed=0,0
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b)) end
local function deep(a,b)
 eq(type(a),type(b)); if type(a)~='table' then return eq(a,b) end
 for k,v in pairs(a) do deep(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'extra field '..tostring(k)) end
end
local function unchanged(root)
 local old,seen=C.copy(root),{}
 local function walk(t) if type(t)~='table' or seen[t] then return end
  local fields={};seen[t]=fields;for k,v in pairs(t) do fields[k]=v;walk(v) end end
 walk(root)
 return function()
  deep(root,old)
  for t,fields in pairs(seen) do
   for k,v in pairs(fields) do assert(t[k]==v,'reference changed '..tostring(k)) end
   for k in pairs(t) do assert(fields[k]~=nil,'new reference field '..tostring(k)) end
  end
 end
end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
end
local pristine=Run.new(F.Data,'42')
local mapTemplate=Map.generate(F.Data,'42')
local function enter(deck)
 local run,map=C.copy(pristine),C.copy(mapTemplate)
 if deck then run.deck=C.copy(deck) end
 local first=Map.available(map)[1]
 for _,node in ipairs(map.nodes) do if node.id==first.id then node.type='event';node.eventId='living_wall' end end
 assert(Nodes.enter(run,map,first.id));return run,map
end
local function context(run,original)
 run.transformContext={pools=C.copy(pools),cards=original or {strike={sourceId='Strike_R',category='colored'}},sourceToLocal={Anger='anger',Cleave='cleave'}}
 run.miscRng=R.restore({words={'0000000000000000','0000000000000000'},counter=19})
end
local function spec(items,name)
 for _,v in ipairs(items) do if v.name==name then return v end
  local x=v.children and spec(v.children,name);if x then return x end end
end
local cursor={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='enddrag'}
local function uiFor(run,map,pointer)
 local root=F.control(spec(F.Layout,'nodePanel'));root:SetVisible(true) -- Host opens nodePanel before pointer dispatch.
 local ui=UI.new(root,run,map,F.Presentation,'click',nil,{color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,imageSource='static',cursorEvents=pointer and cursor or nil})
 local function get(path) local v=root;for key in path:gmatch('[^/]+') do v=assert(v:GetChild(key),path) end;return v end
 local function click(path) return get(path..'/hit').click() end
 return ui,get,click
end
test('all three direct UID commands reject before choice locking without any reference writes',function()
 for _,choice in ipairs({'forget','change','grow'}) do
  local run=enter();local check=unchanged(run)
  local ok,reason=Nodes.chooseEvent(run,choice,run.deck[1].uid);eq(ok,false);eq(reason,'invalid_event_choice');check()
 end
end)
test('transforming middle duplicate preserves sibling identities and appends fresh UID only',function()
 local run=enter({{uid=31,cardId='strike',upgraded=false},{uid=52,cardId='strike',upgraded=true},{uid=87,cardId='strike',upgraded=false}})
 run.nextDeckUid=120;context(run);local left,right,old=run.deck[1],run.deck[3],run.deck[2]
 local cardRng,offset,oldMisc=run.cardRng,run.cardRarityOffset,run.miscRng;local oldMiscCheck=unchanged(oldMisc)
 assert(Nodes.chooseEvent(run,'change'));assert(Nodes.chooseLivingWallCard(run,52))
 eq(#run.deck,3);eq(run.deck[1],left);eq(run.deck[2],right);eq(run.deck[3].uid,120);eq(run.deck[3].cardId,'anger');eq(run.deck[3].upgraded,false)
 eq(old.uid,52);eq(old.cardId,'strike');eq(old.upgraded,true);oldMiscCheck();assert(run.miscRng~=oldMisc)
 eq(run.cardRng,cardRng);eq(run.cardRarityOffset,offset);eq(R.snapshot(run.miscRng).counter,20)
 local check=unchanged(run);eq(Nodes.chooseLivingWallCard(run,120),false);check()
end)
test('same source identity is removed before single bounded draw, not rerolled',function()
 local run=enter({{uid=1,cardId='anger',upgraded=true}});run.nextDeckUid=2
 context(run,{anger={sourceId='Anger',category='colored'}})
 assert(Nodes.chooseEvent(run,'change'));assert(Nodes.chooseLivingWallCard(run,1))
 eq(run.deck[1].cardId,'cleave');eq(run.nodeFlow.event.obtainedSourceId,'Cleave');eq(R.snapshot(run.miscRng).counter,20)
end)
test('native unavailable transform retries are atomic and correct content arrival recovers same locked choice',function()
 local run,map=enter();context(run);run.transformContext.sourceToLocal.Anger=nil
 local ui,get,click=uiFor(run,map);click('eventView/option2');click('pickerView/card1')
 local check=unchanged(run);local selected=ui.selected
 click('confirm');eq(ui.selected,selected);eq(ui.picker,'living_change');eq(get('pickerView').visible,true);eq(get('back').visible,false)
 eq(get('notice').text,'事件所需卡牌数据不可用');check();click('confirm');check()
 eq(ui:press('eventView/option1'),false);check()
 run.transformContext.sourceToLocal.Anger='anger';click('confirm');eq(run.phase,'map');eq(run.deck[#run.deck].cardId,'anger');eq(R.snapshot(run.miscRng).counter,20)
 local post=unchanged(run);click('confirm');post();click('confirm');post()
end)
test('native second-page duplicate selection follows UID across reordering rather than position',function()
 local deck={};for i=1,13 do deck[i]={uid=200+i,cardId='strike',upgraded=false} end
 local run,map=enter(deck);local ui,get,click=uiFor(run,map)
 click('eventView/option1');assert(ui:setPage(2));click('pickerView/card1');local selected=ui.selected;assert(selected>201)
 local moving=table.remove(run.deck,#run.deck);table.insert(run.deck,1,moving);ui:render()
 eq(ui.selected,selected);click('confirm');eq(#run.deck,12)
 for _,card in ipairs(run.deck) do assert(card.uid~=selected,'removed wrong duplicate') end
 eq(run.deck[1],moving);eq(get('eventView').visible,true)
end)
test('native stale Grow selection cannot upgrade another UID after selected card becomes upgraded',function()
 local run,map=enter();local ui,get,click=uiFor(run,map)
 click('eventView/option3');click('pickerView/card1');local selected=ui.selected
 for _,c in ipairs(run.deck) do if c.uid==selected then c.upgraded=true end end
 local check=unchanged(run);click('confirm');check();eq(run.phase,'node');eq(run.nodeFlow.event.choice,'grow')
 eq(get('notice').text,'这张卡牌无法继续升级');click('pickerView/card1');assert(ui.selected~=selected);click('confirm');eq(run.phase,'map')
end)
test('hidden native panel refuses old confirm and allows the same selected UID on reopening',function()
 local run,map=enter();local ui,get,click=uiFor(run,map)
 click('eventView/option1');click('pickerView/card1');local selected=ui.selected;ui:setVisible(false)
 local check=unchanged(run);local ok,reason=click('confirm');eq(ok,false);eq(reason,'panel_hidden');check()
 ui:setVisible(true);click('confirm');eq(run.phase,'map');for _,c in ipairs(run.deck) do assert(c.uid~=selected) end
end)
test('new UI instance restores locked Grow without replaying option and upgrades once',function()
 local run,map=enter();assert(Nodes.chooseEvent(run,'grow'))
 local ui,get,click=uiFor(run,map);eq(ui.picker,'living_grow');eq(get('back').visible,false);eq(get('pickerView').visible,true)
 click('pickerView/card1');local uid=ui.selected;click('confirm');eq(run.phase,'map')
 local check=unchanged(run);eq(Nodes.chooseLivingWallCard(run,uid),false);check()
end)
test('pointer confirmation from previous render cannot consume rebound or recovered action',function()
 local run,map=enter();context(run);run.transformContext.sourceToLocal.Anger=nil
 local ui,get,click=uiFor(run,map,true);click('eventView/option2');click('pickerView/card1')
 local hit=get('confirm/hit');local event={touchId=41}
 hit.listeners.down(event);hit.listeners.up(event)
 ui:render();local check=unchanged(run);local ok,reason=hit.click(event);eq(ok,false);eq(reason,'stale_action');check()
 run.transformContext.sourceToLocal.Anger='anger';ui:render();check=unchanged(run);ok,reason=hit.click(event);eq(ok,false);eq(reason,'stale_action');check()
 hit.listeners.down(event);hit.listeners.up(event);hit.click(event);eq(run.phase,'map');eq(R.snapshot(run.miscRng).counter,20)
 check=unchanged(run);ok,reason=hit.click(event);eq(ok,false);eq(reason,'stale_action');check()
end)
print('INDEPENDENT_LIVING_WALL '..count..' tests, '..failed..' failed');assert(failed==0)
