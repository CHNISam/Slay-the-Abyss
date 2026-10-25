package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H=require('abyss_relic_hooks')
local run={relics={'burning_blood'},relicCounters={},gold=0,hp=80,maxHp=80}
assert(H.obtainCirclet(run));assert(#run.relics==2 and run.relics[2]=='circlet' and run.relicCounters.circlet==1)
assert(H.obtainCirclet(run));assert(#run.relics==2 and run.relicCounters.circlet==2)
assert(H.obtainCirclet(run));assert(#run.relics==2 and run.relicCounters.circlet==3)
H.onEquip(run,'circlet');assert(run.relicCounters.circlet==3,'onEquip must not double-count host-managed repeats')
assert(H.scoreAdjustment(run)==0)
run.relics[#run.relics+1]='spirit_poop';H.onEquip(run,'spirit_poop')
assert(H.scoreAdjustment(run)==-1 and run.hp==80 and run.gold==0)
local battle={relics={'warped_tongs'},player={hp=80},cardActions={{effect={op='draw',value=5}}}}
H.enqueuePostDraw(battle)
assert(#battle.cardActions==2 and battle.cardActions[1].effect.op=='draw')
assert(battle.cardActions[2].effect.op=='relicUpgradeRandomHand' and battle.cardActions[2].source==battle.player)
print('LUA_SPECIAL_RELIC_OBTAIN_PASS circlet repeat count and Spirit Poop score')
