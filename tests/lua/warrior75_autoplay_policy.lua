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
r=run('defend');r.combat.hand[2]={uid=2,cardId='strike'};r.combat.nextUid=3
r.combat.enemies[1].statuses.enrage=2
r.combat.enemies[1].intents={{id='rush',kind='attack',effects={{op='damage',value=14}}}};r.combat.enemies[1].intentIndex=1
uid,target=P.chooseCombat(r);assert(uid==2,'visible Enrage must discourage unnecessary starter skills')
print('ok autoplay policy - visible Enrage favors a legal attack over unnecessary defensive skills')
