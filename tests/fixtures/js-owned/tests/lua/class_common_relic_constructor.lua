package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,A=require('abyss_run'),require('abyss_actor')
local D=require('abyss_data')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function run(character,ids)
 local r=R.new(D,'42',{experimental=true,character=character})
 for _,id in ipairs(ids or {})do assert(R.obtainRelic(r,id))end
 assert(R.startCombat(r,'cultist_solo'));local s=r.combat;s.enemies[1].hp=10000;s.enemies[1].maxHp=10000
 return r,s
end
test('Fumes constructor snapshots Snake ownership before a real Foresight pause',function()
 local r,s=run('silent')
 A.applyPower(s,s.player,'foresight',1,s.player);A.applyPower(s,s.player,'noxious_fumes',2,s.player)
 assert(R.endTurn(r));assert(s.pendingScry and s.startTurnPending)
 local poison
 for _,action in ipairs(s.actionQueue.actions)do if action.effect and action.effect.op=='turnPoison'then poison=action.effect end end
 assert(poison);eq(poison.value,2)
 assert(R.obtainRelic(r,'snake_skull'));s=r.combat
 assert(R.chooseScry(r,{},s.pendingScry.token,r.combatGeneration));eq(s.enemies[1].statuses.poison,2,'a later acquire cannot alter an already constructed ApplyPower')
 assert(R.endTurn(r));assert(s.pendingScry)
 assert(R.chooseScry(r,{},s.pendingScry.token,r.combatGeneration));eq(s.enemies[1].statuses.poison,4,'the next constructor sees Snake: 2-1+3')
end)
test('already constructed Fumes keeps its Snake bonus even if current ownership changes',function()
 local r,s=run('silent',{'snake_skull'})
 A.applyPower(s,s.player,'foresight',1,s.player);A.applyPower(s,s.player,'noxious_fumes',2,s.player)
 assert(R.endTurn(r));assert(s.pendingScry);s.relics={}
 assert(R.chooseScry(r,{},s.pendingScry.token,r.combatGeneration));eq(s.enemies[1].statuses.poison,3)
end)
test('Envenom captures Snake at its onAttack ApplyPower constructor, not later resolution',function()
 local T=require('abyss_card_triggers');local _,s=run('silent')
 T.apply(s,'envenom',1);local action=assert(T.onAttack(s,s.player,s.enemies[1],1,'NORMAL'))
 s.relics={'snake_skull'};T.resolveEnvenom(s,action.effect);eq(s.enemies[1].statuses.poison,1)
 action=assert(T.onAttack(s,s.player,s.enemies[1],1,'NORMAL'));s.relics={}
 T.resolveEnvenom(s,action.effect);eq(s.enemies[1].statuses.poison,3)
end)
test('real card use captures explicit Poison and Crippling Poison before queue execution',function()
 local Q=require('abyss_action_queue');local C=require('abyss_combat')
 local r=R.new(D,'42',{experimental=true,character='silent'})
 r.deck={{uid=1,cardId='deadly_poison',upgraded=false},{uid=2,cardId='crippling_poison',upgraded=false}}
 assert(R.startCombat(r,'cultist_solo'));r.combat.enemies[1].hp=10000;r.combat.enemies[1].maxHp=10000
 local original=Q.start;local expected,seen=0,false
 local function inspect(effect)
  if effect and (effect.op=='applyStatus'and effect.status=='poison'or effect.op=='cripplingPoison')then
   eq(effect.poisonBonus,expected,'card use constructor snapshot');seen=true
  end
  for _,part in ipairs(effect and effect.effects or {})do inspect(part)end
 end
 Q.start=function(state,actions)
  for _,action in ipairs(actions)do inspect(action.effect)end
  return original(state,actions)
 end
 local ok,why=pcall(function()
  local s=r.combat;s.energy=10;assert(R.play(r,1,1));assert(seen);eq(s.enemies[1].statuses.poison,5)
  assert(R.obtainRelic(r,'snake_skull'));s=r.combat;expected=1;seen=false;C.draw(s,10)
  assert(R.play(r,2));assert(seen);eq(s.enemies[1].statuses.poison,10)
 end)
 Q.start=original;assert(ok,why)
end)
assert(failed==0,tostring(failed)..' class common constructor cases failed')
print('CLASS_COMMON_RELIC_CONSTRUCTOR_PASS '..count)
