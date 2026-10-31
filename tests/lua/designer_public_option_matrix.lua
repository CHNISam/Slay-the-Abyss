-- Source-locked Designer branches at the public Nodes boundary. Controlled
-- room/inventory fixtures, not full-pool random draw, natural or device proof.
-- Catches missing dispatcher branches, wrong charging, partial failed commit,
-- duplicate acceptance and infeasible mandatory grids in public commands.
local Run,N,Map,D,C=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data'),require('abyss_combat')
local Hooks=require('abyss_relic_hooks')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local function copy(r)return C.copy(r,{[r.data]=r.data})end
local function choose(r,choice,uid)local ok,why=N.chooseEvent(r,choice,uid);assert(ok,choice..': '..tostring(why))end
local function reject(r,choice,uid)
 local before=copy(r);local flow,deck,pool=r.nodeFlow,r.deck,r.relicPool
 local ok=N.chooseEvent(r,choice,uid);eq(ok,false);same(r,before)
 eq(r.nodeFlow,flow);eq(r.deck,deck);eq(r.relicPool,pool)
end
local function fixture(seed)
 local r=Run.new(D,tostring(seed),{experimental=true,campaign=true,campaignProfile='competition-two-act'})
 r.act,r.gold=2,200;local m=Map.generate(D,tostring(seed),2);local node=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==node.id then v.type,v.eventId='event','designer'end end
 assert(N.enter(r,m,node.id));choose(r,'continue');return r,m
end
local function terminal(r,m)
 choose(r,'leave');eq(r.phase,'map');eq(r.nodeFlow.complete,true);assert(#N.available(r,m)>0);reject(r,'leave')
end
local function upgraded(r)local n=0;for _,c in ipairs(r.deck)do if c.upgraded then n=n+1 end end;return n end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Designer public '..count..' '..name)end
local one,mapOne=fixture(1);local random,mapRandom=fixture(2)
eq(one.nodeFlow.event.adjustmentUpgradesOne,true);eq(one.nodeFlow.event.cleanUpRemovesCards,false)
eq(random.nodeFlow.event.adjustmentUpgradesOne,false);eq(random.nodeFlow.event.cleanUpRemovesCards,true)
for _,case in ipairs({{one,mapOne,true},{random,mapRandom,false}})do
 test(case[3]and'selected adjustment full and punch'or'random adjustment cleanup full and punch',function()
  local r,m=copy(case[1]),C.copy(case[2]);choose(r,'adjust');eq(r.gold,160)
  if case[3]then
   eq(r.nodeFlow.event.stage,'choose_card');local uid=r.deck[1].uid
   reject(r,'leave');reject(r,'upgrade',999);choose(r,'upgrade',uid);eq(upgraded(r),1)
  else eq(upgraded(r),2)end
  reject(r,'adjust');terminal(r,m)
  r,m=copy(case[1]),C.copy(case[2]);choose(r,'cleanup');eq(r.gold,140)
  local view=N.view(r,m).node.event;eq(view.selection.canCancel,false)
  if case[3]then
   eq(view.selection.count,2);local a,b=r.deck[1].uid,r.deck[6].uid
   reject(r,'transform',{a,a});choose(r,'transform',{b,a});same(r.nodeFlow.event.removedUids,{b,a});eq(#r.deck,10)
  else
   eq(view.selection.count,1);local uid=r.deck[1].uid;choose(r,'remove',uid);eq(#r.deck,9)
   for _,card in ipairs(r.deck)do assert(card.uid~=uid)end
  end
  reject(r,'cleanup');terminal(r,m)
  r,m=copy(case[1]),C.copy(case[2]);choose(r,'full');eq(r.gold,110);choose(r,'full_remove',r.deck[1].uid)
  eq(#r.deck,9);eq(upgraded(r),1);terminal(r,m)
  r,m=copy(case[1]),C.copy(case[2]);choose(r,'punch');eq(r.hp,77);eq(r.gold,200);terminal(r,m)
 end)
end
test('empty protected bottled and insufficient funds preserve resources and allow source Punch',function()
 for _,case in ipairs({one,random})do
  for _,kind in ipairs({'empty','bottled','protected','poor'})do
   local r=copy(case)
   if kind=='empty'then r.deck={}
   elseif kind=='bottled'then for _,card in ipairs(r.deck)do card.inBottleFlame=true end
   elseif kind=='protected'then r.deck={{uid=1,cardId='necronomicurse',upgraded=false}}
   else r.gold=39 end
   for _,choice in ipairs({'cleanup','full'})do reject(r,choice)end
   if kind=='empty'or kind=='poor'then reject(r,'adjust')end
   local view=N.view(r,case==one and mapOne or mapRandom).node.event
   for _,row in ipairs(view.options)do if row.choice=='cleanup'or row.choice=='full'then eq(row.enabled,false)end end
   choose(r,'punch');eq(r.hp,77)
  end
 end
end)
test('late transformed-card refusal rolls back public command and exact retry commits once',function()
 local r,m=copy(one),C.copy(mapOne);choose(r,'cleanup');local a,b=r.deck[1].uid,r.deck[6].uid
 local old=Hooks.onObtainCard
 Hooks.onObtainCard=function(staged,card,definition,api)old(staged,card,definition,api);error('public Designer late failure')end
 local ok,why=pcall(reject,r,'transform',{a,b});Hooks.onObtainCard=old;assert(ok,why)
 eq(r.gold,140);choose(r,'transform',{a,b});eq(#r.deck,10);eq(r.nextDeckUid,13)
 reject(r,'transform',{a,b});terminal(r,m)
end)
print('DESIGNER_PUBLIC_OPTION_MATRIX '..count..' passed')
