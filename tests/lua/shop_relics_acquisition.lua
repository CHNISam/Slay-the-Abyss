package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C=require('abyss_run'),require('abyss_combat')
local Shop,Choices=require('abyss_shop_relics'),require('abyss_relic_choices')
local Pool,Random=require('abyss_card_pool'),require('abyss_sts_random')
local data=C.copy(require('abyss_data'))
for source,id in pairs(Shop.aliases)do
 local found=false;for _,d in ipairs(data.relics.relics)do if d.id==id then found=true end end
 if not found then data.relics.relics[#data.relics.relics+1]={id=id,sourceId=source,name=id,rarity='shop',trigger='hooks',effects={}}end
end
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function claim(run,token,index,choice)
 return R.transaction(run,function(s)return Choices.claim(s,token,index,choice)end)
end
test('Orrery acquisition offers five independent ordinary card rewards and resolves all',function()
 local run=R.new(data,42);local before=#run.deck
 assert(R.obtainRelic(run,'Orrery'));local p=run.shopRelicRewards
 assert(p.relic=='orrery'and #p.items==5)
 assert(not Choices.finish(run,p.token))
 for i,item in ipairs(p.items)do assert(#item.reward.cards==3)
  assert(claim(run,p.token,i,1));assert(not claim(run,p.token,i,1))
 end
 assert(#run.deck==before+5)
 assert(Choices.finish(run,p.token));assert(not run.shopRelicRewards)
 assert(not claim(run,p.token,1,1))
end)
test('Cauldron acquires real potions and full inventory refuses without consuming offer',function()
 local run=R.new(data,981);assert(R.obtainRelic(run,'Cauldron'))
 local p=run.shopRelicRewards;assert(#p.items==5)
 for i=1,3 do assert(claim(run,p.token,i,1))end
 local ok,why=claim(run,p.token,4,1);assert(not ok and why=='potion_slots_full')
 assert(not run.shopRelicRewards.items[4].claimed)
 assert(claim(run,p.token,4,0));assert(claim(run,p.token,5,0));assert(Choices.finish(run,p.token))
 assert(R.potionCount(run)==3)
end)
test('Dolly copies chosen upgraded permanent card with new UID and clears selection',function()
 local run=R.new(data,42);local old=run.deck[1];old.upgraded=true;old.upgrades=1
 local before=#run.deck;assert(R.obtainRelic(run,'DollysMirror'))
 assert(not Choices.chooseMirror(run,999999))
 assert(R.transaction(run,function(s)return Choices.chooseMirror(s,old.uid)end))
 local copy=run.deck[#run.deck];assert(#run.deck==before+1)
 assert(copy.cardId==old.cardId and copy.upgraded and copy.uid~=old.uid)
 assert(not copy.inBottleFlame and not run.shopRelicChoice)
 assert(not Choices.chooseMirror(run,old.uid))
end)
test('Prismatic acquisition keeps all320 cards and spends source shuffle+identity RNG',function()
 local run=R.new(data,42);assert(R.obtainRelic(run,'PrismaticShard'));assert(run.masterMaxOrbs==1)
 local pools=Pool.prismaticPools(run);assert(#pools.common==76 and #pools.uncommon==160 and #pools.rare==84)
 local cards,rng=Pool.prepareRewards(run);assert(#cards==3)
 for _,id in ipairs(cards)do local found=false
  for _,pool in pairs(pools)do for _,candidate in ipairs(pool)do if candidate==id then found=true end end end
  assert(found)
 end
 assert(Random.snapshot(rng).counter>Random.snapshot(run.cardRng).counter+6)
end)
test('Question Card and Busted Crown compose in ordinary card rewards',function()
 local run=R.new(data,42);run.relics={'question_card'};assert(#Pool.prepareRewards(run)==4)
 run.relics={'busted_crown'};assert(#Pool.prepareRewards(run)==1)
 run.relics={'question_card','busted_crown'};assert(#Pool.prepareRewards(run)==2)
end)
test('acquired passive shop relics publish real combat owners and opening effects',function()
 local run=R.new(data,42)
 for _,id in ipairs({'hand_drill','chemical_x','orange_pellets','clockwork_souvenir',
  'frozen_eye','the_abacus','medical_kit','strange_spoon','brimstone'})do assert(R.obtainRelic(run,id))end
 assert(R.startCombat(run,'cultist_solo'));local s=run.combat
 for _,id in ipairs(run.relics)do assert(Shop.owns(s,id))end
 assert(s.player.statuses.artifact==1)
 assert(s.player.statuses.strength==2 and s.enemies[1].statuses.strength==1)
 assert(Shop.xBonus(s)==2 and Shop.drawOrderVisible(s))
 local status=Shop.medicalCard(s,{type='status',cost=-2});assert(status.cost==0 and status.exhaust)
end)
test('all five Orrery rewards accept Singing Bowl once with Mark Bloom and no card hooks',function()
 local run=R.new(data,42)
 for _,id in ipairs({'singing_bowl','mark_of_bloom','ceramic_fish','toxic_egg','molten_egg','frozen_egg'})do assert(R.obtainRelic(run,id))end
 run.hp=20;local maxHp,gold,deck,uid=run.maxHp,run.gold,C.copy(run.deck),run.nextDeckUid
 assert(R.obtainRelic(run,'Orrery'));local p=run.shopRelicRewards
 for i=1,5 do
  assert(claim(run,p.token,i,'bowl'))
  assert(run.maxHp==maxHp+2*i and run.hp==20)
  assert(not claim(run,p.token,i,'bowl'))
 end
 assert(#run.deck==#deck and run.nextDeckUid==uid and run.gold==gold)
 for i,c in ipairs(run.deck)do assert(c.uid==deck[i].uid and c.upgraded==deck[i].upgraded)end
 assert(Choices.finish(run,p.token));assert(not claim(run,p.token,1,'bowl'))
end)
test('Singing Bowl at full HP heals the new two maxHP and stale owner tokens refuse',function()
 local run=R.new(data,42);assert(R.obtainRelic(run,'singing_bowl'));assert(R.obtainRelic(run,'Orrery'))
 local Pending=require('abyss_relic_pending');local view=Pending.view(run)
 local stale=view.rows[1].token;local p=run.shopRelicRewards;local before=run.maxHp
 assert(claim(run,p.token,1,'bowl'));assert(run.maxHp==before+2 and run.hp==run.maxHp)
 assert(not Pending.resolve(run,stale))
 local other=R.new(data,42);assert(R.obtainRelic(other,'Orrery'))
 assert(not claim(other,other.shopRelicRewards.token,1,'bowl'))
 assert(not other.shopRelicRewards.items[1].claimed)
end)
print('LUA_SHOP_RELIC_ACQUISITION_PASS '..n)
