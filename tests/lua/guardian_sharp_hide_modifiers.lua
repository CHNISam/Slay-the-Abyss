package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,D=require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function card(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error('missing '..id)
end
local function closeUp(rod,deck)
 local s=C.new(D,{seed=42,deck=deck or {'bludgeon','body_slam','body_slam'},enemies={'guardian'},beforeFirstTurn=function(state)
  state.relics=rod and {'tungsten_rod'} or {};return true
 end})
 assert(C.play(s,card(s,'bludgeon').uid,1));eq(s.enemies[1].hp,208)
 assert(C.endTurn(s));eq(s.enemies[1].statuses.sharp_hide,3)
 return s,s.enemies[1]
end
local function body(s)return C.play(s,card(s,'body_slam').uid,1)end
local function last(s)
 for i=#s.events,1,-1 do local e=s.events[i]
  if e.kind=='status_damage'and e.detail.status=='sharp_hide'then return e.detail end
 end
 error('missing Sharp Hide event')
end
for _,rod in ipairs({false,true})do
 local s=closeUp(rod);local hp=s.player.hp
 assert(A.applyPower(s,s.player,'intangible',1,s.player));assert(body(s))
 local loss=rod and 0 or 1;eq(s.player.hp,hp-loss);eq(last(s).amount,loss)
 eq(s.player.damagedThisCombat or 0,rod and 0 or 1)
 print('PASS real Sharp Hide Intangible then Rod='..tostring(rod))
end
do
 local s=closeUp(true);local hp=s.player.hp
 -- Explicit Buffer Power boundary; Sharp Hide itself is obtained by Close Up.
 s.player.statuses.buffer=1;assert(body(s))
 eq(s.player.hp,hp);eq(s.player.statuses.buffer,nil);eq(last(s).amount,0)
 eq(s.player.damagedThisCombat or 0,0)
 assert(body(s));eq(s.player.hp,hp-2);eq(s.player.damagedThisCombat,1)
 print('PASS Buffer consumes before Rod; following real attack pays one reduced hit')
end
do
 local s=closeUp(true);local hp=s.player.hp
 s.player.statuses.buffer=1;C.block(s,s.player,3,true);assert(body(s))
 eq(s.player.hp,hp);eq(s.player.block,0);eq(s.player.statuses.buffer,1)
 eq(last(s).amount,0);eq(last(s).blocked,3)
 print('PASS fully blocked Sharp Hide preserves Buffer')
end
do
 local s=closeUp(true);local hp=s.player.hp
 C.block(s,s.player,2,true);assert(body(s))
 eq(s.player.hp,hp);eq(s.player.block,0);eq(last(s).amount,0);eq(last(s).blocked,2)
 eq(s.player.damagedThisCombat or 0,0)
 print('PASS partial block then Rod prevents the final one without HP-loss notification')
end
do
 local s,e=closeUp(true);local hp,enemyHp=s.player.hp,e.hp
 assert(body(s));assert(body(s));eq(s.player.hp,hp-4);eq(e.hp,enemyHp)
 eq(s.player.damagedThisCombat,2)
 print('PASS zero-damage attacks each retain one distinct Sharp Hide hit and HP notification')
end
do
 local s,e=closeUp(true);local hp,enemyHp=s.player.hp,e.hp
 e.statuses.strength=100;e.statuses.weak=1
 s.player.statuses.vulnerable=1;s.player.statuses.thorns=100
 assert(A.applyPower(s,s.player,'rupture',1,s.player));assert(body(s))
 eq(s.player.hp,hp-2);eq(e.hp,enemyHp);eq(s.player.statuses.strength or 0,0)
 print('PASS THORNS ignores attack modifiers and cannot recursively trigger Thorns or Rupture')
end
do
 local s,e=closeUp(true);local hp=s.player.hp
 eq(A.retaliate(s,e,s.player,3),2);eq(s.player.hp,hp-2)
 eq(s.events[#s.events].kind,'status_damage');eq(s.events[#s.events].detail.status,'thorns')
 print('PASS four-argument Actor retaliate retains its original thorns event label')
end
print('GUARDIAN_SHARP_HIDE_MODIFIERS_PASS 8')
