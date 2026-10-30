-- Fixed319009 AbstractDungeon.returnColorlessCard has one mutable act pool.
-- Actual Match preparation and public Skull Nodes commands; staged room route.
local Run,Nodes,R=require('abyss_run'),require('abyss_nodes'),require('abyss_sts_random')
local Data,Copy,Hooks=require('abyss_data'),require('abyss_copy').copy,require('abyss_relic_hooks')
local Match,Skull=require('abyss_match_event'),require('abyss_knowing_skull_event')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected '..tostring(k))end
end
local function snapshot(r)return Copy(r,{[r.data]=r.data})end
local function fixture()
 local r=Run.new(Data,'42',{experimental=true,campaign=true});r.act,r.floor,r.phase=2,18,'node';return r
end
local function match(r,floor)
 local event
 assert(Run.transaction(r,function(s)
  event={id='match_game'};return Match.prepare(s,event,Run.roomStreams(s,floor).miscRng,floor)
 end));return event
end
local function skull(r,floor)
 r.floor=floor;r.nodeFlow={type='event',floor=floor,event={id='knowing_skull'}}
 Skull.prepare(r,r.nodeFlow.event,nil,floor);assert(Nodes.chooseEvent(r,'continue'))
end
local function nextPool(r,ids,floor)
 local out=Copy(ids);R.shuffle(Run.roomStreams(r,floor).shuffleRng,out)
 for _,id in ipairs(out)do if r.data.cards.sourcePools.cardSourceMetadata[id].rarity=='uncommon'then return out,id end end
 error('missing uncommon')
end
local failures,count={},0
local function test(name,fn)
 local ok,why=pcall(fn);if ok then count=count+1;print('PASS '..name)
 else failures[#failures+1]=name..': '..tostring(why);print('FAIL '..failures[#failures])end
end
test('Match18 then Skull19 inherits exact canonical order and card identity',function()
 local r=fixture();match(r,18)
 local expected,id=nextPool(r,r.colorlessCardPool.cards,19);eq(id,'deep_breath')
 skull(r,19);assert(Nodes.chooseEvent(r,'card'))
 eq(r.deck[#r.deck].cardId,id);same(r.colorlessCardPool.cards,expected);eq(r.eventCardPools,nil)
end)
test('Skull18 then Match19 continues the same pool rather than restarting raw order',function()
 local r=fixture();local first=nextPool(r,r.data.cards.sourcePools.colorlessRaw,18)
 skull(r,18);assert(Nodes.chooseEvent(r,'card'))
 assert(r.colorlessCardPool,'Skull must publish the existing canonical owner');same(r.colorlessCardPool.cards,first)
 local expected,id=nextPool(r,first,19);local event=match(r,19)
 same(r.colorlessCardPool.cards,expected)
 local found=false;for _,c in ipairs(event.board)do if c.cardId==id then found=true end end
 assert(found,'Match board must contain shared-pool uncommon');eq(r.eventCardPools,nil)
end)
test('cross-act Skull resets canonical order once then Match continues it',function()
 local r=fixture();match(r,18);r.act=3
 local first=nextPool(r,r.data.cards.sourcePools.colorlessRaw,35)
 skull(r,35);assert(Nodes.chooseEvent(r,'card'))
 eq(r.colorlessCardPool.act,3);same(r.colorlessCardPool.cards,first)
 local expected=nextPool(r,first,36);match(r,36);same(r.colorlessCardPool.cards,expected)
end)
test('late Skull hook failure restores preexisting Match pool aliases HP price RNG UID then retry',function()
 local r=fixture();match(r,18);skull(r,19)
 r.alias={owner=r.colorlessCardPool,cards=r.colorlessCardPool.cards}
 local owner,ids=r.colorlessCardPool,r.colorlessCardPool.cards;local before=snapshot(r)
 local expected=nextPool(r,ids,19);local hook=Hooks.onObtainCard;local reached=false
 Hooks.onObtainCard=function(s,c,d,api)
  reached=true;same(s.colorlessCardPool.cards,expected);hook(s,c,d,api);error('late canonical pool obtain refusal')
 end
 local ok,why=Nodes.chooseEvent(r,'card');Hooks.onObtainCard=hook
 eq(ok,false);eq(why,'transaction_failed');assert(reached);same(r,before)
 eq(r.colorlessCardPool,owner);eq(r.colorlessCardPool.cards,ids);eq(r.alias.owner,owner);eq(r.alias.cards,ids)
 assert(Nodes.chooseEvent(r,'card'));same(r.colorlessCardPool.cards,expected);eq(r.hp,before.hp-6)
end)
assert(#failures==0,table.concat(failures,'\n'))
print('SKULL_MATCH_POOL_CONTINUITY '..count..' passed')
