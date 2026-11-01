package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Actor = require("abyss_actor")
local data = require("abyss_data")
local count, failed = 0, 0
local function eq(a,b) assert(a==b, 'expected '..tostring(b)..', got '..tostring(a)) end
local function test(name, fn)
 count=count+1; local ok,err=pcall(fn); if not ok then failed=failed+1 end
 print((ok and 'ok ' or 'not ok ')..count..' - '..name..(ok and '' or ': '..tostring(err)))
end
local function battle() return Combat.new(data,{deck={'strike','defend','flex'},enemies={'jaw_worm'},seed=42}) end
for _, id in ipairs({'strength','dexterity'}) do
 for _, enemy in ipairs({false,true}) do
  test(id..' caps on initial application and accumulation, actor='..tostring(enemy),function()
   for _, row in ipairs({{0,1000,999},{0,-1000,-999},{998,2,999},{-998,-2,-999},{999,2,999},{-999,-2,-999},{999,-2,997},{-999,2,-997},{2,-2,0},{-2,2,0}}) do
    local s=battle();local a=enemy and s.enemies[1] or s.player
    if row[1]~=0 then Actor.addStatus(a,id,row[1]) end
    Actor.addStatus(a,id,row[2]);eq(a.statuses[id],row[3])
   end
  end)
 end
 test(id..' emitted amount is actual capped delta and snapshot',function()
  local s=battle();Actor.addStatus(s.player,id,998);Actor.status(s,s.player,id,4)
  local e=s.events[#s.events];eq(e.detail.amount,1);eq(e.frame.player.statuses[id],999)
  Actor.status(s,s.player,id,4);eq(s.events[#s.events].detail.amount,0)
 end)
end
test('capped strength affects attack and capped dexterity precedes frail',function()
 local s=battle(); Actor.addStatus(s.player,'strength',1000);eq(Actor.attackAmount(s,s.player,s.enemies[1],6),1005)
 Actor.addStatus(s.player,'dexterity',1000);Actor.addStatus(s.player,'frail',1);eq(Actor.blockAmount(s,s.player,5),753)
end)
for _, gain in ipairs({2,4}) do
 test('Flex requested '..gain..' debt remains full when strength cap truncates gain',function()
  local s=battle();Actor.addStatus(s.player,'strength',998);Actor.addTemporaryStrength(s.player,gain)
  eq(s.player.statuses.strength,999);eq(s.player.temporaryStrength,gain)
  Actor.endTurn(s,s.player);eq(s.player.statuses.strength,999-gain);eq(s.player.temporaryStrength,0)
 end)
end
for _, upgraded in ipairs({false,true}) do
 test('real Flex card at strength cap, upgraded='..tostring(upgraded),function()
  local s=Combat.new(data,{deck={'strike',{cardId='flex',upgraded=upgraded}},enemies={'jaw_worm'},seed=42})
  Actor.addStatus(s.player,'strength',998)
  local card;for _,v in ipairs(s.hand) do if v.cardId=='flex' then card=v end end;assert(card)
  local energy=s.energy;assert(Combat.play(s,card.uid));eq(s.energy,energy)
  eq(s.player.statuses.strength,999);eq(s.player.temporaryStrength,upgraded and 4 or 2)
  eq(#s.discard,1);eq(s.discard[1].uid,card.uid)
  assert(Combat.endTurn(s));eq(s.player.statuses.strength,upgraded and 995 or 997)
  eq(s.player.temporaryStrength,0)
 end)
end
test('unrelated intensity is not globally capped',function()
 local s=battle();Actor.addStatus(s.player,'poison',1000);eq(s.player.statuses.poison,1000)
end)
assert(failed==0,tostring(failed)..' failures');print('LUA_SIGNED_STATUS_CAPS_PASS '..count)
