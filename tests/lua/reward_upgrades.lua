package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,Pool,Q=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_card_pool'),require('abyss_encounter_queue')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then return eq(a,b)end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local count=0
local function test(name,fn)fn();count=count+1;print('ok reward upgrades '..count..' - '..name)end
test('fixed source draws identities first, then chapter upgrade floats, with unchanged A0 first-act entropy',function()
 -- Fixed seed1 consumes six identity draws followed by floats
 -- .59927195310593, .25889480113983, .1227068901062.
 local expected={{false,false,false},{false,false,true},{false,true,true},{false,true,true}}
 for act=1,4 do
  local run=Run.new(Data,'1');run.act=act
  local before=R.snapshot(run.cardRng)
  local ids,rng,offset,upgrades=Pool.prepareRewards(run)
  same(ids,{'body_slam','clothesline','dual_wield'});same(upgrades,expected[act])
  eq(rng.counter,9);eq(offset,3);same(R.snapshot(run.cardRng),before)
 end
end)
test('rare boss cards never consume upgrade floats or become upgraded',function()
 local run=Run.new(Data,'1');run.act,run.encounterTier=2,'boss'
 local calls=0;local original=R.randomBooleanChance
 R.randomBooleanChance=function(...)calls=calls+1;return original(...)end
 local called,ids,rng,_,upgrades=pcall(Pool.prepareRewards,run)
 R.randomBooleanChance=original;assert(called,ids)
 eq(calls,0);eq(rng.counter,6);same(upgrades,{false,false,false})
 for _,id in ipairs(ids)do for _,d in ipairs(run.data.cards.cards)do if d.id==id then eq(d.rarity,'rare')end end end
end)
test('missing effect definitions preserve source identity, upgrade flags and every RNG draw',function()
 local run=Run.new(Data,'1');run.act=2
 local ids,rng,offset,upgrades=Pool.prepareRewards(run)
 for i=#run.data.cards.cards,1,-1 do if run.data.cards.cards[i].id=='dual_wield'then table.remove(run.data.cards.cards,i)end end
 local actual,nextRng,nextOffset,nextUpgrades=Pool.prepareRewards(run)
 same(actual,ids);same(R.snapshot(nextRng),R.snapshot(rng));eq(nextOffset,offset);same(nextUpgrades,upgrades)
end)
local function won()
 local run=Run.new(Data,'1',{experimental=true,campaign=true})
 run.act,run.floor,run.encounters=2,18,Q.new('1',2)
 assert(Run.startRoomCombat(run,'normal'));eq(run.encounterSource,'Chosen')
 for _,enemy in ipairs(run.combat.enemies)do C.damage(run.combat,run.combat.player,enemy,999,true)end
 assert(Run.finishCombat(run));eq(run.phase,'reward');return run
end
test('actual second-act victory retains upgrades through pending reward and plain state restoration, then claims same UID into next battle',function()
 local run=won();same(Run.rewardOptions(run),{'body_slam','clothesline','dual_wield'})
 same(run.rewards.cardUpgrades,{false,false,true})
 local rng=R.snapshot(run.cardRng);local uid=run.nextDeckUid
 assert(Run.leaveCombatRewards(run));same(run.pendingCombatRewards.rewards.cardUpgrades,{false,false,true})
 -- Run has no complete save-file API: restore its plain state graph, including
 -- pending reward/room aliases, as used by permanent command transactions.
 local restored=C.copy(run);assert(Run.reopenCombatRewards(restored))
 local deck,rewards=restored.deck,restored.rewards
 assert(Run.claimCardReward(restored,3));eq(restored.deck,deck);eq(restored.rewards,rewards)
 local card=restored.deck[#restored.deck];eq(card.uid,uid);eq(card.cardId,'dual_wield');eq(card.upgraded,true)
 eq(restored.nextDeckUid,uid+1);same(R.snapshot(restored.cardRng),rng)
 assert(not Run.claimCardReward(restored,3));eq(restored.nextDeckUid,uid+1)
 assert(Run.leaveCombatRewards(restored));restored.floor=19
 assert(Run.startRoomCombat(restored,'normal'))
 local found=false;for _,pile in ipairs({restored.combat.hand,restored.combat.draw})do for _,c in ipairs(pile)do
  if c.deckUid==uid then eq(c.cardId,'dual_wield');eq(c.upgraded,true);found=true end
 end end;assert(found)
end)
test('rejected upgraded reward leaves reward owner, deck, flags and RNG untouched',function()
 local run=won();run.nextDeckUid=run.deck[1].uid
 local before=C.copy(run);local deck,rewards=run.deck,run.rewards
 local ok,why=Run.claimCardReward(run,3);eq(ok,false);eq(why,'invalid_deck_uid')
 same(run,before);eq(run.deck,deck);eq(run.rewards,rewards)
end)
test('unavailable upgraded identity refuses atomically while skipping remains possible',function()
 local run=won()
 for i=#run.data.cards.cards,1,-1 do if run.data.cards.cards[i].id=='dual_wield'then table.remove(run.data.cards.cards,i)end end
 local before=C.copy(run);local rewards,deck=run.rewards,run.deck
 local ok,why=Run.claimCardReward(run,3);eq(ok,false);eq(why,'card_content_unavailable')
 same(run,before);eq(run.rewards,rewards);eq(run.deck,deck)
 assert(Run.claimCardReward(run,0));eq(run.rewards.cardResolved,true)
 same(run.rewards.cardUpgrades,{false,false,true});same(R.snapshot(run.cardRng),R.snapshot(before.cardRng))
end)
test('later potion preparation failure rolls back the complete upgrade-bearing reward transaction',function()
 local run=Run.new(Data,'1',{experimental=true,campaign=true})
 run.act,run.floor,run.encounters=2,18,Q.new('1',2);assert(Run.startRoomCombat(run,'normal'))
 for _,enemy in ipairs(run.combat.enemies)do C.damage(run.combat,run.combat.player,enemy,999,true)end
 local before=C.copy(run);local rewards=require('abyss_potion_rewards');local prepare=rewards.prepare
 rewards.prepare=function()error('intentional potion failure')end
 local ok,why=pcall(Run.finishCombat,run);rewards.prepare=prepare
 eq(ok,false);assert(tostring(why):find('intentional potion failure',1,true));same(run,before)
end)
print('REWARD_UPGRADES_PASS '..count)
