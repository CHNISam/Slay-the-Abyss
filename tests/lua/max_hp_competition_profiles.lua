-- Public Geo and explicit full-source Raiden loadouts, controlled obtain/injury; not natural play.
local F=dofile('tests/lua/support/max_hp_relics.lua')
local Select=require('abyss_character_select')
local Frozen=require('abyss_original_v4_data')
local External=require('abyss_external_random')
local ids={'strawberry','pear','mango','lees_waffle'}
local gains={strawberry=7,pear=10,mango=14,lees_waffle=7}
local function new(character)
 local options=Select.options(character)or{}
 options.experimental,options.campaign=true,true
 options.campaignProfile=character=='raiden'and 'full-source'or 'competition-two-act'
 local r=F.R.new(F.D,'2',options)
 F.eq(r.campaignProfile,character=='raiden'and 'full-source'or 'competition-two-act')
 if character=='raiden'then
  F.eq(r.character,'raiden');F.eq(r.data.originalV4Role,'RD');F.eq(r.characterProfile.role,'RD')
  assert(r.characterProfile.originalV4);F.eq(r.maxHp,Frozen.rules.roles.RD.max_hp)
  F.eq(#r.deck,#Frozen.rules.roles.RD.starter)
  for i,card in ipairs(r.deck)do F.eq(card.cardId,Frozen.rules.roles.RD.starter[i])end
 else assert(not r.characterProfile and not r.data.originalV4Role);F.eq(r.maxHp,80)end
 for _,id in ipairs(ids)do
  local actual,source
  for _,d in ipairs(r.data.relics.relics)do if d.id==id then actual=d end end
  for _,d in ipairs(F.D.relics.relics)do if d.id==id then source=d end end
  assert(actual and source);F.same(actual,source)
 end
 return r
end
local count=0
local selected=rawget(_G,'ABYSS_MUTATION_CASE')
assert(not selected or selected=='ironclad'or selected=='raiden','unknown competition profile case')
for _,character in ipairs(selected and{selected}or{'ironclad','raiden'})do
 local r=new(character);r.hp=30
 local maximum,hp=r.maxHp,r.hp
 local pool,entropy=F.C.copy(r.relicPool),External.snapshot()
 for _,id in ipairs(ids)do
  maximum=maximum+gains[id];hp=id=='lees_waffle'and maximum or hp+gains[id]
  assert(F.R.obtainRelic(r,id));F.eq(r.maxHp,maximum);F.eq(r.hp,hp)
  print('OBTAIN actual '..character..' '..id..' hp='..r.hp..' maxHp='..r.maxHp..' phase='..r.phase)
  F.eq(r.relics[#r.relics],id);F.snapshotFailure(r,function()return F.R.obtainRelic(r,id)end)
 end
 F.same(r.relicPool,pool);F.same(External.snapshot(),entropy)
 assert(F.R.startCombat(r,'cultist_solo'));F.eq(r.combat.player.maxHp,maximum);F.eq(r.combat.player.hp,hp)
 if character=='raiden'then F.eq(r.combat.originalV4.role,'RD');F.eq(r.combat.originalV4.healUsed,0)
 else assert(not r.combat.originalV4)end
 count=count+1;print('PASS actual '..character..' four outside obtains and next-combat inheritance')
 r=new(character);r.hp=30;assert(F.R.startCombat(r,'cultist_solo'))
 for _,id in ipairs(ids)do
  F.C.damage(r.combat,r.combat.enemies[1],r.combat.player,1,true)
  assert(r.combat.player.hp<r.hp,'actual combat injury must leave stale permanent health')
  local beforeHp,beforeMaximum=r.combat.player.hp,r.combat.player.maxHp
  local beforeEntropy=External.snapshot()
  if character=='raiden'then
   local reason
   F.snapshotFailure(r,function()local ok,why=F.R.obtainRelic(r,id);reason=why;return ok,why end)
   -- Public transactions intentionally normalize internal assertion text.
   F.eq(reason,'transaction_failed')
   F.eq(r.combat.originalV4.healUsed,0);F.eq(r.combat.player.hp,beforeHp)
   print('REFUSED actual raiden active '..id..' reason='..reason..' owner-preserved hp='..beforeHp..' maxHp='..beforeMaximum)
  else
   assert(F.R.obtainRelic(r,id));local maximum=beforeMaximum+gains[id]
   F.eq(r.maxHp,maximum);F.eq(r.combat.player.maxHp,maximum)
   F.eq(r.hp,id=='lees_waffle'and maximum or beforeHp+gains[id]);F.eq(r.combat.player.hp,r.hp)
  end
  F.same(External.snapshot(),beforeEntropy)
 end
 count=count+1;print('PASS actual '..character..(character=='raiden'and' active V4 safety refusal/owner rollback' or' active stale-owner acquisition'))
end
F.eq(count,selected and 2 or 4);print('MAX_HP_COMPETITION_PROFILES_PASS '..count..' '..(selected or'Geo/frozen-Raiden')..'; active V4 refusal remains explicit')
