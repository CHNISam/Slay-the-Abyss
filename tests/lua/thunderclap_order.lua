-- Fixed mirror expectations and limits: docs/rules/AREA_THORNS_ORDER.md.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Combat, data = require('abyss_combat'), require('abyss_data')
local count, failures = 0, {}
local function eq(a,b,label) assert(a == b, (label or 'value') .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b)) end
local function test(name,fn)
 local ok,why=pcall(fn);count=count+1
 if ok then print('ok '..count..' - '..name) else failures[#failures+1]=name..': '..tostring(why);print('not ok '..count..' - '..failures[#failures]) end
end
local function battle(upgraded)
 local s=Combat.new(data,{seed=42,enemies={'jaw_worm','jaw_worm'},deck={{cardId='thunderclap',upgraded=upgraded}}})
 for _,e in ipairs(s.enemies) do e.hp,e.maxHp=100,100 end
 s.events={}
 return s,s.hand[1]
end
local function play(s,c)
 assert(Combat.play(s,c.uid))
 eq(s.energy,2,'cost');eq(#s.hand,0);eq(#s.discard,s.player.hp>0 and 1 or 0);eq(#s.exhaust,0)
 if s.player.hp<=0 then eq(s.cardInUse,c) end
end
for _,v in ipairs({{up=false,base=4,name='base'},{up=true,base=7,name='upgraded'}}) do
 test(v.name..' damage precedes new Vulnerable for all targets',function()
  local s,c=battle(v.up);play(s,c)
  local damageLast,statusFirst=0,nil
  for i,e in ipairs(s.events) do
   if e.kind=='damage' then damageLast=i;eq(e.frame.enemies[1].statuses.vulnerable or 0,0,'frame no new Vulnerable') end
   if e.kind=='status' and e.detail.status=='vulnerable' then statusFirst=statusFirst or i end
  end
  assert(statusFirst and damageLast<statusFirst)
  for _,e in ipairs(s.enemies) do eq(e.hp,100-v.base);eq(e.statuses.vulnerable,1) end
 end)
 test(v.name..' existing Vulnerable boosts damage before duration stacks',function()
  local s,c=battle(v.up);Combat.addStatus(s.enemies[1],'vulnerable',2);play(s,c)
  eq(s.enemies[1].hp,100-math.floor(v.base*1.5));eq(s.enemies[1].statuses.vulnerable,3)
  eq(s.enemies[2].hp,100-v.base);eq(s.enemies[2].statuses.vulnerable,1)
 end)
 test(v.name..' full block does not prevent Vulnerable',function()
  local s,c=battle(v.up);s.enemies[1].block=20;play(s,c)
  eq(s.enemies[1].hp,100);eq(s.enemies[1].block,20-v.base);eq(s.enemies[1].statuses.vulnerable,1)
 end)
 test(v.name..' killed target skipped while survivor receives Vulnerable',function()
  local s,c=battle(v.up);s.enemies[1].hp=1;play(s,c)
  eq(s.enemies[1].hp,0);eq(s.enemies[1].statuses.vulnerable or 0,0)
  eq(s.enemies[2].hp,100-v.base);eq(s.enemies[2].statuses.vulnerable,1);eq(s.phase,'player')
 end)
 test(v.name..' zero attack still applies Vulnerable',function()
  local s,c=battle(v.up);Combat.addStatus(s.player,'strength',-10);play(s,c)
  for _,e in ipairs(s.enemies) do eq(e.hp,100);eq(e.statuses.vulnerable,1) end
 end)
 test(v.name..' lethal thorns cannot interrupt one area-damage action',function()
  local s,c=battle(v.up);s.player.hp=1;Combat.addStatus(s.enemies[1],'thorns',3);play(s,c)
  eq(s.enemies[1].hp,100-v.base);eq(s.enemies[2].hp,100-v.base,'second enemy must receive area damage before queued thorns')
  eq(s.player.hp,0);eq(s.phase,'defeat')
 end)
end

local function retaliations(s)
 local rows={}
 for _,e in ipairs(s.events) do if e.kind=='status_damage' and e.detail.status=='thorns' then rows[#rows+1]=e end end
 return rows
end
test('multiple Thorns resolve in reverse target order after all AoE damage',function()
 local s,c=battle(false);s.player.block=4
 Combat.addStatus(s.enemies[1],'thorns',3);Combat.addStatus(s.enemies[2],'thorns',5)
 play(s,c);eq(s.player.hp,76);eq(s.player.block,0)
 local r=retaliations(s);eq(#r,2);eq(r[1].detail.source,s.enemies[2].id);eq(r[1].detail.blocked,4);eq(r[1].detail.amount,1)
 eq(r[2].detail.source,s.enemies[1].id);eq(r[2].detail.blocked,0);eq(r[2].detail.amount,3)
 eq(r[1].frame.enemies[1].hp,96);eq(r[1].frame.enemies[2].hp,96)
 eq(s.enemies[1].statuses.vulnerable,1);eq(s.enemies[2].statuses.vulnerable,1)
 local lastDamage,lastThorns,firstThorns,firstStatus=0,0,nil,nil
 for i,e in ipairs(s.events) do
  if e.kind=='damage' then lastDamage=i end
  if e.kind=='status_damage' then firstThorns=firstThorns or i;lastThorns=i end
  if e.kind=='status' then firstStatus=firstStatus or i end
 end
 assert(lastDamage<firstThorns and lastThorns<firstStatus,'AoE, retaliation, then Vulnerable event ordering')
end)
test('killed targets retain queued retaliation before victory',function()
 local s,c=battle(false);for _,e in ipairs(s.enemies) do e.hp=1;Combat.addStatus(e,'thorns',3) end
 play(s,c);eq(s.player.hp,74);eq(s.phase,'victory');eq(#retaliations(s),2)
 eq(s.enemies[1].hp,0);eq(s.enemies[2].hp,0)
end)
test('all targets die before lethal queued retaliation yields defeat',function()
 local s,c=battle(false);s.player.hp=1;for _,e in ipairs(s.enemies) do e.hp=1;Combat.addStatus(e,'thorns',3) end
 play(s,c);eq(s.player.hp,0);eq(s.enemies[1].hp,0);eq(s.enemies[2].hp,0);eq(s.phase,'defeat')
end)
test('previously dead targets do not enqueue retaliation',function()
 local s,c=battle(false);s.enemies[1].hp=0;Combat.addStatus(s.enemies[1],'thorns',3)
 play(s,c);eq(s.player.hp,80);eq(#retaliations(s),0);eq(s.enemies[2].hp,96)
end)
test('zero damage and full enemy block still enqueue Thorns',function()
 local s,c=battle(false);Combat.addStatus(s.player,'strength',-10);s.enemies[2].block=20
 for _,e in ipairs(s.enemies) do Combat.addStatus(e,'thorns',3) end
 play(s,c);eq(s.player.hp,74);eq(#retaliations(s),2)
 for _,e in ipairs(s.enemies) do eq(e.hp,100);eq(e.statuses.vulnerable,1) end
end)
test('Cleave uses the same atomic area-damage boundary',function()
 local s,c=battle(false);c.cardId='cleave';s.player.hp=1;Combat.addStatus(s.enemies[1],'thorns',3)
 play(s,c);eq(s.enemies[1].hp,92);eq(s.enemies[2].hp,92);eq(s.phase,'defeat')
end)
test('later effect failure rolls back all area damage and queued retaliation',function()
 local s,c=battle(false);Combat.addStatus(s.enemies[1],'thorns',3)
 local effects=s.catalog.cards.thunderclap.effects;effects[#effects+1]={op='gainStatus',status='not_a_status',value=1}
 local ok=pcall(Combat.play,s,c.uid);assert(not ok);eq(s.energy,3);eq(#s.hand,1);eq(#s.discard,0);eq(#s.events,0)
 eq(s.player.hp,80);eq(s.enemies[1].hp,100);eq(s.enemies[2].hp,100)
 effects[#effects]=nil;play(s,c);eq(s.player.hp,77);eq(#retaliations(s),1)
end)
test('queued Thorns ignores attack modifiers and cannot recursively retaliate',function()
 local s,c=battle(false);s.player.block=2
 Combat.addStatus(s.player,'thorns',50);Combat.addStatus(s.player,'vulnerable',2)
 for _,e in ipairs(s.enemies) do Combat.addStatus(e,'thorns',3);Combat.addStatus(e,'strength',20);Combat.addStatus(e,'weak',1) end
 play(s,c);eq(s.player.hp,76);eq(#retaliations(s),2)
 eq(s.enemies[1].hp,96);eq(s.enemies[2].hp,96)
end)
test('area hit reduces Guardian Mode Shift before flushing defensive block',function()
 local s=Combat.new(data,{seed=42,enemies={'guardian','jaw_worm'},deck={'thunderclap'}})
 local g=s.enemies[1];Combat.damage(s,s.player,g,27,true)
 local other=s.enemies[2].hp;play(s,s.hand[1])
 eq(g.hp,209);eq(g.statuses.mode_shift,0);eq(g.block,20);eq(Combat.intent(s,1).id,'guardian_5')
 eq(s.enemies[2].hp,other-4)
end)
test('deferred retaliation still updates Guardian source HP-loss and mode hooks',function()
 local s=Combat.new(data,{seed=42,enemies={'guardian'},deck={'defend'}});local g=s.enemies[1]
 Combat.damage(s,s.player,g,29,true);Combat.addStatus(s.player,'thorns',3)
 -- Controlled interpreter boundary, not a claim that Guardian has an AoE intent.
 Combat.applyEffects(s,{{op='damageAll',value=5}},g,s.player)
 eq(g.hp,208);eq(g.statuses.mode_shift,0);eq(g.block,20);eq(Combat.intent(s,1).id,'guardian_5');eq(s.player.hp,75)
end)
test('deferred lethal retaliation clears pending Guardian transition',function()
 local s=Combat.new(data,{seed=42,enemies={'guardian'},deck={'defend'}});local g=s.enemies[1]
 Combat.damage(s,s.player,g,29,true);g.hp=2;Combat.addStatus(s.player,'thorns',3)
 Combat.applyEffects(s,{{op='damageAll',value=5}},g,s.player)
 eq(g.hp,0);eq(g.block,0);eq(g.aiShiftPending,nil);eq(Combat.outcome(s),'victory')
end)
local function multiBattle(hp)
 local s,c=battle(false);s.player.hp=hp or 80
 for _,e in ipairs(s.enemies) do Combat.addStatus(e,'thorns',3) end
 return s,c
end
local function damageSequence(s)
 local sequence={}
 for _,e in ipairs(s.events) do
  if e.kind=='damage' then sequence[#sequence+1]='d'
  elseif e.kind=='status_damage' and e.detail.status=='thorns' then sequence[#sequence+1]='t' end
 end
 return table.concat(sequence)
end
test('lethal retaliation stops subsequent area hits and later card effects',function()
 local s=multiBattle(7)
 -- Controlled supported interpreter input: no current card promises three AoE hits.
 Combat.applyEffects(s,{{op='damageAll',value=4,times=3},{op='energy',value=10},
  {op='block',value=10},{op='applyStatusAll',status='vulnerable',value=1}},s.player)
 eq(s.enemies[1].hp,92);eq(s.enemies[2].hp,92);eq(s.player.hp,0)
 eq(s.energy,3);eq(s.player.block,0);eq(s.enemies[1].statuses.vulnerable,nil)
 eq(s.enemies[2].statuses.vulnerable,nil);eq(damageSequence(s),'ddttddt')
end)
test('surviving area multihit drains a separate retaliation queue after each hit',function()
 local s=multiBattle()
 Combat.applyEffects(s,{{op='damageAll',value=4,times=2}},s.player)
 eq(s.player.hp,68);eq(s.enemies[1].hp,92);eq(s.enemies[2].hp,92)
 eq(damageSequence(s),'ddttddtt')
end)
test('single-target multihit still retaliates immediately and stops on death',function()
 local s=multiBattle(1)
 Combat.applyEffects(s,{{op='damage',value=4,times=2},{op='energy',value=5}},s.player,s.enemies[1])
 eq(s.enemies[1].hp,96);eq(s.enemies[2].hp,100);eq(s.energy,3);eq(s.player.hp,0)
 eq(damageSequence(s),'dt')
end)
test('area retaliation integration preserves signed status caps on both sides',function()
 local s=multiBattle()
 Combat.applyEffects(s,{{op='damageAll',value=4}},s.player)
 -- Integration guard against replacing Actor with the pre-cap candidate file.
 for _,a in ipairs({s.player,s.enemies[1]}) do
  for _,id in ipairs({'strength','dexterity'}) do
   Combat.addStatus(a,id,2000);eq(a.statuses[id],999)
   Combat.addStatus(a,id,-3000);eq(a.statuses[id],-999)
  end
 end
end)
if #failures>0 then error(table.concat(failures,'\n')) end
print('LUA_THUNDERCLAP_PASS '..count)
