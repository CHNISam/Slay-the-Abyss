-- The branch predates the host's shared CardActions module. When integrated,
-- this regression runs against that real module, not a duplicate dispatcher.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local available,Actions=pcall(require,'abyss_card_actions')
if not available then print('LUA_PUZZLE_QUEUE_INTEGRATION_PENDING host CardActions absent');return end
local C,A,H,D=require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks'),require('abyss_data')
local damageActors=ABYSS_PUZZLE_DAMAGE_ACTORS or A
local s=assert(C.new(D,{seed=42,deck={'strike'},enemies={'cultist'}}))
H.bindBattle(s,{'centennial_puzzle'})
s.hand={{cardId='strike',uid=1000}}
s.draw={{cardId='strike',uid=2000},{cardId='burn',uid=2001},{cardId='defend',uid=2002},{cardId='dazed',uid=2003}}
s.discard={}
A.applyPower(s,s.player,'evolve',1,s.player)
A.applyPower(s,s.player,'fire_breathing',6,s.player)
local enemyHp=s.enemies[1].hp;local energy=s.energy
Actions.enqueue(s,{op='energy',value=1}) -- existing BOTTOM tail must stay behind TOP draw
damageActors.damage(s,s.enemies[1],s.player,1)
assert(#s.hand==1,'damage callback drew synchronously')
assert(s.player.hp==79 and s.relicCombat.centennialUsed)
assert(#s.cardActions==2 and s.cardActions[1].effect.op=='draw' and s.cardActions[1].effect.value==3)
assert(s.cardActions[2].effect.op=='energy')
local trace={};local draw,damage=C.draw,C.damage
C.draw=function(state,n)trace[#trace+1]='draw:'..string.format('%d',n);return draw(state,n)end
C.damage=function(state,source,target,n,...)
 trace[#trace+1]='damage:'..string.format('%d',n);return damage(state,source,target,n,...)
end
local ok,why=pcall(Actions.drain,C,s);C.draw,C.damage=draw,damage;assert(ok,why)
assert(table.concat(trace,',')=='draw:3,draw:1,damage:6,draw:1,damage:6',table.concat(trace,','))
assert(#s.hand==5 and #s.draw==0 and s.enemies[1].hp==enemyHp-12)
assert(s.energy==energy+1 and s.cardActions==nil and not s.pendingChoice)
damageActors.damage(s,s.enemies[1],s.player,1)
assert(s.cardActions==nil,'Puzzle triggered more than once in the same battle')
print('LUA_PUZZLE_QUEUE_PASS damage->TOP_queue->drain; evolve/fire_breathing order verified')
