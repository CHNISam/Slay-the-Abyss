package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,D=require('abyss_combat'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function definition(rows,id)
 for _,row in ipairs(rows)do if row.id==id then return row end end;error('missing '..id)
end
local function minimal()
 return {rules=D.rules,statuses=D.statuses,
  cards={cards={definition(D.cards.cards,'defend')}},
  enemies={enemies={definition(D.enemies.enemies,'cultist')}}}
end
local function construct(data)return C.new(data,{seed=42,deck={'defend'},enemies={'cultist'}})end
local passed,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
test('historical sparse data omitting potions constructs and executes normal cards and turns',function()
 local data=minimal();local before=C.copy(data);local s=construct(data)
 eq(next(s.catalog.potions),nil);assert(C.play(s,s.hand[1].uid));eq(s.player.block,5)
 assert(C.endTurn(s));eq(s.turn,2);eq(s.player.hp,80);same(data,before);eq(data.potions,nil)
end)
test('empty optional potion wrapper and empty explicit array both construct without mutation',function()
 for _,wrapper in ipairs({{},{potions={}}})do
  local data=minimal();data.potions=wrapper;local before=C.copy(data)
  local s=construct(data);eq(next(s.catalog.potions),nil);same(data,before);eq(data.potions,wrapper)
 end
end)
test('complete potion catalog retains every real definition and leaves caller input unchanged',function()
 local data=minimal();data.potions=D.potions;local before=C.copy(data);local s=construct(data)
 local count=0;for id,row in pairs(s.catalog.potions)do count=count+1;eq(row.id,id)end
 assert(count>0);eq(count,#D.potions.potions)
 for _,row in ipairs(D.potions.potions)do same(s.catalog.potions[row.id],row)end
 assert(s.catalog.potions.fire_potion);same(data,before)
end)
test('each missing or complete catalog owns an independent lookup table',function()
 for _,full in ipairs({false,true})do
  local data=minimal();if full then data.potions=D.potions end
  local a,b=construct(data),construct(data);assert(a.catalog.potions~=b.catalog.potions)
  a.catalog.potions.review_only={id='review_only'};eq(b.catalog.potions.review_only,nil)
  eq(data.potions and data.potions.review_only,nil)
 end
end)
print('COMBAT_OPTIONAL_POTIONS '..passed..' passed; '..failed..' failed')
assert(failed==0,'optional potion catalog compatibility failed')
