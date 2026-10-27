package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,D,A,Cards=require('abyss_combat'),require('abyss_data'),require('abyss_actor'),require('abyss_card_actions')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Spire facing '..count..' '..name)end
local function fresh(advanced,id)
 local data=C.copy(D);data.rules.player.drawPerTurn=0
 local s=assert(C.new(data,{seed=42,enemies={'spire_shield','spire_spear'},deck={},enableStances=advanced}))
 local card=Cards.fresh(C,s,id or 'strike');s.hand={card};return s,s.enemies[1],s.enemies[2],card
end
for _,advanced in ipairs({false,true})do
 test((advanced and 'advanced'or 'native')..' legal single-target card turns before its effects',function()
  for _,free in ipairs({false,true})do
   local s,shield,spear,card=fresh(advanced);card.freeToPlayOnce=free
   local energy=s.energy
   assert(not s.spirePair.facingLeft and shield.statuses.back_attack==1)
   assert(C.play(s,card.uid,1));assert(s.spirePair.facingLeft)
   assert(not shield.statuses.back_attack and spear.statuses.back_attack==1)
   if free then assert(s.energy==energy,'free manual card must remain a manual targeted play')end
  end
 end)
end
test('self/AoE cards and rejected targets cannot change facing',function()
 for _,id in ipairs({'defend','cleave'})do
  local s,shield,spear,card=fresh(false,id)
  assert(C.play(s,card.uid));assert(not s.spirePair.facingLeft and shield.statuses.back_attack==1 and not spear.statuses.back_attack)
 end
 local s,shield,_,card=fresh(false)
 local ok,why=C.play(s,card.uid,3)
 assert(not ok and why=='invalid_target'and not s.spirePair.facingLeft and shield.statuses.back_attack==1 and s.hand[1]==card)
end)

test('queued automatic targeted cards preserve player facing in both resolvers',function()
 for _,advanced in ipairs({false,true})do
  local s,shield,spear,card=fresh(advanced)
  if advanced then s.catalog.cards.strike.effects[#s.catalog.cards.strike.effects+1]={op='scry',value=0} end
  s.hand={}
  C.queueCard(s,card,{targetIndex=1,exhaustCards=false})
  Cards.drain(C,s)
  assert(shield.hp<110,'queued target must actually be attacked')
  assert(not s.spirePair.facingLeft and shield.statuses.back_attack==1 and not spear.statuses.back_attack,
   'autoplay must not turn toward its queued target')
 end
end)

test('real Havoc target selection and autoplay do not turn the player',function()
 local s,shield,spear,havoc=fresh(false,'havoc')
 local R=require('abyss_sts_random');s.cardRandomRng=R.fromSeed('1')
 local expected=R.randomInt(R.cloneState(s.cardRandomRng),1)+1
 A.faceTarget(s,s.enemies[3-expected]) -- controlled facing opposite the selected top-card target.
 local facing=s.spirePair.facingLeft;local left,right=shield.hp,spear.hp
 s.draw={Cards.fresh(C,s,'strike')}
 assert(C.play(s,havoc.uid))
 assert(shield.hp<left or spear.hp<right,'Havoc must execute the real top card')
 assert(s.spirePair.facingLeft==facing,'Havoc autoplay must preserve the pre-use facing')
end)
test('actual output and intent preview preserve the distinct source float boundaries',function()
 local s,shield=fresh(false)
 shield.statuses.weak=1;s.player.statuses.vulnerable=1
 assert(A.attackAmount(s,shield,s.player,12)==13,'ordinary snapshot ABI must stay ordinary')
 assert(type(A.intentAttackAmount)=='function','missing distinct source intent arithmetic')
 assert(A.intentAttackAmount(s,shield,s.player,12)==20)
 local hp=s.player.hp;assert(A.damage(s,shield,s.player,12,false)==19 and s.player.hp==hp-19)
 local t,left=fresh(false);hp=t.player.hp
 assert(A.damage(t,left,t.player,12,false,nil,18)==18 and t.player.hp==hp-18,'frozen back-attack output must not multiply twice')
end)
test('real lethal damage clears Surrounded and survivor BackAttack through the queue',function()
 local s,shield,spear=fresh(false)
 assert(C.damage(s,s.player,spear,160,true)==160)
 assert(s.spirePair.facingLeft and not s.player.statuses.surrounded and not shield.statuses.back_attack)
 assert(A.damage(s,shield,s.player,12,false)==12)
end)
test('poison death before actions turns toward the surviving attacker',function()
 local s,shield,spear=fresh(false)
 for i,move in ipairs(shield.intents)do if move.id=='bash'then shield.intentIndex=i end end
 A.addStatus(spear,'poison',160) -- controlled owner-death boundary, not an Artifact bypass claim.
 assert(C.endTurn(s));assert(spear.hp==0 and s.player.hp==68)
 assert(not s.player.statuses.surrounded and not shield.statuses.back_attack and s.spirePair.facingLeft)
end)
test('late card failure restores facing, Power membership and original references',function()
 local s,shield,spear,card=fresh(true);local facing=s.spirePair
 local old=C.damage;C.damage=function(...)old(...);error('late facing damage fault')end
 local called,ok=pcall(C.play,s,card.uid,1);C.damage=old
 assert(not called or not ok)
 assert(s.spirePair==facing and not facing.facingLeft and shield.hp==110 and spear.hp==160)
 assert(shield.statuses.back_attack==1 and not spear.statuses.back_attack and s.hand[1]==card)
 assert(C.play(s,card.uid,1)and facing.facingLeft)
end)
test('real targeted potion turns once while previews and rejected targets stay detached',function()
 local Run=require('abyss_run')
 local function owner()
  local s,left,right=fresh(false)
  local run=Run.new(D,'42',{experimental=true,campaign=true})
  run.phase,run.combat,run.encounterId,run.encounterTier='combat',s,'ending_spire_pair','elite'
  run.combatGeneration,s.combatGeneration=1,1;run.potions[1]='fire_potion';run.gold=s.player.gold
  return run,s,left,right
 end
 local run,s,left,right=owner()
 assert(Run.potionView(run)[1].canUse)
 assert(not s.spirePair.facingLeft and left.statuses.back_attack==1 and not right.statuses.back_attack)
 local used=Run.usePotion(run,1,99);assert(not used and run.potions[1]=='fire_potion'and not s.spirePair.facingLeft)
 assert(Run.usePotion(run,1,1))
 assert(run.combat.spirePair.facingLeft and not run.combat.enemies[1].statuses.back_attack and run.combat.enemies[2].statuses.back_attack==1)
 local frame=require('abyss_events').frame(run.combat)
 assert(frame.spirePair~=run.combat.spirePair and frame.spirePair.facingLeft)
end)
print('SPIRE_FACING_HOOKS_PASS '..count..' real play/damage/death; controlled offline, not natural or live evidence')
