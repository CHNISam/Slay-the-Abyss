local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Map,R=require('abyss_map'),require('abyss_sts_random')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fixture(empty)
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local ui=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=42,prologue=false,imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
 assert(testStart(ui));local r=ui.run
 r.potions=empty and {} or {[1]='blood_potion',[3]='fruit_juice'}
 r.deck=empty and {{uid=1,cardId='strike',upgraded=false}} or {{uid=1,cardId='strike',upgraded=false},{uid=7,cardId='anger',upgraded=true,inBottleFlame=true},{uid=9,cardId='cleave',upgraded=false}}
 if empty then r.gold=49 end
 -- Explicit event content and skipped prior rooms isolate this UI contract;
 -- never replace a canonical combat node with an invented event room.
 assert(r.data~=F.Data and r.data.rules~=F.Data.rules and r.data.rules.events~=F.Data.rules.events,
  'controlled event content requires a private Run data owner')
 local sharedEvent=F.Data.rules.events.encounterId
 r.data.rules.events.encounterId='we_meet_again'
 eq(F.Data.rules.events.encounterId,sharedEvent)
 local first
 while not first do
  local available=Map.available(ui.map);assert(#available>0,'canonical event route missing')
  for _,node in ipairs(available)do if node.type=='event' then first=node;break end end
  if not first then assert(Map.choose(ui.map,available[1].id))end
 end
 -- The unchanged independent seed42 map golden reaches f3_l2 via f1_l2/f2_l1.
 eq(first.id,'f3_l2');eq(first.floor,3);eq(ui.map.path[1],'f1_l2');eq(ui.map.path[2],'f2_l1')
 r.floor=ui.map.floor
 assert(F.Nodes.restoreMap(r,ui.map),'ordinary event fixture must retain its canonical map')
 ui:refresh();assert(ui.mapUI:choose(first.id))
 eq(ui.mode,'node');eq(r.nodeFlow.id,first.id);eq(r.nodeFlow.type,'event');eq(r.nodeFlow.event.id,'we_meet_again')
 eq(F.Data.rules.events.encounterId,sharedEvent)
 r.relicPool.rng=R.restore({words={'0000000000000000','0000000000000000'},counter=0})
 local q=r.relicPool.queues.common;for i,v in ipairs(q)do if v=='Anchor'then table.remove(q,i);break end end;table.insert(q,1,'Anchor')
 local function get(path)local n=root:GetChild('nodePanel');for key in path:gmatch('[^/]+')do n=assert(n:GetChild(key),path)end;return n end
 local function click(path)return get(path):GetChild('hit').click()end
 return ui,get,click
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS we-meet-again UI '..count..' '..name)end
test('four source trades expose exact cached potion gold and approved upgraded card name',function()
 local ui,get,click=fixture();local r=ui.run
 eq(get('eventView/name').text,'又见面了');eq(get('eventView/option4').visible,true);eq(get('confirm').visible,false)
 -- Source constructor order at room seed42+3=45: potion shuffle, gold,
 -- card shuffle. Existing independent Python XS128/Java48 oracles give52/UID7.
 eq(r.nodeFlow.event.tradePotionSlot,3);eq(r.nodeFlow.event.tradeGold,52);eq(r.nodeFlow.event.tradeCardUid,7)
 assert(get('eventView/option2/description').text:find('52',1,true))
 assert(get('eventView/option3/description').text:find(F.Presentation.anger.name..'+',1,true))
 assert(ui:openPotions());local bag=ui.potionUI.root;assert(bag:GetChild('slot3'):GetChild('hit').click())
 eq(bag:GetChild('discard'):GetChild('hit').interactable,false);eq(bag:GetChild('use'):GetChild('hit').interactable,false)
 assert(bag:GetChild('detail').text:find('不能使用或丢弃',1,true));eq(bag:GetChild('discard'):GetChild('hit').click(),false);eq(r.potions[3],'fruit_juice')
 assert(ui:closePotions());eq(r.miscRng.counter,3)
 local misc=R.snapshot(r.miscRng);eq(misc.words[1],'a734e819e6d5c06d');eq(misc.words[2],'47c9649dafb559fe')
 local stale=ui.nodeUI.actions['eventView/option3'].handler;click('eventView/option3');eq(stale(),false)
 eq(r.nodeFlow.event.removedUid,7);eq(r.nodeFlow.event.obtainedRelicId,'anchor');eq(get('pickerView').visible,false)
 click('eventView/option1');eq(r.phase,'map');eq(ui.nodeUI:holding(),false)
end)
test('no resources leaves three explicit disabled choices and a working refusal',function()
 local ui,get,click=fixture(true)
 eq(ui.run.miscRng.counter,0);eq(ui.run.nodeFlow.event.tradeGold,0)
 for i=1,3 do eq(ui.nodeUI.actions['eventView/option'..i].enabled,false)end
 eq(get('eventView/option4').visible,true);click('eventView/option4');eq(ui.run.nodeFlow.event.stage,'result')
 click('eventView/option1');eq(ui.run.phase,'map')
end)
print('WE_MEET_AGAIN_UI '..count..' passed')
