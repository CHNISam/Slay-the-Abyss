local F=dofile('tests/lua/support/max_hp_relics.lua');local H=require('abyss_relic_hooks')
local count,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function minimal(case)
 local r={data=F.D,relics=F.C.copy(case.relics),hp=case.hp,maxHp=case.maximum,phase='map',deck={}}
 if case.combat then
  r.phase='combat';r.combat={player={id='player',hp=case.hp,maxHp=case.maximum,statuses={}},relics=F.C.copy(case.relics),events={},enemies={},hand={},draw={},discard={},exhaust={}}
 end
 return r
end
test('new acquisition outside battle never rewrites a retained victory or pending reward battle',function()
 for _,phase in ipairs({'reward','map','node'})do
  local r=F.R.new(F.D,42);r.hp=20
  r.phase=phase;r.combat={phase='victory',player={hp=20,maxHp=80},marker='historical'}
  r.pendingCombatRewards={combat=r.combat};local before=F.C.copy(r.combat)
  assert(F.R.obtainRelic(r,'Mango'));F.eq(r.maxHp,94);F.eq(r.hp,34)
  F.same(r.combat,before);F.eq(r.pendingCombatRewards.combat,r.combat)
 end
end)
test('active source healing removes Red Skull only when actual heal crosses its current maximum threshold',function()
 local r=F.R.new(F.D,42);r.hp=40;r.relics={'red_skull'};assert(F.R.startCombat(r,'cultist_solo'))
 F.eq(r.combat.player.statuses.strength,3);assert(F.R.obtainRelic(r,'Pear'))
 F.eq(r.hp,50);F.eq(r.maxHp,90);F.eq(r.combat.player.statuses.strength,0);assert(not r.combat.relicCombat.redSkullActive)
end)
test('Waffle emits detached ordered health frames and never queues an invented heal action',function()
 local r=F.R.new(F.D,42);r.hp=30;assert(F.R.startCombat(r,'cultist_solo'))
 local events=#r.combat.events;assert(F.R.obtainRelic(r,"Lee's Waffle"));local s=r.combat
 F.eq(#s.events,events+2);local first,last=s.events[events+1],s.events[events+2]
 F.eq(first.kind,'heal');F.eq(first.frame.player.maxHp,87);F.eq(first.frame.player.hp,37)
 F.eq(last.kind,'heal');F.eq(last.frame.player.maxHp,87);F.eq(last.frame.player.hp,87)
 local before=F.C.copy({first,last});s.player.hp=1;s.player.maxHp=90
 F.same({first,last},before);assert(not s.cardActions and not s.actionQueue)
end)
test('source modifier aliases remain controlled dependencies and dying health never revives',function()
 for _,id in ipairs({'strawberry','pear','mango','lees_waffle'})do
  local r={data=F.D,relics={'Magic Flower','Mark of the Bloom'},hp=30,maxHp=80,phase='map',deck={}}
  assert(F.R.obtainRelic(r,id));F.eq(r.hp,30);assert(r.maxHp>80)
  r={data=F.D,relics={},hp=0,maxHp=80,phase='defeat',deck={}}
  assert(F.R.obtainRelic(r,id));F.eq(r.hp,0);assert(r.maxHp>80)
  for _,combat in ipairs({false,true})do
   local dying=minimal({relics={},hp=30,maximum=80,combat=combat})
   local actor=combat and dying.combat.player or dying;actor.isDying=true
   local health=require('abyss_potion_health');local original=health.modifyHealing
   health.modifyHealing=function()error('DYING_MUST_RETURN_BEFORE_HEAL_MODIFIERS')end
   local called,ok,why=pcall(F.R.obtainRelic,dying,id);health.modifyHealing=original
   assert(called and ok,tostring(why));F.eq(dying.hp,30);assert(dying.maxHp>80)
   if combat then F.eq(dying.combat.player.hp,30);F.eq(#dying.combat.events,0)end
  end
 end
end)
assert(failed==0,tostring(failed)..' max HP health groups failed');print('MAX_HP_RELICS_HEALTH_LIFECYCLE_PASS '..count)
