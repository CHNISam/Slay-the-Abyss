package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,Actions=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fresh()
 local r=Run.new(Data,42,{character='defect',experimental=true});assert(Run.obtainRelic(r,'TungstenRod'));assert(Run.startCombat(r,'cultist_solo'))
 return r,r.combat
end
local function power(s,id)
 local card=Actions.fresh(C,s,id);Actions.toHand(s,card);assert(C.play(s,card.uid))
end
do
 local _,s=fresh();power(s,'static_discharge');local count=#s.orbs.balls;local hp=s.player.hp
 eq(C.damage(s,s.enemies[1],s.player,1,false),0);eq(s.player.hp,hp);eq(#s.orbs.balls,count+1)
 eq(s.orbs.balls[#s.orbs.balls].kind,'lightning');eq(s.player.damagedThisCombat or 0,0)
 print('PASS real Static onAttacked sees positive one before Rod and channels without HP loss')
end
do
 local _,s=fresh();power(s,'buffer');power(s,'static_discharge');local count=#s.orbs.balls;local hp=s.player.hp
 s.player.block=1;eq(C.damage(s,s.enemies[1],s.player,1,false),0);eq(s.player.statuses.buffer,1);eq(#s.orbs.balls,count)
 eq(C.damage(s,s.enemies[1],s.player,1,false),0);eq(s.player.statuses.buffer,nil);eq(#s.orbs.balls,count);eq(s.player.hp,hp)
 eq(C.damage(s,s.enemies[1],s.player,1,false),0);eq(#s.orbs.balls,count+1)
 print('PASS full block preserves Buffer; Buffer precedes Static and Rod; next hit channels')
end
do
 local _,s=fresh();power(s,'static_discharge');assert(A.applyPower(s,s.player,'intangible',1,s.player))
 local count,hp=#s.orbs.balls,s.player.hp
 eq(C.damage(s,s.enemies[1],s.player,100,false),0);eq(s.player.hp,hp);eq(#s.orbs.balls,count+1)
 eq(A.retaliate(s,s.enemies[1],s.player,100),0);eq(A.loseHp(s,s.player,100),0)
 eq(s.player.hp,hp);eq(#s.orbs.balls,count+1)
 print('PASS Intangible caps each damage type before Rod, only NORMAL queues Static')
end
do
 local _,s=fresh();local hp=s.player.hp;s.player.block=2
 eq(C.damage(s,s.enemies[1],s.player,3,false),0);eq(s.player.block,0)
 for i=1,3 do eq(C.damage(s,s.enemies[1],s.player,2,false),1)end
 eq(s.player.hp,hp-3);eq(s.player.damagedThisCombat,3)
 -- Rod belongs to the player, never an enemy sharing this combat owner.
 local before=s.enemies[1].hp;eq(C.damage(s,s.player,s.enemies[1],1,true),1);eq(s.enemies[1].hp,before-1)
 print('PASS remaining block precedes per-hit Rod and only actual HP losses notify; enemy is unaffected')
end
print('TUNGSTEN_ROD_INTERACTIONS_PASS 4')
