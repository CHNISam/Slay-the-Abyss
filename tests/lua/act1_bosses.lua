local C=require('abyss_combat')
local Run=require('abyss_run')
local Q=require('abyss_encounter_queue')
local R=require('abyss_sts_random')
local Bosses=require('abyss_act1_bosses')
local D=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b))
 if type(a)~='table'then return eq(a,b)end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected field '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok act1 bosses '..count..' - '..name)end
local function battle(id,hp,ids)
 return C.new(D,{enemies=ids or {id},deck={},seed=42,hp=hp or 500,maxHp=500})
end
local function intent(e)return e.intents[e.intentIndex].id end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return v end end;error(id)end
local function cards(s,id)
 local result={}
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do
  for _,card in ipairs(pile)do if card.cardId==id then result[#result+1]=card end end
 end
 return result
end
local function room(source,seen)
 local run=Run.new(D,'42');run.floor=16
 run.bossInitialization,run.encounters=Q.initializeBoss(run.encounters,seen)
 eq(run.bossInitialization.bossList[1],source)
 assert(Run.startRoomCombat(run,'boss'))
 return run,run.combat
end
test('source Boss lookup preserves identities and rejects other tiers',function()
 for source,id in pairs({['The Guardian']='guardian',Hexaghost='hexaghost',['Slime Boss']='slime_boss'})do
  local encounter=assert(Bosses.resolve(source,'boss'));eq(encounter.enemies[1],id);eq(encounter.source,source)
  eq(Bosses.resolve(source,'normal'),nil)
 end
 eq(Bosses.resolve('invalid','boss'),nil)
end)
test('source history prioritizes Guardian then Ghost then Slime without a shuffle',function()
 local source=Q.new('42');local n=source.monsterRng.counter
 local cases={{},{GUARDIAN=true},{GUARDIAN=true,GHOST=true}}
 local expected={'The Guardian','Hexaghost','Slime Boss'}
 for i,seen in ipairs(cases)do
  local choice,nextQueue=Q.initializeBoss(source,seen)
  eq(choice.bossList[1],expected[i]);eq(choice.bossList[2],expected[i])
  eq(nextQueue.monsterRng.counter,n);eq(source.monsterRng.counter,n)
 end
end)
test('all-seen Boss shuffle consumes exactly one source randomLong and retains all three',function()
 local q=Q.new('42');local expected=R.cloneState(q.monsterRng)
 local list={'The Guardian','Hexaghost','Slime Boss'};R.shuffle(expected,list)
 local actual,nextQueue=Q.initializeBoss(q,{GUARDIAN=true,GHOST=true,SLIME=true})
 for i,id in ipairs(list)do eq(actual.bossList[i],id)end
 eq(nextQueue.monsterRng.counter,expected.counter);eq(nextQueue.monsterRng.counter,q.monsterRng.counter+1)
end)
test('normal Boss room creates Hexaghost at 250 HP with one HP draw and one AI draw',function()
 local run,s=room('Hexaghost',{GUARDIAN=true})
 eq(run.encounterSource,'Hexaghost');eq(s.enemies[1].definitionId,'hexaghost')
 eq(s.enemies[1].hp,250);eq(intent(s.enemies[1]),'activate')
 eq(s.monsterHpRng.counter,1);eq(s.aiRng.counter,1)
 assert(C.endTurn(s));eq(intent(s.enemies[1]),'divider');eq(s.aiRng.counter,1)
 s.player.block=100;assert(C.endTurn(s));eq(intent(s.enemies[1]),'sear');eq(s.aiRng.counter,2)
end)
test('Divider captures floor(current HP/12)+1 during Activate, not on the attack',function()
 for _,hp in ipairs({1,11,12,23,24,71,72,80,95})do
  local s=battle('hexaghost',hp);local e=s.enemies[1]
  assert(C.endTurn(s));eq(intent(e),'divider')
  local attack=e.intents[e.intentIndex].effects[1]
  eq(attack.value,math.floor(hp/12)+1);eq(attack.times,6)
  s.player.hp=500;local before=s.player.hp
  assert(C.endTurn(s));eq(before-s.player.hp,6*(math.floor(hp/12)+1))
 end
end)
test('Hexaghost repeats the full source cycle with 2 Strength after Inflame',function()
 local s=battle('hexaghost');local e=s.enemies[1]
 local expected={'activate','divider','sear','tackle','sear','inflame','tackle','sear','inferno',
  'sear','tackle','sear','inflame','tackle','sear','inferno','sear'}
 for i,id in ipairs(expected)do
  eq(intent(e),id);s.player.block=1000
  assert(C.endTurn(s))
  if i==6 then eq(e.block,12);eq(e.statuses.strength,2)end
  if i==13 then eq(e.block,12);eq(e.statuses.strength,4)end
 end
 eq(s.player.hp,500)
end)
test('Inferno resolves six separate 2-base attacks before three upgraded Burns',function()
 local s=battle('hexaghost');local e=s.enemies[1]
 force(e,'inferno');local before=#s.events;local uid=s.nextUid
 assert(C.endTurn(s));eq(s.player.hp,488);eq(s.nextUid,uid+3)
 local hits,created,lastHit=0,nil,nil
 for i=before+1,#s.events do
  local ev=s.events[i]
  if ev.kind=='damage' and ev.detail.source==e.id then hits=hits+1;lastHit=i end
  if ev.kind=='cards_created' and ev.detail.cardId=='burn'then created=i end
 end
 eq(hits,6);assert(created>lastHit);eq(#cards(s,'burn'),3)
 for _,card in ipairs(cards(s,'burn'))do assert(card.upgraded);eq(C.cardDefinition(s,card).burnDamage,4)end
 eq(intent(e),'sear')
end)
test('BurnIncrease upgrades discard then draw, excludes hand/exhaust, and preserves UIDs',function()
 local s=battle('hexaghost');local e=s.enemies[1]
 s.hand={{uid=1,cardId='burn',upgraded=false}}
 s.draw={{uid=2,cardId='burn',upgraded=false},{uid=3,cardId='strike',upgraded=false}}
 s.discard={{uid=4,cardId='burn',upgraded=false},{uid=5,cardId='burn',upgraded=true,upgrades=1}}
 s.exhaust={{uid=6,cardId='burn',upgraded=false}};s.nextUid=7
 e.act1ExecutingIntent='inferno';Bosses.afterEffects(s,e)
 eq(s.hand[1].upgraded,false);eq(s.exhaust[1].upgraded,false)
 eq(s.draw[1].uid,2);eq(s.draw[1].upgraded,true);eq(s.draw[2].upgraded,false)
 eq(s.discard[1].uid,4);eq(s.discard[1].upgraded,true);eq(s.discard[2].upgrades,1)
 for i=3,5 do eq(s.discard[i].uid,i+4);eq(s.discard[i].upgraded,true)end
 eq(s.nextUid,10)
end)
test('Sear changes to upgraded Burn after the first Inferno',function()
 local s=battle('hexaghost');local e=s.enemies[1]
 force(e,'sear');assert(C.endTurn(s));eq(#cards(s,'burn'),1);eq(cards(s,'burn')[1].upgraded,false)
 force(e,'inferno');s.player.block=1000;assert(C.endTurn(s))
 for _,card in ipairs(cards(s,'burn'))do assert(card.upgraded)end
 s.hand,s.draw,s.discard,s.exhaust={},{},{},{}
 eq(intent(e),'sear');assert(C.endTurn(s));eq(#cards(s,'burn'),1);eq(cards(s,'burn')[1].upgraded,true)
end)
test('lethal player damage stops Inferno before BurnIncrease and queued roll',function()
 local run,s=room('Hexaghost',{GUARDIAN=true});local e=s.enemies[1]
 force(e,'inferno');s.player.hp=1;local rng=s.aiRng.counter
 assert(C.endTurn(s));eq(s.phase,'defeat');eq(#cards(s,'burn'),0);eq(s.aiRng.counter,rng)
 assert(e.hexBurnUpgraded) -- source sets this flag while queueing takeTurn.
 eq(run.phase,'combat') -- direct Combat command does not claim a Run transaction.
end)
test('dead Hexaghost still consumes its queued roll while another monster lives',function()
 local s=battle('hexaghost',500,{'hexaghost','cultist'});local e=s.enemies[1]
 force(e,'divider');e.hp=1;s.player.statuses.thorns=3
 local old,calls=C.random,{}
 C.random=function(state,n)calls[#calls+1]=n;return old(state,n)end
 local ok,why=pcall(C.endTurn,s);C.random=old;assert(ok,why)
 eq(e.hp,0);eq(#calls,2);eq(calls[1],100);eq(calls[2],100)
 eq(intent(e),'sear');eq(C.outcome(s),nil)
end)
test('queued BurnIncrease survives owner death with an ally and clears on final victory',function()
 for _,ally in ipairs({false,true})do
  local s=battle('hexaghost',500,ally and {'hexaghost','cultist'} or {'hexaghost'})
  local e=s.enemies[1];force(e,'inferno');e.hp=1;s.player.statuses.thorns=3
  assert(C.endTurn(s));eq(e.hp,0)
  eq(#cards(s,'burn'),ally and 3 or 0)
  if ally then for _,card in ipairs(cards(s,'burn'))do assert(card.upgraded)end
  else eq(s.phase,'victory')end
 end
end)
test('normal Slime Boss room uses A0 140 HP and setMove cycle without turn rolls',function()
 local _,s=room('Slime Boss',{GUARDIAN=true,GHOST=true});local e=s.enemies[1]
 eq(e.hp,140);eq(s.monsterHpRng.counter,1);eq(s.aiRng.counter,1)
 for _,id in ipairs({'sticky','prepare','slam','sticky'})do
  eq(intent(e),id);s.player.block=100;assert(C.endTurn(s));eq(s.aiRng.counter,1)
 end
 eq(#cards(s,'slimed'),6)
end)
test('Slime Boss interrupts at half HP and snapshots remaining HP at split time',function()
 local s=battle('slime_boss');local e=s.enemies[1]
 C.damage(s,s.player,e,69,true);eq(e.hp,71);eq(intent(e),'sticky')
 C.damage(s,s.player,e,1,true);eq(e.hp,70);eq(intent(e),'split');eq(#s.enemies,1)
 C.damage(s,s.player,e,7,true);assert(C.endTurn(s))
 eq(#s.enemies,3);eq(s.enemies[2],e);eq(e.hp,0)
 eq(s.enemies[1].definitionId,'spike_slime_l');eq(s.enemies[3].definitionId,'acid_slime_l')
 for _,i in ipairs({1,3})do eq(s.enemies[i].hp,63);eq(s.enemies[i].maxHp,63)end
 eq(s.enemies[1].sourcePosition.x,-385);eq(s.enemies[3].sourcePosition.x,120)
 eq(s.player.hp,500);eq(C.outcome(s),nil)
end)
test('Slime Boss split children consume two opening rolls and no HP draws or parent roll',function()
 local _,s=room('Slime Boss',{GUARDIAN=true,GHOST=true});local e=s.enemies[1]
 C.damage(s,s.player,e,80,true);local hp,ai=s.monsterHpRng.counter,s.aiRng.counter
 assert(C.endTurn(s));eq(s.monsterHpRng.counter,hp);eq(s.aiRng.counter,ai+2)
end)
test('Slime Boss split does not transfer powers, trigger spore death, or act newborns',function()
 local s=battle('slime_boss');local e=s.enemies[1]
 C.damage(s,s.player,e,80,true);e.statuses.spore_cloud=2;e.statuses.strength=6;e.statuses.poison=2
 assert(C.endTurn(s));eq(s.player.hp,500);eq(s.player.statuses.vulnerable or 0,0)
 -- Source large-slime constructors always append their own SplitPower;
 -- no parent Poison/Strength/SporeCloud is transferred to these fresh actors.
 for _,i in ipairs({1,3})do
  local child=s.enemies[i];eq(child.hp,58)
  eq(child.statuses.split,-1);eq(table.concat(child.powerOrder,','),'split')
  local n=0;for id,amount in pairs(child.statuses)do eq(id,'split');eq(amount,-1);n=n+1 end;eq(n,1)
 end
end)
test('Slime Boss children split through the existing large-slime policies next',function()
 local s=battle('slime_boss');C.damage(s,s.player,s.enemies[1],80,true);assert(C.endTurn(s))
 for _,i in ipairs({1,3})do C.damage(s,s.player,s.enemies[i],31,true)end
 assert(C.endTurn(s));local live={}
 for _,e in ipairs(s.enemies)do if e.hp>0 then live[#live+1]=e;eq(e.hp,29);eq(e.maxHp,29)end end
 eq(#live,4);eq(live[1].definitionId,'spike_slime_m');eq(live[4].definitionId,'acid_slime_m')
end)
test('Slam retaliation interrupts to Split without erasing the already queued 35 damage',function()
 local s=battle('slime_boss');local e=s.enemies[1]
 force(e,'slam');e.hp=71;s.player.statuses.thorns=1
 assert(C.endTurn(s));eq(s.player.hp,465);eq(e.hp,70);eq(intent(e),'split');eq(#s.enemies,1)
 assert(C.endTurn(s));eq(s.player.hp,465);eq(#s.enemies,3)
end)
test('lethal damage or poison cancels pending Slime Boss split',function()
 for _,poison in ipairs({false,true})do
  local s=battle('slime_boss');local e=s.enemies[1];C.damage(s,s.player,e,80,true)
  if poison then e.statuses.poison=60 else C.damage(s,s.player,e,60,true)end
  assert(C.endTurn(s));eq(s.phase,'victory');eq(#s.enemies,1)
 end
end)
test('Run keeps the split Boss in combat until all children die, then rewards once',function()
 local run,s=room('Slime Boss',{GUARDIAN=true,GHOST=true});local e=s.enemies[1]
 C.damage(s,s.player,e,80,true);assert(Run.endTurn(run));eq(run.phase,'combat');eq(run.victories,0)
 C.damage(s,s.player,s.enemies[1],60,true);assert(Run.endTurn(run));eq(run.phase,'combat');eq(run.victories,0)
 for _,enemy in ipairs(s.enemies)do if enemy.hp>0 then C.damage(s,s.player,enemy,999,true)end end
 assert(Run.endTurn(run));eq(run.phase,'reward');eq(run.victories,1)
 local gold=run.gold;eq(Run.endTurn(run),false);eq(run.gold,gold);eq(run.victories,1)
end)
test('Boss catalog and Burn upgrades remain private to each Combat',function()
 local before=C.copy(D.cards.cards)
 local a=battle('hexaghost');local b=battle('hexaghost')
 a.enemies[1].intents[2].effects[1].value=99
 eq(b.enemies[1].intents[2].effects[1].value,1)
 eq(a.catalog.cards.burn.upgrade.burnDamage or a.catalog.cards.burn.upgrade.endTurnDamage,4)
 eq(C.canUpgrade(a,{cardId='burn',uid=99,upgraded=false}),false,'ordinary upgrades exclude statuses')
 same(D.cards.cards,before)
end)
print('LUA_ACT1_BOSSES_PASS '..count)
