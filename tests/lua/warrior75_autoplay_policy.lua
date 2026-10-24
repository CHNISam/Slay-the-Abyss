package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P=dofile('scripts/warrior75-autoplay-policy.lua')
local C=require('abyss_combat')
local data=require('abyss_data')
local function run(id,hp)
 local b=C.new(data,{deck={id},hp=hp or 60,enemies={'cultist'},seed=42})
 return {phase='combat',combat=b,deck={{cardId=id}}}
end
local r=run('whirlwind');r.combat.energy=3
local uid,target=P.chooseCombat(r);assert(uid==r.combat.hand[1].uid and C.canPlay(r.combat,uid,target))
print('ok autoplay policy - X-cost is evaluated numerically and remains a legal command')
r=run('feel_no_pain');uid,target=P.chooseCombat(r);assert(uid==r.combat.hand[1].uid and C.canPlay(r.combat,uid,target))
print('ok autoplay policy - shared persistent power definitions are recognized')
r=run('offering',6);assert(not P.chooseCombat(r))
print('ok autoplay policy - declines a legal but lethal self-payment')
