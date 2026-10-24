-- Transaction fixtures, not natural-run or platform acceptance evidence.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Map,Nodes=require('abyss_combat'),require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local data=require('abyss_data')
local n,failed=0,0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
 if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'extra '..tostring(k)) end
end
local function test(name,fn)
 n=n+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'ok ' or 'not ok ')..n..' - '..name..(ok and '' or ': '..tostring(err)))
end
local function enter(kind,id)
 local run,map=Run.new(data,42),Map.generate(data,42)
 run.deck={run.deck[1]}
 map.nodes[1].type=kind;map.nodes[1].eventId=id
 assert(Nodes.enter(run,map,map.nodes[1].id));return run,map
end

test('explicit empty permanent deck starts without fabricated cards and can lose normally',function()
 local s=C.new(data,{deck={},enemies={'cultist'},seed=42})
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do eq(#pile,0) end
 local seed=s.seed;C.draw(s,5);eq(s.seed,seed)
 for _=1,30 do if s.phase~='player' then break end;assert(C.endTurn(s)) end
 eq(s.phase,'defeat');eq(s.player.hp,0)
end)

for _,id in ipairs({'cleric','purifier'}) do
 test(id..' removes the final UID exactly once, preserving permanent identity and cost',function()
  local run,map=enter('event',id);local uid,nextUid=run.deck[1].uid,run.nextDeckUid
  local gold=run.gold;eq(Nodes.view(run,map).node.event.options[id=='cleric' and 2 or 1].enabled,true)
  assert(Nodes.purifyEvent(run,uid));eq(#run.deck,0);eq(run.nextDeckUid,nextUid)
  eq(run.gold,gold-(id=='cleric' and 50 or 0));eq(run.phase,'map')
  local before=C.copy(run);local ok,reason=Nodes.purifyEvent(run,uid)
  eq(ok,false);eq(reason,'no_pending_node');same(run,before)
  assert(Run.startCombat(run,'cultist_solo'));eq(#run.combat.hand,0);eq(#run.deck,0)
 end)
end

test('Golden Wing pays once before removing the last permanent card',function()
 local run,map=enter('event','golden_wing');local uid=run.deck[1].uid;local hp=run.hp
 assert(Nodes.chooseEvent(run,'sacrifice'));eq(run.hp,hp-7)
 eq(Nodes.view(run,map).node.event.options[1].enabled,true)
 local before=C.copy(run);eq(Nodes.chooseEvent(run,'leave'),false);same(run,before)
 assert(Nodes.purgeWing(run,uid));eq(#run.deck,0);eq(run.hp,hp-7)
 eq(run.phase,'map');assert(Run.startCombat(run,'cultist_solo'))
end)

test('empty event deck disables selection and rejects stale UID without charging',function()
 for _,id in ipairs({'cleric','purifier'}) do
  local run,map=enter('event',id);local uid=run.deck[1].uid;run.deck={}
  local options=Nodes.view(run,map).node.event.options
  eq(options[id=='cleric' and 2 or 1].enabled,false)
  local before=C.copy(run)
  local ok=Nodes.purifyEvent(run,uid)
  eq(ok,false);same(run,before);assert(Nodes.chooseEvent(run,'leave'))
 end
end)

test('Golden Wing empty-deck sacrifice still pays its displayed damage without a stuck picker',function()
 local run,map=enter('event','golden_wing');run.deck={};local hp=run.hp
 eq(Nodes.view(run,map).node.event.options[1].enabled,true)
 assert(Nodes.chooseEvent(run,'sacrifice'));eq(run.hp,hp-7);eq(run.phase,'map')
 eq(run.nodeFlow.complete,true);eq(#run.deck,0)
 local before=C.copy(run);eq(Nodes.chooseEvent(run,'sacrifice'),false);same(run,before)
end)

test('shop removes the last card, consumes one service, and still permits buying a new card',function()
 local run,map=enter('shop');run.gold=10000
 local uid=run.deck[1].uid;local price=Nodes.view(run,map).node.removePrice
 assert(Nodes.removeCard(run,uid));eq(#run.deck,0);eq(run.gold,10000-price)
 eq(run.shopRemoveCount,1);eq(Nodes.view(run,map).node.removeAvailable,false)
 local before=C.copy(run);local ok,reason=Nodes.removeCard(run,uid)
 eq(ok,false);eq(reason,'removal_unavailable');same(run,before)
 local offer=run.nodeFlow.cards[1];assert(not offer.unavailable)
 assert(Nodes.buyCardSlot(run,1));eq(#run.deck,1);assert(run.deck[1].uid~=uid)
end)

test('empty-deck shop rejects a stale UID without spending its unused service',function()
 local run,map=enter('shop');run.gold=10000;local uid=run.deck[1].uid;run.deck={}
 local before=C.copy(run);local ok,reason=Nodes.removeCard(run,uid)
 eq(ok,false);eq(reason,'invalid_card');same(run,before)
 eq(Nodes.view(run,map).node.removeAvailable,true)
end)

print('EMPTY_PERMANENT_DECK '..n..' tests, '..failed..' failed');assert(failed==0)
