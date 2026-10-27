-- Controlled lethal boundaries test queue order, not a natural route.
local C,Orbs,Relics=require('abyss_combat'),require('abyss_orbs'),require('abyss_relic_hooks')
local D=require('abyss_warrior_strength_cards').withCards(require('abyss_data'))
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh(advanced,block)
 local s=C.new(D,{deck={'metallicize',{cardId='juggernaut',upgraded=true}},
  enemies={'cultist'},seed=42,orbSlots=2,cardRandomSeed='42'})
 Relics.bindBattle(s,{'orichalcum'},{}) -- The same real binding used by Inventory.opening.
 s.experimentalMechanics=advanced
 for _,id in ipairs({'juggernaut','metallicize'})do for _,card in ipairs(s.hand)do
  if card.cardId==id then assert(C.play(s,card.uid));break end
 end end
 Orbs.channel(s,'dark',C);Orbs.channel(s,'frost',C)
 s.player.block=block
 return s
end
local passed,failed=0,0
for _,advanced in ipairs({false,true})do for _,initial in ipairs({0,1})do
 local ok,why=pcall(function()
  local s=fresh(advanced,initial);s.enemies[1].hp=1
  local counter=s.cardRandomRng.counter;assert(C.endTurn(s))
  eq(C.outcome(s),'victory');eq(s.player.block,initial==0 and 11 or 6)
  eq(s.orbs.balls[1].stored,12);eq(s.cardRandomRng.counter,counter+1)
 end)
 if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..'Orichalcum hook eligibility before Metallicize/Orb/Juggernaut '..tostring(advanced)..' block'..initial..(ok and ''or ': '..tostring(why)))
end end
for _,advanced in ipairs({false,true})do
 local ok,why=pcall(function()
  local s=fresh(advanced,0);local block,damage=C.block,C.damage;local trace={}
  local counter=s.cardRandomRng.counter
  C.block=function(state,target,n,...)
   if state==s and target==s.player then trace[#trace+1]='block'..string.format('%.0f',n)end
   return block(state,target,n,...)
  end
  C.damage=function(state,source,target,n,...)
   if state==s and source==s.player and target==s.enemies[1]then
    eq(s.orbs.balls[1].stored,12);trace[#trace+1]='damage'..string.format('%.0f',n)
   end
   return damage(state,source,target,n,...)
  end
  local called,reason=pcall(C.endTurn,s);C.block=block;C.damage=damage;assert(called,reason)
  eq(table.concat(trace,','),'block6,block3,damage7,damage7,block2,damage7')
  eq(s.cardRandomRng.counter,counter+3)
 end)
 if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..'Orichalcum prelude queues all three source BOT target draws '..tostring(advanced)..(ok and ''or ': '..tostring(why)))
end
for _,advanced in ipairs({false,true})do
 local ok,why=pcall(function()
  local s=C.new(D,{deck={},enemies={'cultist'},seed=42})
  s.experimentalMechanics=advanced;Relics.bindBattle(s,{'orichalcum'},{})
  local player,events,held=s.player,s.events,s.relics;local count=#events
  local block=C.block
  C.block=function(state,...)
   local amount=block(state,...)
   if state==s then error('INJECTED_ORICHALCUM_BLOCK',0)end
   return amount
  end
  local called,reason=pcall(C.endTurn,s);C.block=block
  assert(not called and tostring(reason):find('INJECTED_ORICHALCUM_BLOCK',1,true))
  eq(s.player,player);eq(s.events,events);eq(s.relics,held);eq(#events,count)
  eq(s.phase,'player');eq(s.player.block,0);eq(s.actionQueue,nil)
  assert(C.endTurn(s))
  local blocks=0;for i=count+1,#events do
   if events[i].kind=='block'and events[i].detail.amount==6 then blocks=blocks+1 end
  end;eq(blocks,1)
 end)
 if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..'Orichalcum-only prelude failure keeps original owners and retries once '..tostring(advanced)..(ok and ''or ': '..tostring(why)))
end
print('OWNER_END_ORICHALCUM '..passed..' passed; '..failed..' failed')
assert(failed==0)
