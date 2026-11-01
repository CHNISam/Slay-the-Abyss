package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,P,D=require('abyss_combat'),require('abyss_card_actions'),require('abyss_character_profiles'),require('abyss_data')
local data=P.prepare(D,'defect')
local function setup(id,up)
 local s=C.new(data,{deck={},enemies={'jaw_worm'},seed=42,orbSlots=3,cardRandomSeed='17'})
 local c=A.fresh(C,s,id);c.upgraded=up;s.hand={c};s.energy=10;assert(C.play(s,c.uid));return s
end
for _,up in ipairs({false,true})do
 local s=setup('buffer',up);local hp=s.player.hp;local n=up and 2 or 1
 s.player.block=6;C.damage(s,s.enemies[1],s.player,6);assert(s.player.hp==hp and s.player.statuses.buffer==n)
 C.damage(s,s.enemies[1],s.player,6);assert(s.player.hp==hp and (s.player.statuses.buffer or 0)==n-1)
 if up then C.applyEffects(s,{{op='loseHp',value=3}},s.player,s.player);assert(s.player.hp==hp and not s.player.statuses.buffer)end
 C.damage(s,s.enemies[1],s.player,6);assert(s.player.hp==hp-6)
 s=setup('static_discharge',up);local before=s.cardRandomRng.counter
 C.damage(s,s.enemies[1],s.player,1);assert(#s.orbs.balls==(up and 2 or 1));assert(s.cardRandomRng.counter==before)
 local count=#s.orbs.balls;s.player.block=20;C.damage(s,s.enemies[1],s.player,1);assert(#s.orbs.balls==count)
 s.player.block=0;C.retaliate(s,s.enemies[1],s.player,1);assert(#s.orbs.balls==count)
 C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player);assert(#s.orbs.balls==count)
 s=setup('static_discharge',up);local b=A.fresh(C,s,'buffer');s.hand={b};s.energy=10;assert(C.play(s,b.uid))
 C.damage(s,s.enemies[1],s.player,4);assert(#s.orbs.balls==0)
 s=setup('static_discharge',up);s.player.hp=1;C.damage(s,s.enemies[1],s.player,4);assert(s.player.hp==0 and #s.orbs.balls==0)
end
local s=setup('buffer');local hp=s.player.hp;C.damage(s,nil,s.player,3,true);assert(s.player.hp==hp and not s.player.statuses.buffer)
s=setup('buffer');hp=s.player.hp;C.retaliate(s,s.enemies[1],s.player,3);assert(s.player.hp==hp and not s.player.statuses.buffer)
print('DEFECT_FINAL_DEFENSES_PASS Buffer post-block/all damage types, Static external NORMAL only, blocked/buffer/fatal no channels')
