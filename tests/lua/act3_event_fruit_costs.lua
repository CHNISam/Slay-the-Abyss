package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/act3_winding_fixture.lua')
local Run,Nodes,Map,C,P,Q,R=F.Run,F.Nodes,F.Map,F.C,F.P,F.Q,F.R
local function fixture(id,hp)
 local r,m,n=F.fixture(hp or 89,89)
 for _,node in ipairs(m.nodes)do if node.id==n then node.eventId=id end end
 assert(Run.obtainPotion(r,'fruit_juice'));assert(Nodes.enter(r,m,n))
 if id=='winding_halls'then assert(Nodes.chooseEvent(r,'continue'))end
 local cache=C.copy(r.nodeFlow.event);local rng=R.snapshot(r.miscRng)
 assert(Run.usePotion(r,1));assert(r.maxHp==94 and r.potions[1]==nil)
 return r,m,cache,rng
end
local r,m,cache,rng=fixture('moai_head')
assert(cache.hpLoss==11 and r.nodeFlow.event.hpLoss==11)
local row=Nodes.view(r,m).node.event.options[1]
assert(row.description:find('94',1,true)and row.description:find('83',1,true),'Moai display must use current max94 and cached loss11')
assert(Nodes.chooseEvent(r,'heal'));assert(r.maxHp==83 and r.hp==83)
assert(R.snapshot(r.miscRng).counter==rng.counter)
for _,choice in ipairs({'madness','writhe','max_hp'})do
 r,m,cache,rng=fixture('winding_halls',choice=='max_hp' and 89 or 30)
 assert(cache.hpDamage==11 and cache.healAmount==22 and cache.maxHpLoss==4)
 local event=r.nodeFlow.event;assert(event.hpDamage==11 and event.healAmount==22 and event.maxHpLoss==4)
 local text=Nodes.view(r,m).node.event.options[3].description
 assert(text:find('94',1,true)and text:find('90',1,true),'Winding display must use current max94 and cached loss4')
 assert(Nodes.chooseEvent(r,choice))
 if choice=='madness'then assert(r.hp==24 and r.maxHp==94)
 elseif choice=='writhe'then assert(r.hp==57 and r.maxHp==94)
 else assert(r.maxHp==90 and r.hp==90)end
 assert(R.snapshot(r.miscRng).counter==rng.counter);assert(Nodes.chooseEvent(r,'leave'))
end
print('ACT3_EVENT_FRUIT_COSTS_PASS real Fruit use changes current owner while Moai/Winding retain original costs and update current before/after display')
