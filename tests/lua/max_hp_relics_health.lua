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
for _,id in ipairs({'strawberry','pear','mango','lees_waffle'})do
 test(id..' exact source heal steps, held-order modifiers and cap against 40 independent inputs',function()
  for _,case in ipairs(F.vectors.health)do if case.id==id then
   local r=minimal(case);local health=require('abyss_potion_health');local modify=health.modifyHealing;local equip=H.onEquip;local steps,owner={}
   H.onEquip=function(staged,relic,...)owner=staged;return equip(staged,relic,...)end
   health.modifyHealing=function(amount,relics,inCombat)
    local actor=owner.phase=='combat'and owner.combat.player or owner
    steps[#steps+1]={requested=amount,maximum=actor.maxHp,beforeHp=actor.hp,combat=inCombat}
    return modify(amount,relics,inCombat)
   end
   local called,ok,why=pcall(F.R.obtainRelic,r,case.sourceId);health.modifyHealing=modify;H.onEquip=equip
   assert(called and ok,tostring(why));F.eq(r.maxHp,case.expectedMaximum);F.eq(r.hp,case.expectedHp)
   F.eq(r.relics[#r.relics],id);F.eq(#steps,#case.steps)
   for i,step in ipairs(steps)do
    F.eq(step.requested,case.steps[i].requested);F.eq(step.maximum,case.steps[i].maximum)
    F.eq(step.beforeHp,i==1 and case.hp or case.steps[i-1].hp);F.eq(step.combat,case.combat)
   end
   if case.combat then F.eq(r.combat.player.hp,r.hp);F.eq(r.combat.player.maxHp,r.maxHp)end
  end end
 end)
end
test('all four exact identities obtain once, persist to the next real battle and cannot retroactively re-equip',function()
 local r=F.R.new(F.D,42);r.hp=30
 local rng={};for _,key in ipairs({'eventRng','miscRng','treasureRng','cardRng'})do rng[key]=F.S.snapshot(r[key])end
 local pool=F.C.copy(r.relicPool)
 for _,pair in ipairs({{'strawberry','Strawberry',87,37},{'pear','Pear',97,47},{'mango','Mango',111,61},{'lees_waffle',"Lee's Waffle",118,118}})do
  assert(F.R.obtainRelic(r,pair[2]));F.eq(r.maxHp,pair[3]);F.eq(r.hp,pair[4]);F.snapshotFailure(r,function()return F.R.obtainRelic(r,pair[1])end)
 end
 for key,value in pairs(rng)do F.same(F.S.snapshot(r[key]),value)end;F.same(r.relicPool,pool)
 assert(F.R.startCombat(r,'cultist_solo'));F.eq(r.combat.player.hp,118);F.eq(r.combat.player.maxHp,118)
 local before=F.C.copy(r.combat);F.eq(#r.relics,5);F.same(r.combat,before)
end)
assert(failed==0,tostring(failed)..' max HP health groups failed');print('MAX_HP_RELICS_HEALTH_PASS '..count)
