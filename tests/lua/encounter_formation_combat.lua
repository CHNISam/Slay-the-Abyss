package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data=require('abyss_combat'),require('abyss_data')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS formation Combat '..count..' - '..name)end
local function equal(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function boundary(booleans,indices)
 local b,i,visual=0,0,0
 return {misc={boolean=function()b=b+1;assert(type(booleans[b])=='boolean');return booleans[b]end,
  integer=function(lo,hi)i=i+1;equal(lo,0);local n=assert(indices[i]);assert(n<=hi);return n end},
  visualFloat=function(lo,hi)equal(lo,-20);equal(hi,20);visual=visual+1;return 0 end},
  function()equal(b,#booleans);equal(i,#indices);return visual end
end
local function members(s)
 local out={};for i,e in ipairs(s.enemies)do out[i]=e.definitionId;equal(e.id,e.definitionId..'_'..i);equal(e.hp,e.maxHp)end
 equal(s.nextEnemyId,#s.enemies+1);return table.concat(out,',')
end
test('all six explicit source groups produce actual independent combat actors',function()
 local rows={
  {'2 Louse',{false,true},{},'green_louse,red_louse'},
  {'3 Louse',{true,false,true},{},'red_louse,green_louse,red_louse'},
  {'Large Slime',{false},{},'spike_slime_l'},
  {'Lots of Slimes',{}, {0,0,0,0,0},'spike_slime_s,spike_slime_s,spike_slime_s,acid_slime_s,acid_slime_s'},
  {'Exordium Thugs',{false,false},{2,2},'acid_slime_m,looter'},
  {'Exordium Wildlife',{false},{1,0},'jaw_worm,green_louse'},
 }
 for _,r in ipairs(rows)do
  local callbacks,done=boundary(r[2],r[3])
  local s=C.new(Data,{deck={},seed=42,sourceEncounter=r[1],encounterBoundary=callbacks})
  equal(members(s),r[4]);equal(s.sourceEncounter,r[1]);done()
  for _,e in ipairs(s.enemies)do assert(e.hp>0 and e.intents[e.intentIndex] and e.statuses and e.sourcePosition)end
  if #s.enemies>1 then assert(s.enemies[1]~=s.enemies[2] and s.enemies[1].statuses~=s.enemies[2].statuses)end
 end
end)
test('discarded Louse still spends HP and Bite before all chosen actors initialize',function()
 local callbacks,done=boundary({false,false},{2,2});local original=C.random;local ranges={}
 C.random=function(s,max)ranges[#ranges+1]=max;return original(s,max)end
 local ok,s=pcall(C.new,Data,{deck={},seed=42,sourceEncounter='Exordium Thugs',encounterBoundary=callbacks})
 C.random=original;assert(ok,s);done();equal(members(s),'acid_slime_m,looter')
 -- All six candidates construct, including the discarded Louse's Bite sample.
 -- Only the two chosen actors roll opening AI; discarded Louse has no CurlUp.
 equal(table.concat(ranges,','),'7,3,5,5,7,5,5,100,100')
 equal(s.enemies[1].sourcePosition.x,-160);equal(s.enemies[2].sourcePosition.x,130)
end)
test('selected Louse constructor sampling precedes AI and later CurlUp',function()
 local callbacks=boundary({false,true},{});local original=C.random;local ranges={}
 C.random=function(s,max)ranges[#ranges+1]=max;return original(s,max)end
 local ok,s=pcall(C.new,Data,{deck={},seed=42,sourceEncounter='2 Louse',encounterBoundary=callbacks})
 C.random=original;assert(ok,s)
 equal(table.concat(ranges,','),'7,3,6,3,100,100,5,5')
 for _,e in ipairs(s.enemies)do assert(e.statuses.curl_up>=3 and e.statuses.curl_up<=7)end
end)
test('explicit enemy arrays remain unchanged and mixed/unknown group requests fail before boundaries',function()
 local s=C.new(Data,{deck={},seed=42,enemies={'acid_slime_m','spike_slime_m'}})
 equal(members(s),'acid_slime_m,spike_slime_m');equal(s.sourceEncounter,nil)
 local calls=0;local callback={misc={boolean=function()calls=calls+1;return true end}}
 assert(not pcall(C.new,Data,{sourceEncounter='medium_slimes',encounterBoundary=callback}))
 assert(not pcall(C.new,Data,{sourceEncounter=false,encounterBoundary=callback}))
 assert(not pcall(C.new,Data,{sourceEncounter='2 Louse',enemies={'cultist'},encounterBoundary=callback}))
 equal(calls,0)
end)
print('LUA_ENCOUNTER_FORMATION_COMBAT_PASS '..count)
