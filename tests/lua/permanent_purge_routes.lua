package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,C,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_combat'),require('abyss_map')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local passed,failed=0,0
local function test(name,fn)local ok,e=pcall(fn);if ok then passed=passed+1;print('PASS purge '..name)else failed=failed+1;print('FAIL purge '..name..': '..tostring(e))end end
local function fixture(kind)
 local r=Run.new(Data,42);r.phase='node';r.gold=500
 r.deck={{uid=1,cardId='strike',inBottleFlame=true},{uid=2,cardId='bash',upgraded=false}}
 r.nodeFlow={type=kind=='shop' and 'shop' or 'event',event={id=kind,stage=kind=='golden_wing' and 'purge' or nil}}
 return r
end
local function remove(r,kind,uid)
 if kind=='shop'then return Nodes.removeCard(r,uid)end
 return Nodes.chooseEvent(r,kind=='cleric' and 'purify' or kind=='purifier' and 'pray' or 'purge',uid)
end
for _,kind in ipairs({'shop','cleric','purifier','golden_wing'})do
 test(kind..' rejects bottled UID atomically and accepts eligible UID',function()
  local r=fixture(kind);local before=C.copy(r)
  local ok,why=remove(r,kind,1);eq(ok,false);eq(why,'card_not_purgeable');same(r,before)
  assert(remove(r,kind,2));eq(#r.deck,1);eq(r.deck[1].uid,1)
 end)
end
test('shop pays and disables Maw Bank before permanent remove hook',function()
 local H,Curse=require('abyss_relic_hooks'),require('abyss_curses')
 local r=fixture('shop');assert(Run.obtainRelic(r,'MawBank'));local price=require('abyss_shop').removePrice(r)
 local old=Curse.onRemove;local seen
 Curse.onRemove=function(owner,card)seen={gold=owner.gold,maw=owner.relicCounters.maw_bank};return old(owner,card)end
 local called,ok=pcall(remove,r,'shop',2);Curse.onRemove=old
 assert(called and ok);eq(seen.gold,500-price);eq(seen.maw,-2)
end)
test('shop remove-hook exception rolls payment counters and card back',function()
 local Curse=require('abyss_curses');local r=fixture('shop');assert(Run.obtainRelic(r,'MawBank'));local before=C.copy(r)
 local old=Curse.onRemove;Curse.onRemove=function()error('injected remove failure')end
 local called,ok=pcall(remove,r,'shop',2);Curse.onRemove=old
 assert(called);eq(ok,false);same(r,before)
end)
test('native purge pickers use the shared legal group in all four rooms',function()
 local UI=require('abyss_node_ui');local F=dofile('tests/lua/support/game_ui_fixture.lua')
 local function spec(list,name)for _,item in ipairs(list)do if item.name==name then return item end;local found=item.children and spec(item.children,name);if found then return found end end end
 local map=Map.generate(Data,42);local n=Map.available(map)[1];assert(Map.choose(map,n.id))
 for _,kind in ipairs({'shop','cleric','purifier','golden_wing'})do
  local r=fixture(kind);local flow=r.nodeFlow
  flow.id,flow.floor,flow.mapSeed,flow.mapSignature=n.id,n.floor,map.seed,map.sourceSignature
  flow.cards,flow.relics,flow.potions={}, {}, {}
  local root=F.control(spec(F.Layout,'nodePanel'))
  local ui=UI.new(root,r,map,F.Presentation,'click',nil,{color=function(...)return{...}end,imageSource='static'})
  eq(#ui.removeRows,1);eq(ui.removeRows[1].uid,2)
  local key=kind=='shop' and 'shopView/removal' or kind=='cleric' and 'eventView/option2' or 'eventView/option1'
  ui:setVisible(true);assert(ui:press(key));eq(#ui.removeRows,1);eq(ui.removeRows[1].uid,2)
  r.deck[2].inBottleTornado=true;ui:render();eq(#ui.removeRows,0)
 end
end)
assert(failed==0,failed..' purge tests failed');print('PERMANENT_PURGE_ROUTES '..passed..' passed')
