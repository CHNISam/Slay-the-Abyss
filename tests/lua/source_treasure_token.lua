local H=dofile('tests/helpers/act2_event_ui.lua')
local function fixture()
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true});local m=H.Map.generate(r.data,'42')
 local n=H.Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='treasure'end end
 assert(H.Nodes.enter(r,m,n.id));assert(H.Nodes.openTreasure(r));local item=r.nodeFlow.reward.items[1]
 return r,assert(H.Nodes.treasureRewardSource(r,item.slot))
end
H.test('opaque token refuses metatables and every additional field before changing a reward owner',function()
 for _,kind in ipairs({'extra','meta'})do
  local r,token=fixture();local before=H.snapshot(r)
  if kind=='extra'then token.extra=true else setmetatable(token,{})end
  local ok,why=H.Nodes.claimTreasureReward(r,token);H.eq(ok,false);H.eq(why,'treasure_source_mismatch');H.same(r,before)
 end
end)
H.test('source rechecks floor, seed, signature, generation and opened chest',function()
 local cases={function(r)r.floor=r.floor+1 end,function(r)r.nodeFlow.mapSeed='43'end,
  function(r)r.nodeFlow.mapSignature=''end,function(r)r.roomGeneration=0 end,
  function(r)r.roomGeneration=.5 end,function(r)r.nodeFlow.chest.opened=false end}
 for _,mutate in ipairs(cases)do
  local r,token=fixture();mutate(r);local before=H.snapshot(r)
  local ok=H.Nodes.claimTreasureReward(r,token);H.eq(ok,false);H.same(r,before)
 end
end)
local function linkedFixture(missing,extra)
 local r=H.Run.new(H.Data,'42',{experimental=true,campaign=true});r.endingUnlocked=true
 if extra then r.relics[#r.relics+1]='Matryoshka';r.relicCounters=r.relicCounters or {};r.relicCounters.Matryoshka=2 end
 if missing then
  r.data=H.Copy(r.data)
  for i=#r.data.relics.relics,1,-1 do if r.data.relics.relics[i].id==missing then table.remove(r.data.relics.relics,i)end end
 end
 local m=H.Map.generate(r.data,'42');local n=H.Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='treasure'end end
 assert(H.Nodes.enter(r,m,n.id));assert(H.Nodes.openTreasure(r))
 return r,m,assert(H.Nodes.treasureSource(r,m))
end
H.test('modern footer source binds stable linked slots and taking key preserves all independent rewards',function()
 local r,m,token=linkedFixture();local before=H.snapshot(r);local remaining={}
 for _,item in ipairs(before.nodeFlow.reward.items)do
  if item.slot~=token.baseSlot and item.slot~=token.keySlot then remaining[#remaining+1]=item end
 end
 local ok,why=H.Nodes.chooseTreasure(r,m,token,'sapphire');assert(ok);H.eq(why,'sapphire');H.eq(r.keys.sapphire,true)
 H.same(r.nodeFlow.reward.items,remaining);H.eq(r.phase,#remaining>0 and 'node'or 'map')
 H.eq(r.gold,before.gold);H.same(r.relics,before.relics);H.same(r.miscRng,before.miscRng);H.same(r.relicPool,before.relicPool)
 local source=H.Nodes.treasureSource(r,m);H.eq(source,nil)
end)
H.test('modern footer refuses same token after any reward or summary mutation without partial resources',function()
 local mutations={function(r)r.nodeFlow.reward.items[1].unexpected=true end,
  function(r)r.nodeFlow.reward.gold=999 end,function(r)r.nodeFlow.reward.extraRelics={}end,
  function(r)r.nodeFlow.reward.items[1].slot=99 end,function(r)r.nodeFlow.reward.items[1].kind='invalid'end}
 for _,mutate in ipairs(mutations)do
  local r,m,token=linkedFixture();mutate(r);local before=H.snapshot(r)
  local ok=H.Nodes.chooseTreasure(r,m,token,'sapphire');H.eq(ok,false);H.same(r,before)
 end
end)
H.test('initial unavailable base can be sacrificed, later missing implemented definition cannot be laundered',function()
 local s,sm,st=linkedFixture()
 local r,m,token=linkedFixture(st.relicId);local base
 for _,item in ipairs(r.nodeFlow.reward.items)do if item.slot==token.baseSlot then base=item end end
 -- Removing this definition before open preserves the original queue and
 -- source identity. It is a content-fault input, never a rerolled player reward.
 H.eq(base.available,false);assert(H.Nodes.chooseTreasure(r,m,token,'sapphire'))
 s.data=H.Copy(s.data)
 for i=#s.data.relics.relics,1,-1 do if s.data.relics.relics[i].id==st.relicId then table.remove(s.data.relics.relics,i)end end
 local before=H.snapshot(s);local ok=H.Nodes.chooseTreasure(s,sm,st,'sapphire');H.eq(ok,false);H.same(s,before)
end)
H.test('source Matryoshka extra reward survives Sapphire together with independent gold',function()
 local r,m,token=linkedFixture(nil,true);local before=H.snapshot(r);local extra={}
 assert(r.nodeFlow.reward.extraRelics and #r.nodeFlow.reward.extraRelics==1)
 for _,item in ipairs(before.nodeFlow.reward.items)do if item.slot~=token.baseSlot and item.slot~=token.keySlot then extra[#extra+1]=item end end
 assert(H.Nodes.chooseTreasure(r,m,token,'sapphire'));H.eq(r.phase,'node');H.eq(r.keys.sapphire,true)
 H.same(r.nodeFlow.reward.items,extra);H.eq(#r.nodeFlow.reward.extraRelics,1);H.eq(r.gold,before.gold)
 H.same(r.relicPool,before.relicPool);H.same(r.treasureRng,before.treasureRng);H.same(r.relicCounters,before.relicCounters)
end)
print('SOURCE_TREASURE_TOKEN '..H.count..' passed')
