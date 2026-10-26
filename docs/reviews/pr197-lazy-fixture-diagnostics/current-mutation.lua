package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local mode=assert(os.getenv('MUTATION'))
local real=Run.usePotion
Run.usePotion=function(run,...)
 local ok,reason=real(run,...)
 if not ok then
  if mode=='seed' then run.seed=run.seed+1
  elseif mode=='data' then run.data.rules.player.maxHp=run.data.rules.player.maxHp+1
  elseif mode=='deck' then run.deck=C.copy(run.deck)
  elseif mode=='potions' then run.potions=C.copy(run.potions)
  elseif mode=='combat' then run.combat=C.copy(run.combat)
  elseif mode=='rng' and run.combat.shuffleRng then run.combat.shuffleRng.counter=run.combat.shuffleRng.counter+1 end
 end
 return ok,reason
end
dofile(assert(os.getenv('FIXTURE')))
