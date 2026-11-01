package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,Data=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local function battle(id)
 local r=Run.new(Data,42);assert(Run.obtainPotion(r,id));assert(Run.startCombat(r,'cultist_solo'))
 r.combat.hand={{cardId='strike',uid=1000},{cardId='defend',uid=1001},{cardId='bash',uid=1002}}
 return r,r.combat
end
local function choose(r,uid) assert(Run.chooseCard(r,r.combat.pendingChoice.token,uid)) end
for _,id in ipairs({'elixir','gamblers_brew'}) do
 local r,s=battle(id);local n=#s.hand;assert(Run.usePotion(r,1));assert(s.pendingChoice.multiple)
 choose(r,0);assert(not s.pendingChoice and #s.hand==n and not r.potions[1])
end
local r,s=battle('elixir');A.applyPower(s,s.player,'dark_embrace',1);A.applyPower(s,s.player,'feel_no_pain',3)
local draw=#s.draw;assert(Run.usePotion(r,1));local stale=s.pendingChoice.token
choose(r,1000);choose(r,1001);assert(#s.hand==3 and #s.exhaust==0)
local ok,reason=Run.chooseCard(r,stale,1002);assert(not ok and reason=='stale_card_choice')
choose(r,0);assert(#s.exhaust==2 and #s.hand==3 and s.player.block==6 and #s.draw==draw-2)
local g,gs=battle('gamblers_brew');assert(Run.usePotion(g,1));choose(g,1000);choose(g,1001);choose(g,0)
assert(#gs.hand==3 and #gs.discard==2 and gs.discard[1].uid==1000 and gs.discard[2].uid==1001)
local m,ms=battle('liquid_memories');ms.discard={{cardId='bash',uid=1100},{cardId='strike',uid=1101}}
assert(Run.usePotion(m,1));choose(m,1100)
assert(not ms.pendingChoice and #ms.hand==4 and #ms.discard==1)
assert(ms.hand[4].uid==1100 and ms.hand[4].costForTurn==0)
local full,fs=battle('liquid_memories');fs.hand={};for i=1,10 do fs.hand[i]={cardId='strike',uid=1200+i} end
fs.discard={{cardId='bash',uid=1400}};assert(Run.usePotion(full,1));assert(#fs.hand==10 and fs.discard[1].uid==1400)
for _,id in ipairs({'burn','whirlwind'}) do
 local r,s=battle('liquid_memories');s.discard={{cardId=id,uid=1600}}
 assert(Run.usePotion(r,1));local returned=s.hand[#s.hand]
 assert(returned.uid==1600 and returned.costForTurn==nil,'negative/X source cost cannot be changed by setCostForTurn')
end
local nodraw,ns=battle('gamblers_brew');ns.player.noDraw=true
assert(Run.usePotion(nodraw,1));choose(nodraw,1000);choose(nodraw,0);assert(#ns.hand==2 and #ns.discard==1)
local toggle,ts=battle('elixir');assert(Run.usePotion(toggle,1));choose(toggle,1000);choose(toggle,1000);choose(toggle,0)
assert(#ts.hand==3 and #ts.exhaust==0)
print('LUA_POTION_CHOICES_PASS 10')
