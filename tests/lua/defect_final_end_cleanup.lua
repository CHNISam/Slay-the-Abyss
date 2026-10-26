package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,P,D=require('abyss_combat'),require('abyss_card_actions'),require('abyss_character_profiles'),require('abyss_data')
local data=P.prepare(D,'defect')
local s=C.new(data,{deck={},enemies={'cultist'},seed=42,orbSlots=0,cardRandomSeed='17'})
for _,id in ipairs({'amplify','rebound'})do local c=A.fresh(C,s,id);s.hand={c};s.energy=10;assert(C.play(s,c.uid,1))end
assert(s.player.statuses.amplify==1 and s.player.statuses.rebound==1)
local regret=A.fresh(C,s,'regret');s.hand={regret};s.player.hp=1;assert(C.endTurn(s))
assert(s.player.hp==0 and s.cardInUse==regret)
assert(not s.player.statuses.amplify and not s.player.statuses.rebound,'end-of-turn removal must precede lethal Regret')
print('DEFECT_FINAL_END_CLEANUP_PASS source Power removal precedes lethal end-turn card without losing in-use UID')
