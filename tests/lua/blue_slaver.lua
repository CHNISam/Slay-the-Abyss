-- Source-derived action values; not certification of selection RNG or Weak decay.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Combat=require('abyss_combat')
local data=require('abyss_data')
local passed,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn) local ok,err=pcall(fn); if ok then passed=passed+1; print('ok - '..name) else failed=failed+1; print('not ok - '..name..': '..err) end end
local function battle(seed,enemies) return Combat.new(data,{enemies=enemies or {'blue_slaver'},deck={'defend'},seed=seed or 42}) end
local function rake(s) s.enemies[1].intentIndex=2; s.events={}; assert(Combat.endTurn(s)) end

test('Stab remains 12 damage without Weak',function()
 local s=battle(); assert(Combat.endTurn(s)); eq(s.player.hp,68); eq(s.player.statuses.weak or 0,0)
end)
test('Rake deals 7 then applies Weak 1',function()
 local s=battle(); rake(s); eq(s.player.hp,73); eq(s.player.statuses.weak,1)
 local hit,weak
 for i,e in ipairs(s.events) do
  if e.kind=='damage' and e.detail.target==s.player.id then hit=i; eq(e.detail.amount,7) end
  if e.kind=='status' and e.detail.status=='weak' and e.detail.target==s.player.id then weak=i; eq(e.detail.amount,1) end
 end
 assert(hit and weak and hit<weak,'damage must precede Weak')
end)
test('Rake intent exposes damage rather than debuff-only',function()
 local s=battle(); s.enemies[1].intentIndex=2; local i=Combat.intent(s,1); eq(i.kind,'attack'); eq(i.effects[1].op,'damage'); eq(i.effects[1].value,7)
end)
test('full block absorbs Rake but does not prevent Weak',function()
 local s=battle(); s.player.block=7; Combat.addStatus(s.player,'barricade',1); rake(s); eq(s.player.hp,80); eq(s.player.block,0); eq(s.player.statuses.weak,1)
end)
test('zero modified damage still applies Weak',function()
 local s=battle(); Combat.addStatus(s.enemies[1],'strength',-7); rake(s); eq(s.player.hp,80); eq(s.player.statuses.weak,1)
end)
test('Rake uses existing strength Weak Vulnerable and block modifiers',function()
 local s=battle(); Combat.addStatus(s.enemies[1],'strength',3); Combat.addStatus(s.enemies[1],'weak',1)
 Combat.addStatus(s.player,'vulnerable',2); Combat.addStatus(s.player,'barricade',1); s.player.block=4
 rake(s); eq(s.player.hp,73); eq(s.player.block,0); eq(s.player.statuses.weak,1) -- floor(10*.75*1.5)-4=7
end)
test('actual HP sampling reaches all five inclusive values reproducibly',function()
 local seen={}
 for seed=0,127 do local a,b=battle(seed),battle(seed); local e=a.enemies[1]; assert(e.hp>=46 and e.hp<=50); eq(e.maxHp,e.hp); eq(b.enemies[1].hp,e.hp); seen[e.hp]=true end
 for hp=46,50 do assert(seen[hp],'missing HP '..hp) end
end)
test('Rake state and preview are isolated across instances',function()
 local a,b=battle(),battle(); a.enemies[1].intentIndex=2
 local i=Combat.intent(a,1); i.effects[1].value=100; rake(a); eq(a.player.hp,73); eq(b.player.hp,80); eq(b.enemies[1].intentIndex,1); eq(b.player.statuses.weak,nil)
end)
test('two Blue Slavers each resolve their own Rake',function()
 local s=battle(42,{'blue_slaver','blue_slaver'}); s.enemies[1].intentIndex=2;s.enemies[2].intentIndex=2
 assert(Combat.endTurn(s));eq(s.player.hp,66);eq(s.player.statuses.weak,2)
end)
print(passed..' passed, '..failed..' failed'); assert(failed==0,'Blue Slaver regressions failed')
