local Run,C,D,E=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_events')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function state()
 local s=C.new(D,{deck={},enemies={'jaw_worm','jaw_worm'},seed=17,shuffleSeed='17'})
 for _,e in ipairs(s.enemies)do e.hp=1000;e.maxHp=1000;e.block=0;e.intents={{id='wait',effects={{op='block',value=0}}}};e.intentIndex=1;e.ai=nil end
 s.hand={};s.energy=99;return s
end
local function play(s,id,uid,suppressed)
 s.hand[#s.hand+1]={cardId=id,uid=uid,upgraded=false,dontTriggerOnUseCard=suppressed}
 return C.play(s,uid,1)
end
local s=state()
for i=1,19 do assert(play(s,'good_instincts',i))end
eq(s.scoreStats.combo,false);eq(s.scoreStats.turnCardCount,19)
assert(play(s,'good_instincts',20,true));eq(s.scoreStats.turnCardCount,19);eq(s.scoreStats.combo,false)
assert(play(s,'good_instincts',21));assert(s.scoreStats.combo);eq(s.scoreStats.turnCardCount,20)
s=state();for i=1,19 do assert(play(s,'good_instincts',i))end
assert(C.endTurn(s));assert(play(s,'good_instincts',30));eq(s.scoreStats.combo,false);eq(s.scoreStats.turnCardCount,1)
s=state();for i=1,18 do assert(play(s,'good_instincts',i))end
s.draw={{cardId='good_instincts',uid=30,upgraded=false}};assert(play(s,'havoc',31));assert(s.scoreStats.combo)
s=state();s.enemies[1].hp=1;assert(play(s,'hand_of_greed',1));eq(s.scoreStats.goldGained,20)
s=state();s.enemies[1].hp=1;s.player.statuses.strength=100;s.scoreStats.turnCardCount=19
local old=E.emit
E.emit=function(b,k,d)local out=old(b,k,d);if k=='gold'then error('late score rollback')end;return out end
local ok=pcall(play,s,'hand_of_greed',1);E.emit=old;eq(ok,false)
eq(s.scoreStats.goldGained,0);eq(s.scoreStats.turnCardCount,19);eq(s.scoreStats.combo,false);eq(s.scoreStats.overkill,false)
for _,tier in ipairs({'normal','elite'})do
 local r=Run.new(D,'42');r.floor=tier=='elite'and 7 or 1
 assert(Run.obtainPotion(r,'smoke_bomb'));assert(Run.startRoomCombat(r,tier))
 local b=r.combat;b.scoreStats.goldGained=20;b.scoreStats.combo=true;b.scoreStats.overkill=true
 assert(Run.usePotion(r,1));eq(r.scoreStats.goldGained,20);assert(r.scoreStats.combo and r.scoreStats.overkill)
 eq(r.scoreStats.normalWins,tier=='normal'and 1 or 0);eq(r.scoreStats.eliteWins[1],tier=='elite'and 1 or 0);eq(r.scoreStats.champion,0)
 eq(r.victories,0);assert(not Run.usePotion(r,1));eq(r.scoreStats.goldGained,20)
end
print('PASS score actual plays/autoplay/Greed/rollback/Smoke')
