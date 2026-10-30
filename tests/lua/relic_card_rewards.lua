package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random')
local Cards,Pending,Pool=require('abyss_relic_card_rewards'),require('abyss_relic_pending'),require('abyss_card_pool')
local D=require('abyss_data');local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function reward(ids,tier)
 local r=Run.new(D,'42',{experimental=true,character='ironclad'})
 for _,id in ipairs(ids or {})do assert(Run.obtainRelic(r,id))end
 if tier=='boss'then assert(Run.freezeMapContext(r));r.floor=16 end
 assert(Run.startRoomCombat(r,tier or 'normal'))
 for _,e in ipairs(r.combat.enemies)do C.damage(r.combat,r.combat.player,e,20000,true)end
 assert(Run.finishCombat(r));return r
end
local function token(r,index,choice)
 for _,row in ipairs(Pending.view(r).rows)do
  if row.token.index==index and row.token.choice==choice then return row.token end
 end
 error('missing source row')
end
test('normal Prayer Wheel produces two full sequential independent RNG rewards',function()
 local plain=reward();local r=reward({'prayer_wheel'})
 local groups=assert(r.rewards.cardRewardGroups);eq(#groups,2)
 same(groups[1].cards,plain.rewards.cards);same(groups[1].cardUpgrades,plain.rewards.cardUpgrades)
 local expected,rng,offset,upgrades=Pool.prepareRewards(plain)
 same(groups[2].cards,expected);same(groups[2].cardUpgrades,upgrades)
 same(R.snapshot(r.cardRng),R.snapshot(rng));eq(r.cardRarityOffset,offset)
 same(r.rewards.potion,plain.rewards.potion);same(r.shopRng,plain.shopRng)
end)
test('elite and boss Prayer Wheel grant one group only',function()
 for _,tier in ipairs({'elite','boss'})do
  local r=reward({'prayer_wheel'},tier)
  assert(not r.rewards.cardRewardGroups or #r.rewards.cardRewardGroups==1)
 end
end)
test('old card command consumes one group at a time and zero explicitly abandons only one',function()
 local r=reward({'prayer_wheel'});local size=#r.deck
 assert(Run.claimCardReward(r,0));eq(#r.deck,size);assert(not r.rewards.cardResolved)
 same(Run.rewardOptions(r),r.rewards.cardRewardGroups[2].cards)
 assert(Run.claimCardReward(r,1));eq(#r.deck,size+1);assert(r.rewards.cardResolved)
 assert(not Run.claimCardReward(r,1))
end)
test('modal closes without consuming groups, supports second group first, retires old source tokens',function()
 local r=reward({'prayer_wheel','singing_bowl'});local source=r.rewards
 assert(Cards.open(r,source));local view=Pending.view(r);local close=view.rows[#view.rows].token
 assert(Pending.resolve(r,close));assert(not Pending.owner(r));assert(not r.rewards.cardResolved)
 assert(not Cards.open(r,source));assert(Cards.open(r,r.rewards))
 local old=token(r,1,1);local selected=token(r,2,'bowl');local maxHp,size=r.maxHp,#r.deck
 assert(Pending.resolve(r,selected));eq(r.maxHp,maxHp+2);eq(#r.deck,size)
 assert(r.rewards.cardRewardGroups[2].resolved and not r.rewards.cardRewardGroups[1].resolved)
 assert(not Pending.resolve(r,old));assert(Pending.resolve(r,token(r,1,1)))
 eq(#r.deck,size+1);assert(r.rewards.cardResolved and not Pending.owner(r))
end)
test('each Bowl reward gives two max HP independently; Mark of Bloom prevents only the healing',function()
 local r=reward({'prayer_wheel','singing_bowl'});r.hp=r.maxHp-10
 assert(Run.obtainRelic(r,'mark_of_bloom'));local hp,maxHp,size=r.hp,r.maxHp,#r.deck
 assert(Cards.claim(r,1,'bowl'));eq(r.maxHp,maxHp+2);eq(r.hp,hp);eq(#r.deck,size)
 assert(Cards.claim(r,2,'bowl'));eq(r.maxHp,maxHp+4);eq(r.hp,hp);eq(#r.deck,size)
 local before=C.copy(r);assert(not Cards.claim(r,2,'bowl'));same(r,before)
end)
test('Bowl cannot be used without ownership; failed permanent grant rolls back selected group',function()
 local r=reward({'prayer_wheel'});local before=C.copy(r)
 assert(not Cards.claim(r,1,'bowl'));same(r,before)
 r.nextDeckUid=9007199254740991.0;before=C.copy(r)
 assert(not Cards.claim(r,1,1));same(r,before)
end)
test('Question Card and Crown compose separately for both Wheel groups',function()
 local r=reward({'prayer_wheel','question_card','busted_crown','singing_bowl'})
 for _,group in ipairs(r.rewards.cardRewardGroups)do eq(#group.cards,2)end
end)
test('Tiny House card item exposes and consumes its own Bowl option',function()
 local r=Run.new(D,'42',{experimental=true,character='ironclad'})
 assert(Run.obtainRelic(r,'singing_bowl'));assert(Run.obtainRelic(r,'tiny_house'))
 local found;for _,row in ipairs(Pending.view(r).rows)do if row.token.choice=='bowl'then found=row.token end end
 assert(found);local maxHp,size=r.maxHp,#r.deck;assert(Pending.resolve(r,found))
 eq(r.maxHp,maxHp+2);eq(#r.deck,size);assert(r.pendingBossRelic.cardResolved)
end)
print('RELIC_CARD_REWARDS_PASS '..count)
