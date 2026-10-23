-- Source-derived A0 trace, independent of data-driven expected values.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C = require('abyss_combat')
local data = require('abyss_data')
local n, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,f) n=n+1; local ok,e=pcall(f); if not ok then failed=failed+1 end; print((ok and 'ok ' or 'not ok ')..n..' - '..name..(ok and '' or ': '..tostring(e))) end
local function battle(seed, enemies, d) return C.new(d or data,{enemies=enemies or {'wizard_gremlin'},seed=seed or 42,deck={'defend'}}) end

test('opening charge is empty and does not create block or statuses',function()
 local s=battle(); eq(C.intent(s,1).kind,'charge'); eq(#C.intent(s,1).effects,0)
 assert(C.endTurn(s)); eq(s.player.hp,80); eq(s.enemies[1].block,0); eq(next(s.enemies[1].statuses),nil)
end)
test('eleven actual turns attack only on 3,7,11 after reset to zero',function()
 local s=battle()
 for t,d in ipairs({0,0,25,0,0,0,25,0,0,0,25}) do
  eq(C.intent(s,1).kind,d==0 and 'charge' or 'attack','intent turn '..t)
  local hp=s.player.hp; assert(C.endTurn(s)); eq(hp-s.player.hp,d,'damage turn '..t); eq(s.enemies[1].block,0)
 end
 eq(s.player.hp,5)
end)
test('HP samples cover exactly 21 through25, maxHp and repeatability',function()
 local seen={}
 for seed=0,127 do local s=battle(seed); local e=s.enemies[1]; assert(e.hp>=21 and e.hp<=25); eq(e.maxHp,e.hp); eq(battle(seed).enemies[1].hp,e.hp); seen[e.hp]=true end
 for hp=21,25 do assert(seen[hp],'missing HP '..hp) end
end)
test('preview and catalog do not mutate per-instance charge state',function()
 local s=battle(1,{'wizard_gremlin','wizard_gremlin'}); local fresh=battle(1)
 local preview=C.intent(s,1); preview.kind='buff'; preview.effects[1]={op='block',value=99}
 assert(C.endTurn(s)); eq(s.enemies[1].aiCharge,2); eq(s.enemies[2].aiCharge,2); eq(fresh.enemies[1].aiCharge,1)
 s.enemies[1].aiCharge=0; assert(C.endTurn(s)); eq(C.intent(s,1).kind,'charge'); eq(C.intent(s,2).kind,'attack')
 eq(fresh.enemies[1].aiCharge,1); eq(next(data.enemies.enemies[1].statuses or {}),nil)
end)
test('lethal poison prevents charge and preserves surviving ally',function()
 local s=battle(42,{'wizard_gremlin','wizard_gremlin'}); local e=s.enemies[1]; e.hp=1; C.addStatus(e,'poison',1)
 assert(C.endTurn(s)); eq(e.hp,0); eq(e.aiCharge,1); eq(s.enemies[2].aiCharge,2)
end)
test('lethal thorns prevents charge advance after attack',function()
 local s=battle(42,{'wizard_gremlin','wizard_gremlin'}); assert(C.endTurn(s)); assert(C.endTurn(s))
 s.enemies[1].hp=1; C.addStatus(s.player,'thorns',1); assert(C.endTurn(s)); eq(s.enemies[1].hp,0); eq(s.enemies[1].aiCharge,0,'reset before lethal retaliation'); eq(s.enemies[2].aiCharge,0)
end)
test('attack uses existing Strength and Weak arithmetic',function()
 local s=battle(); assert(C.endTurn(s)); assert(C.endTurn(s)); C.addStatus(s.enemies[1],'strength',3); C.addStatus(s.enemies[1],'weak',2)
 local hp=s.player.hp; assert(C.endTurn(s)); eq(hp-s.player.hp,21)
end)
test('charge rejects nonempty effects through actual Combat constructor',function()
 local d=C.copy(data); for _,e in ipairs(d.enemies.enemies) do if e.id=='wizard_gremlin' then e.intents[1].effects={{op='block',value=3}} end end
 assert(not pcall(battle,42,nil,d))
end)
test('orphan charge cannot bypass supported-effect validation',function()
 local d=C.copy(data); for _,e in ipairs(d.enemies.enemies) do if e.id=='wizard_gremlin' then e.ai=nil; e.intents[1].kind='charge'; e.intents[1].effects={} end end
 assert(not pcall(battle,42,nil,d))
end)
print('WIZARD_GREMLIN '..(n-failed)..'/'..n); assert(failed==0,'Wizard failures '..failed)
