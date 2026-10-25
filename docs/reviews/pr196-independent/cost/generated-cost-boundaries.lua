package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R=require('abyss_run');local C=require('abyss_combat');local A=require('abyss_card_actions');local D=require('abyss_data')
local failed,total=0,0
local function eq(a,b) assert(a==b,'expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn) total=total+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err))) end
local function setup(ids,seed)
 local r=R.new(D,seed or 1);assert(R.startCombat(r,'cultist_solo'));local s=r.combat
 s.hand={};s.draw={};s.discard={};s.exhaust={};s.nextUid=101;s.energy=3
 for _,id in ipairs(ids) do s.hand[#s.hand+1]={uid=s.nextUid,cardId=id,upgraded=false};s.nextUid=s.nextUid+1 end
 return r,s
end
test('Initial permanent BFB starts at four, one later HP loss lowers it to three',function()
 local r,s=setup({'blood_for_blood','bloodletting'});eq(C.cardDefinition(s,s.hand[1]).cost,4);assert(R.play(r,102));eq(C.cardDefinition(s,s.hand[1]).cost,3)
end)
test('Unhurt fresh BFB starts at four',function()
 local r,s=setup({});local c=A.fresh(C,s,'blood_for_blood');eq(C.cardDefinition(s,c).cost,4)
end)
for _,losses in ipairs({1,3,5}) do
 test('Fresh and then upgraded BFB inherit '..losses..' actual HP-loss events',function()
  local ids={};for _=1,losses do ids[#ids+1]='bloodletting' end
  local r,s=setup(ids);for i=1,losses do assert(R.play(r,100+i)) end;eq(s.player.damagedThisCombat,losses)
  local c=A.fresh(C,s,'blood_for_blood');eq(C.cardDefinition(s,c).cost,math.max(0,4-losses));assert(C.upgrade(s,c));eq(C.cardDefinition(s,c).cost,math.max(0,3-losses))
 end)
end
test('Stat-equivalent prototype retains its own discount, upgrade and turn override',function()
 local r,s=setup({});s.player.damagedThisCombat=3
 local p={uid=9,cardId='blood_for_blood',upgraded=true,upgrades=1,costReduction=1,costForTurn=0}
 local c=A.fresh(C,s,'blood_for_blood',p);assert(c~=p and c.uid~=p.uid);eq(c.costReduction,1);eq(c.upgraded,true);eq(C.cardDefinition(s,c).cost,0);c.costForTurn=nil;eq(C.cardDefinition(s,c).cost,2)
end)
test('Unrelated generated attack gains no BFB cost state',function()
 local r,s=setup({});s.player.damagedThisCombat=3;local c=A.fresh(C,s,'strike');eq(c.costReduction,nil);eq(C.cardDefinition(s,c).cost,1)
end)
for _,hurt in ipairs({false,true}) do
 for _,upgrade in ipairs({false,true}) do
  test('Real Infernal generation, free current turn, next-turn reset: hurt='..tostring(hurt)..' upgrade='..tostring(upgrade),function()
   local r,s=setup({'bloodletting','infernal_blade','armaments'},30)
   if hurt then assert(R.play(r,101)) else table.remove(s.hand,1) end
   assert(R.play(r,102));local c=s.hand[#s.hand];eq(c.cardId,'blood_for_blood');eq(C.cardDefinition(s,c).cost,0)
   if upgrade then assert(R.play(r,103));eq(c.upgraded,true) end
   eq(C.cardDefinition(s,c).cost,0);assert(R.endTurn(r));eq(C.cardDefinition(s,c).cost,(upgrade and 3 or 4)-(hurt and 1 or 0))
  end)
 end
end
print('TOTAL '..total..' cases, '..failed..' failed');assert(failed==0,'generated BFB boundary regressions')
