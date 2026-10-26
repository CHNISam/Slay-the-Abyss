package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local R=require('abyss_run');local data=require('abyss_data')
local function setup(ids)
 local r=R.new(data,1);assert(R.startCombat(r,'cultist_solo'));local s=r.combat
 s.hand={};s.draw={};s.discard={};s.exhaust={};s.nextUid=101;s.energy=3;s.events={}
 for _,id in ipairs(ids) do s.hand[#s.hand+1]={uid=s.nextUid,cardId=id,upgraded=false};s.nextUid=s.nextUid+1 end
 return r,s
end
local function equal(a,b,seen)
 if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
 seen=seen or {};if seen[a]==b then return true end;seen[a]=b
 for k,v in pairs(a) do if not equal(v,b[k],seen) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local n=0
for _,id in ipairs({'strike','feed','fiend_fire','spot_weakness','disarm','body_slam'}) do
 local r,s=setup({id});local before=C.copy(s)
 for _,entry in ipairs({{}, {false}, {0}, {-1}, {1.5}, {99}, {'1'}, {{}}}) do
  local ok,reason=R.play(r,101,entry[1]);assert(not ok and reason=='invalid_target');assert(equal(s,before));n=n+1
 end
 local ok=R.play(r,101,1);assert(ok);print('PASS_TARGET '..id..' 8 malformed targets rejected atomically; valid target accepted')
end
for _,entry in ipairs({{}, {'101'}, {false}, {0}, {9999}, {{}}}) do
 local r,s=setup({'strike'});local before=C.copy(s);local ok,reason=R.play(r,entry[1],1)
 assert(not ok and reason=='card_not_in_hand' and equal(s,before));n=n+1
end
for _,up in ipairs({false,true}) do
 for _,energy in ipairs({0,2}) do
  local r,s=setup({'whirlwind'});s.hand[1].upgraded=up;s.energy=energy
  s.player.statuses.strength=2;local before=s.enemies[1].hp
  assert(R.play(r,101));local expected=energy*((up and 8 or 5)+2)
  assert(s.energy==0 and before-s.enemies[1].hp==expected)
  print('PASS_X upgraded='..tostring(up)..' energy='..energy..' damage='..expected)
 end
end
-- Source upgradeBaseCost preserves an already-zero temporary turn cost.
do
 local r,s=setup({'body_slam'});local c=s.hand[1];c.costForTurn=0;assert(C.upgrade(s,c));assert(C.cardDefinition(s,c).cost==0)
 assert(R.endTurn(r));assert(C.cardDefinition(s,c).cost==0);print('PASS_TEMP Body Slam zero turn cost + upgrade stays zero next turn')
end
do
 local r,s=setup({'blood_for_blood','bloodletting'});local c=s.hand[1];assert(R.play(r,102));assert(C.cardDefinition(s,c).cost==3)
 c.costForTurn=0;assert(C.upgrade(s,c));assert(C.cardDefinition(s,c).cost==0)
 assert(R.endTurn(r));assert(C.cardDefinition(s,c).cost==2);print('PASS_TEMP Existing Blood for Blood damage reduction + temporary zero + upgrade resets to two')
end
do
 local r,s=setup({'bludgeon'});s.energy=2;local before=C.copy(s);local ok,reason=R.play(r,101,1)
 assert(not ok and reason=='insufficient_energy' and equal(s,before));print('PASS_ENERGY Insufficient energy preserves full combat state')
end
print('Contract total: '..n..' malformed target/UID rejections, 4 X-cost cases, 2 temporary-cost upgrade cases, 1 energy rejection.')
