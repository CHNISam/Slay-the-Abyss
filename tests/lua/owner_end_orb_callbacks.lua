package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Orbs=require('abyss_combat'),require('abyss_orbs')
local D=require('abyss_warrior_strength_cards').withCards(require('abyss_data'))
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function fresh(advanced)
 local s=C.new(D,{deck={'metallicize',{cardId='juggernaut',upgraded=true}},enemies={'cultist'},seed=42,orbSlots=2,cardRandomSeed='42'})
 s.experimentalMechanics=advanced
 for _,id in ipairs({'juggernaut','metallicize'})do for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid));break end end end
 Orbs.channel(s,'dark',C);Orbs.channel(s,'frost',C)
 return s
end
for _,advanced in ipairs({false,true})do
 local s=fresh(advanced);s.enemies[1].hp=1
 local counter=s.cardRandomRng.counter;assert(C.endTurn(s));eq(C.outcome(s),'victory')
 eq(s.player.block,5);eq(s.orbs.balls[1].stored,12);eq(s.cardRandomRng.counter,counter+1)
 print('PASS source GainBlock3 -> Orb trigger/Dark growth -> Juggernaut kill -> retained Frost2 '..tostring(advanced))
 local t=fresh(advanced);local trace={};local hp=t.enemies[1].hp;local block,damage=C.block,C.damage
 C.block=function(state,target,n,...)
  if state==t and target==t.player then trace[#trace+1]=string.format('block%d',n)end
  return block(state,target,n,...)
 end
 C.damage=function(state,source,target,n,...)
  if state==t and source==t.player and target==t.enemies[1]then
   eq(t.orbs.balls[1].stored,12);trace[#trace+1]=string.format('damage%d',n)
  end
  return damage(state,source,target,n,...)
 end
 counter=t.cardRandomRng.counter
 local ok,why=pcall(C.endTurn,t);C.block=block;C.damage=damage;assert(ok,why)
 eq(table.concat(trace,','),'block3,damage7,block2,damage7');eq(t.cardRandomRng.counter,counter+2)
 local frame;for _,e in ipairs(t.events)do if e.kind=='enemy_turn'then frame=e.frame;break end end
 eq(frame.player.block,5);eq(frame.enemies[1].hp,hp-14)
 print('PASS nonterminal BOT callback order and exactly two real cardRandom target draws '..tostring(advanced))
 local u=fresh(advanced);local before=C.copy(u);local player,ball,rng=u.player,u.orbs.balls[1],u.cardRandomRng
 local fired=false
 C.block=function(state,target,n,...)
  local result=block(state,target,n,...)
  if state==u and target==u.player and n==2 then
   eq(u.cardRandomRng.counter,rng.counter);eq(rng.counter,before.cardRandomRng.counter+1)
   fired=true;error('INJECTED_LATE_FROST_CALLBACK')
  end
  return result
 end
 ok,why=pcall(C.endTurn,u);C.block=block
 assert(not ok and fired and tostring(why):find('INJECTED_LATE_FROST_CALLBACK',1,true))
 same(u,before);eq(u.player,player);eq(u.orbs.balls[1],ball);eq(u.cardRandomRng,rng)
 print('PASS prelude late failure restores original actor/orb/RNG graphs and consumed target draw '..tostring(advanced))
end
print('OWNER_END_ORB_CALLBACKS_PASS')
