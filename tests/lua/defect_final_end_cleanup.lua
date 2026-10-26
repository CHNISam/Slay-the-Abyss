package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,P,D=require('abyss_combat'),require('abyss_card_actions'),require('abyss_character_profiles'),require('abyss_data')
local data=P.prepare(D,'defect')
local s=C.new(data,{deck={},enemies={'cultist'},seed=42,orbSlots=0,cardRandomSeed='17'})
for _,id in ipairs({'amplify','rebound'})do local c=A.fresh(C,s,id);s.hand={c};s.energy=10;assert(C.play(s,c.uid,1))end
assert(s.player.statuses.amplify==1 and s.player.statuses.rebound==1)
local regret=A.fresh(C,s,'regret');s.hand={regret};s.player.hp=1;assert(C.endTurn(s))
assert(s.player.hp==0 and s.cardInUse==regret)
assert(s.player.statuses.amplify==1 and s.player.statuses.rebound==1,'lethal Regret stops before ordinary Power atEndOfTurn')
s=C.new(data,{deck={},enemies={'cultist'},seed=42,orbSlots=0,cardRandomSeed='17'})
for _,id in ipairs({'amplify','rebound'})do local c=A.fresh(C,s,id);s.hand={c};s.energy=10;assert(C.play(s,c.uid,1))end
s.hand={A.fresh(C,s,'regret')};s.player.hp=5;assert(C.endTurn(s))
assert(not s.player.statuses.amplify and not s.player.statuses.rebound,'surviving end-turn card reaches ordinary Power removal')
print('DEFECT_FINAL_END_CLEANUP_PASS lethal Regret stops ordinary Power removal; surviving Regret reaches removal')
