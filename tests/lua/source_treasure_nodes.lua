-- Public source chest commands/generated controls; route/history are staged test inputs.
local H=dofile('tests/helpers/act2_event_ui.lua')
local T=require('abyss_treasure')
local function fixture(seed,boss)
 local r=H.Run.new(H.Data,tostring(seed),{experimental=true,campaign=true})
 r.floor=boss and 16 or 8
 local m=H.Map.generate(r.data,tostring(seed))
 -- The public node entry still validates map identity; only the test room type is staged.
 local n=H.Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='treasure';v.floor=1 end end
 assert(H.Nodes.enter(r,m,n.id))
 r.endingUnlocked=true
 return r,m
end
H.test('room entry constructs source chest without opening hooks or consuming relic queues',function()
 local r,m=fixture(42);H.eq(r.nodeFlow.chest.opened,false);H.eq(#r.nodeFlow.reward.items,0)
 H.eq(r.treasureRng.counter,2)
 local pool=H.Relics.snapshot(r.relicPool);local cards=H.Random.snapshot(r.cardRng)
 assert(H.Nodes.leaveTreasure(r));H.eq(r.phase,'map')
 H.same(H.Relics.snapshot(r.relicPool),pool);H.same(H.Random.snapshot(r.cardRng),cards)
end)
H.test('explicit open commits exact owners and exposes independent linked reward tokens',function()
 local r,m=fixture(42)
 local expected=assert(T.open(r,r.nodeFlow.chest,r.nodeFlow.reward))
 assert(H.Nodes.openTreasure(r));H.eq(r.nodeFlow.chest.opened,true)
 H.same(r.nodeFlow.reward,expected.reward);H.same(H.Random.snapshot(r.treasureRng),H.Random.snapshot(expected.treasureRng))
 H.same(H.Relics.snapshot(r.relicPool),H.Relics.snapshot(expected.relicPool))
 local before=H.snapshot(r);local ok,why=H.Nodes.openTreasure(r);H.eq(ok,false);H.eq(why,'chest_already_open');H.same(r,before)
 local key
 for _,item in ipairs(r.nodeFlow.reward.items)do if item.kind=='sapphire'then key=item end end
 assert(key);local token=assert(H.Nodes.treasureRewardSource(r,key.slot))
 assert(H.Nodes.claimTreasureReward(r,token));H.eq(r.keys.sapphire,true)
 for _,item in ipairs(r.nodeFlow.reward.items)do assert(item.slot~=key.linkedSlot and item.kind~='sapphire')end
 before=H.snapshot(r);ok=H.Nodes.claimTreasureReward(r,token);H.eq(ok,false);H.same(r,before)
 if r.phase=='node'then assert(H.Nodes.leaveTreasure(r))end
end)
H.test('generated chest click is a real open command and reward paging preserves other rewards',function()
 local r,m=fixture(42);local ui,get,shown,click=H.setup(r,m)
 H.eq(r.nodeFlow.chest.opened,false);assert(click('treasureView/chest'));H.eq(r.nodeFlow.chest.opened,true)
 local found=false
 for _=1,#r.nodeFlow.reward.items do
  if get('treasureView/reward/name').text=='蓝钥匙'then found=true;break end
  assert(click('treasureView/next'))
 end
 assert(found);assert(get('treasureView/reward/description').text:find('放弃关联遗物',1,true))
 assert(click('treasureView/take'));H.eq(r.keys.sapphire,true)
 if r.phase=='node'then assert(click('back'))end
 H.eq(r.phase,'map')
end)
H.test('failed relic obtain cannot consume reward token, queues, currencies or ownership',function()
 local r,m=fixture(42);assert(H.Nodes.openTreasure(r))
 local item
 for _,candidate in ipairs(r.nodeFlow.reward.items)do if candidate.kind=='relic'then item=candidate;break end end
 assert(item)
 local token=assert(H.Nodes.treasureRewardSource(r,item.slot));local before=H.snapshot(r)
 local obtain=H.Run.obtainRelic
 H.Run.obtainRelic=function(s) s.gold=s.gold+9;return false,'test_obtain_failure' end
 local ok=H.Nodes.claimTreasureReward(r,token);H.eq(ok,false);H.same(r,before)
 H.Run.obtainRelic=obtain
end)
print('SOURCE_TREASURE_NODES '..H.count..' passed')
