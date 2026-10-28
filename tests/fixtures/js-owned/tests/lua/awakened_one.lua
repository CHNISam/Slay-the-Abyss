-- Controlled source-contract fixtures, not a natural campaign or native game.
local C,A,D=require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local B,AI=require('abyss_awakened_one'),require('abyss_enemy_ai')
local SF=require('abyss_silent_final_cards')
local Run,Q,R=require('abyss_run'),require('abyss_encounter_queue'),require('abyss_sts_random')
local count,failed=0,0
local function eq(a,b,label)
 assert(a==b,'[AWAKENED_ASSERT '..(label or 'value')..'] '..tostring(a)..' ~= '..tostring(b))
end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then return eq(a,b)end
 seen=seen or {};if seen[a]then return eq(seen[a],b)end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected field '..tostring(k))end
end
local function test(name,fn)
 if ABYSS_MUTATION_CASE and ABYSS_MUTATION_CASE~=name then return end
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local data=C.copy(D);data.statuses=SF.withCardDefinitions(D).statuses
local function battle(mode,deck,allies)
 local s=C.new(data,{seed=42,cardRandomSeed='42',enemies=allies and {'cultist','cultist','awakened_one'}or {'awakened_one'},
  deck=deck or {},hp=500,maxHp=500,enableStances=mode=='advanced'})
 return s,s.enemies[#s.enemies]
end
local function intent(e)return e.intents[e.intentIndex].id end
local function force(e,id)
 for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end;error(id)
end
local function card(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('no hand card '..id)
end
local function zeroFirst(s,e)C.damage(s,s.player,e,1000,true);eq(e.hp,0);assert(e.halfDead)end
local function events(s,kind,id)
 local out={};for _,event in ipairs(s.events)do if event.kind==kind and (not id or event.detail.target==id)then out[#out+1]=event end end
 return out
end
local function corpseTrace(s,fn)
 local old,n=SF.apply,0
 SF.apply=function(api,state,item,...)
  if state==s and item.effect.kind=='corpseDamage'then n=n+1 end
  return old(api,state,item,...)
 end
 local ok,why=pcall(fn);SF.apply=old;assert(ok,why);return n
end
test('source resolver selects the real three-actor formation',function()
 local e=assert(require('abyss_act3_bosses').resolve('Awakened One','boss'),'[AWAKENED_ASSERT resolver] source Boss unavailable')
 eq(e.sourceEncounter,'Awakened One');eq(e.tier,'boss')
 eq(require('abyss_act3_bosses').resolve('Awakened One','elite'),nil)
 local calls={}
 local formation=require('abyss_encounter_formation').assemble(e.sourceEncounter,{misc={},construct=function(id,x,y)
  calls[#calls+1]={id,x,y};return {id=id}
 end})
 eq(#formation,3);same(calls,{{'cultist',-590,10},{'cultist',-298,-10},{'awakened_one',100,15}})
end)
test('opening power amounts retain source acquisition order and no A4 strength',function()
 local s,e=battle();eq(e.hp,300);eq(e.maxHp,300);eq(intent(e),'slash')
 eq(e.statuses.regenerate_monster,10);eq(e.statuses.curiosity,1);eq(e.statuses.unawakened,-1)
 eq(e.statuses.strength,nil);eq(table.concat(e.powerOrder,','),'regenerate_monster,curiosity,unawakened')
 assert(s.awakenedCannotLose);assert(s.catalog.cards.void.ethereal)
end)
test('all first-form AI thresholds and repeat restrictions consume one primary draw',function()
 for _,history in ipairs({{'slash'},{'slash','slash'},{'soul_strike'}})do
  for roll=0,99 do
   local e=C.copy(B.enemy);e.awakenedForm=1;e.awakenedHistory=C.copy(history)
   local calls=0;B.afterAction({},e,function(_,n)eq(n,100);calls=calls+1;return roll+1 end)
   local last,previous=history[#history],history[#history-1]
   local expected=roll<25 and (last=='soul_strike'and 'slash'or 'soul_strike')
    or (last=='slash'and previous=='slash'and 'soul_strike'or 'slash')
   eq(intent(e),expected,'phase1 AI');eq(calls,1)
  end
 end
end)
test('all second-form AI thresholds and repeat restrictions consume one primary draw',function()
 for _,history in ipairs({{'dark_echo'},{'sludge','sludge'},{'tackle','tackle'},{'sludge','tackle'}})do
  for roll=0,99 do
   local e=C.copy(B.enemy);e.awakenedForm=2;e.awakenedFirst=false;e.awakenedHistory=C.copy(history)
   local calls=0;B.afterAction({},e,function(_,n)eq(n,100);calls=calls+1;return roll+1 end)
   local last,previous=history[#history],history[#history-1]
   local expected=roll<50 and (last=='sludge'and previous=='sludge'and 'tackle'or 'sludge')
    or (last=='tackle'and previous=='tackle'and 'sludge'or 'tackle')
   eq(intent(e),expected,'phase2 AI');eq(calls,1)
  end
 end
end)
for _,mode in ipairs({'native','advanced'})do
 test(mode..' first death is nonterminal and untargetable while self cards still resolve',function()
  local s,e=battle(mode,{'strike','defend','inflame'})
  zeroFirst(s,e);eq(C.outcome(s),nil,'first death nonterminal');eq(A.isActive(e),false);eq(A.isPresent(e),true)
  eq(intent(e),'rebirth');eq(C.play(s,card(s,'strike').uid,1),false)
  assert(C.play(s,card(s,'defend').uid));eq(s.player.block,5)
  assert(C.play(s,card(s,'inflame').uid));eq(s.player.statuses.strength,2);eq(e.statuses.curiosity,nil)
 end)
 test(mode..' Rebirth is an enemy action at zero HP and Dark Echo attacks only next turn',function()
  local s,e=battle(mode);zeroFirst(s,e);local hp=s.player.hp
  assert(C.endTurn(s));eq(e.hp,300,'real Rebirth HP');eq(e.halfDead,false);eq(e.awakenedRebirthPending,nil)
  eq(s.awakenedCannotLose,nil);eq(s.player.hp,hp);eq(intent(e),'dark_echo')
  assert(C.endTurn(s));eq(s.player.hp,hp-40,'Dark Echo');eq(e.awakenedFirst,false)
 end)
 test(mode..' first lethal poison removes the actual Power and rebirth happens in the same enemy turn',function()
  local s,e=battle(mode);A.applyPower(s,e,'poison',300,s.player)
  assert(C.endTurn(s));eq(e.hp,300);eq(e.statuses.poison,nil,'Poison not reinserted');eq(intent(e),'dark_echo')
  eq(#events(s,'status_damage',e.id),1);eq(s.player.hp,500)
 end)
 test(mode..' source Rebirth tail failure restores the zero-HP actor and entire command in place',function()
  local s,e=battle(mode);zeroFirst(s,e)
  local before=C.copy(s);local hand,history=s.hand,e.awakenedHistory;local old=B.resolve
  B.resolve=function(api,state,effect)
   local result=old(api,state,effect)
   if effect.kind=='canLose'then error('Rebirth tail fault')end
   return result
  end
  local ok=pcall(C.endTurn,s);B.resolve=old;eq(ok,false)
  same(s,before);eq(s.enemies[1],e);eq(s.hand,hand);eq(e.awakenedHistory,history)
  assert(C.endTurn(s));eq(e.hp,300);eq(intent(e),'dark_echo')
 end)
 test(mode..' the current Pommel Strike draw continues after first-form lethal damage',function()
  local s,e=battle(mode,{'pommel_strike'});e.hp=1
  local nextCard=require('abyss_card_actions').fresh(C,s,'defend');s.draw[#s.draw+1]=nextCard
  assert(C.play(s,card(s,'pommel_strike').uid,1));assert(e.halfDead)
  eq(s.hand[1],nextCard,'current draw continuation');eq(s.cardInUse,nil)
 end)
 test(mode..' Curiosity resolves after the Power effects and before disposal, never on skills',function()
  local s,e=battle(mode,{'inflame','defend'});local played=card(s,'inflame')
  assert(C.play(s,played.uid));eq(e.statuses.strength,1,'Curiosity strength');eq(s.player.statuses.strength,2)
  local playerStrength,bossStrength
  for i,event in ipairs(s.events)do if event.kind=='status'and event.detail.status=='strength'then
   if event.detail.target==s.player.id then playerStrength=i elseif event.detail.target==e.id then bossStrength=i end
  end end
  assert(playerStrength and bossStrength and playerStrength<bossStrength)
  assert(C.play(s,card(s,'defend').uid));eq(e.statuses.strength,1)
 end)
 test(mode..' Feed never rewards the first form but does reward the real second-form death',function()
  local s,e=battle(mode,{'feed','feed'});e.hp=1;local hp=s.player.maxHp
  assert(C.play(s,card(s,'feed').uid,1));eq(s.player.maxHp,hp,'Feed first-form gate');assert(e.halfDead)
  assert(C.endTurn(s));e.hp=1
  assert(C.play(s,card(s,'feed').uid,1));eq(s.player.maxHp,hp+3,'Feed final death');eq(C.outcome(s),'victory')
 end)
 test(mode..' Hand of Greed never grants gold for the first form',function()
  local s,e=battle(mode,{'hand_of_greed','hand_of_greed'});e.hp=1;local gold=s.player.gold
  assert(C.play(s,card(s,'hand_of_greed').uid,1));eq(s.player.gold,gold,'Greed first-form gate')
  assert(C.endTurn(s));e.hp=1;assert(C.play(s,card(s,'hand_of_greed').uid,1))
  eq(s.player.gold,gold+20,'Greed final death')
 end)
 test(mode..' Ritual Dagger grows only on the final death',function()
  local s,e=battle(mode,{'ritual_dagger','ritual_dagger'});e.hp=1;local first=card(s,'ritual_dagger')
  assert(C.play(s,first.uid,1));eq(first.misc or 15,15,'Dagger first-form gate')
  assert(C.endTurn(s));e.hp=1;local second=card(s,'ritual_dagger');assert(C.play(s,second.uid,1))
  eq(second.misc,18,'Dagger final death')
 end)
 test(mode..' first-form Corpse Explosion is queued before cleanup and cannot end combat',function()
  local s,e=battle(mode,nil,true);A.applyPower(s,e,'corpse_explosion',1,s.player)
  A.applyPower(s,e,'strength',4,e);A.applyPower(s,e,'shackled',2,s.player)
  A.applyPower(s,e,'weak',2,s.player);A.applyPower(s,e,'poison',3,s.player)
  local n=corpseTrace(s,function()zeroFirst(s,e)end)
  eq(n,1);eq(s.enemies[1].hp,0);eq(s.enemies[2].hp,0);eq(C.outcome(s),nil,'Corpse preserves phase')
  for _,id in ipairs({'corpse_explosion','weak','poison','shackled','curiosity','unawakened'})do eq(e.statuses[id],nil,id..' removed')end
  eq(e.statuses.strength,4);eq(e.statuses.regenerate_monster,10)
 end)
 test(mode..' final-form death queues cultist escapes between the source duplicate death visits',function()
  local s,e=battle(mode,nil,true);zeroFirst(s,e);assert(C.endTurn(s))
  for i=1,2 do s.enemies[i].hp=1000;s.enemies[i].maxHp=1000 end
  A.applyPower(s,e,'corpse_explosion',1,s.player)
  local n=corpseTrace(s,function()C.damage(s,s.player,e,1000,true)end)
  eq(n,2,'source final death callbacks');eq(e.hp,0);assert(e.isDying)
  for i=1,2 do eq(s.enemies[i].hp,700);eq(s.enemies[i].escaped,true,'Cultist escapes without death')end
  eq(C.outcome(s),'victory');eq(#events(s,'enemy_escape'),2)
 end)
 test(mode..' lethal retaliation keeps the queued roll then restores Rebirth intent',function()
  local s,e=battle(mode);e.hp=1;s.player.statuses.thorns=3
  local old,calls=C.random,0
  C.random=function(state,n)calls=calls+1;return old(state,n)end
  local ok,why=pcall(C.endTurn,s);C.random=old;assert(ok,why)
  eq(e.hp,0);assert(e.halfDead);eq(intent(e),'rebirth','SetMove after queued roll');eq(calls,1)
  eq(s.player.hp,480);eq(C.outcome(s),nil)
 end)
 test(mode..' Regenerate heals ten without consuming stacks and precedes later Shackled restoration',function()
  local s,e=battle(mode);e.hp=280
  A.applyPower(s,e,'strength',-2,s.player);A.applyPower(s,e,'shackled',2,s.player)
  local first=#s.events+1;assert(C.endTurn(s));eq(e.hp,290);eq(e.statuses.regenerate_monster,10)
  eq(e.statuses.strength,0);eq(e.statuses.shackled,nil)
  local healing,restoration
  for i=first,#s.events do local ev=s.events[i]
   if ev.kind=='heal'and ev.detail.target==e.id then healing=i end
   if ev.kind=='status'and ev.detail.target==e.id and ev.detail.status=='strength'then restoration=i end
  end
  assert(healing and restoration and healing<restoration,'source acquired Power order')
 end)
 test(mode..' a post-transition failure rolls back actors, queues, powers and RNG in place',function()
  local s,e=battle(mode,{'strike'});e.hp=1
  local before=C.copy(s);local hand,order=s.hand,e.powerOrder;local old=B.deathFinish
  B.deathFinish=function(state,actor,push)old(state,actor,push);error('post-transition fault')end
  local ok=pcall(C.play,s,card(s,'strike').uid,1);B.deathFinish=old;eq(ok,false)
  same(s,before);eq(s.enemies[1],e);eq(s.hand,hand);eq(e.powerOrder,order)
  assert(C.play(s,card(s,'strike').uid,1));eq(C.outcome(s),nil);assert(e.halfDead)
 end)
end
test('lethal HP loss clears Block at the exact superclass versus override death boundary',function()
 local s,e=battle();e.block=17;A.applyPower(s,e,'barricade',1,e);A.applyPower(s,e,'poison',300,s.player)
 assert(C.endTurn(s));eq(e.hp,300);eq(e.block,0,'first-form poison clears retained Block')
 local other,boss=battle();boss.block=21;A.instantKill(other,boss);eq(boss.block,0,'first-form InstantKill clears Block')
 local final,owner=battle(nil,nil,true);zeroFirst(final,owner);assert(C.endTurn(final))
 for i=1,2 do final.enemies[i].hp=1000;final.enemies[i].maxHp=1000 end
 owner.block=23;A.applyPower(final,owner,'corpse_explosion',1,final.player)
 local old,blocks=SF.death,{}
 SF.death=function(state,target,before,push)
  if state==final and target==owner then blocks[#blocks+1]=target.block end
  return old(state,target,before,push)
 end
 local ok,why=pcall(A.loseHp,final,owner,300);SF.death=old;assert(ok,why)
 eq(#blocks,2);eq(blocks[1],23,'super death sees original Block');eq(blocks[2],0,'override death sees cleared Block')
 eq(owner.block,0);require('abyss_card_actions').drain(C,final);eq(C.outcome(final),'victory')
end)
test('InstantKill preserves the phase and its detached zero-HP presentation frame',function()
 local s,e=battle();A.instantKill(s,e);eq(C.outcome(s),nil);eq(e.hp,0);assert(e.halfDead)
 local hit=events(s,'damage',e.id)[1];assert(hit and hit.frame.enemies[1].halfDead)
end)
test('ClearCardQueue cancels queued copies but preserves the current card continuation',function()
 local s,e=battle('native',{'strike'});e.hp=1;A.applyPower(s,s.player,'double_tap',1,s.player)
 local strike=card(s,'strike')
 local pending=require('abyss_card_actions').fresh(C,s,'defend')
 C.queueCard(s,pending,{append=true})
 assert(C.play(s,strike.uid,1));eq(#events(s,'play'),1,'queued copy cleared');eq(s.player.block,0)
 eq(s.queuedCards,nil);eq(s.cardInUse,nil);eq(s.discard[#s.discard].uid,strike.uid)
 assert(e.halfDead);eq(C.outcome(s),nil)
end)
test('Sludge uses card RNG insertion and the existing Void draw and ethereal semantics',function()
 local s,e=battle();zeroFirst(s,e);assert(C.endTurn(s));force(e,'sludge')
 s.draw={};s.discard={};s.hand={};local uid=s.nextUid;local rng=R.snapshot(s.cardRandomRng)
 assert(C.endTurn(s));eq(s.nextUid,uid+1);eq(s.player.hp,482);eq(s.energy,2,'Void draw energy loss')
 same(R.snapshot(s.cardRandomRng),rng);eq(s.hand[1].cardId,'void');eq(s.hand[1].uid,uid)
 force(e,'tackle');s.player.block=100;assert(C.endTurn(s))
 eq(s.exhaust[#s.exhaust].uid,uid,'Void ethereal')
end)
test('Sludge card insertion consumes one card draw but never HP or AI source draws itself',function()
 local s,e=battle();s.draw={{uid=900,cardId='strike'},{uid=901,cardId='defend'},{uid=902,cardId='bash'}}
 local expected=R.cloneState(s.cardRandomRng);local position=R.randomInt(expected,2)+1;local uid=s.nextUid
 B.void(s,e);eq(s.draw[position].uid,uid);eq(s.draw[position].cardId,'void')
 same(R.snapshot(s.cardRandomRng),R.snapshot(expected))
end)
test('ordinary third-act Run entry preserves source streams and rewards only after final death',function()
 local run=Run.new(D,'42',{experimental=true,campaign=true})
 run.act,run.floor,run.encounters=3,50,Q.new('42',3)
 run.bossInitialization,run.encounters=Q.initializeBoss(run.encounters,{})
 eq(run.bossInitialization.bossList[1],'Awakened One')
 local misc=run.miscRng.counter;assert(Run.startRoomCombat(run,'boss'))
 local s,e=run.combat,run.combat.enemies[3]
 eq(run.encounterSource,'Awakened One');eq(s.monsterHpRng.counter,3);eq(s.aiRng.counter,3)
 eq(run.miscRng.counter,misc);eq(s.enemies[1].sourcePosition.x,-590);eq(s.enemies[2].sourcePosition.x,-298)
 for i=1,2 do assert(s.enemies[i].hp>=48 and s.enemies[i].hp<=54);eq(s.enemies[i].statuses.minion,nil)end
 zeroFirst(s,e);assert(Run.endTurn(run));eq(run.phase,'combat');eq(run.victories,0)
 eq(s.aiRng.counter,6);eq(e.hp,300);eq(intent(e),'dark_echo');eq(s.monsterHpRng.counter,3)
 C.damage(s,s.player,e,1000,true);assert(Run.endTurn(run));eq(run.phase,'reward');eq(run.victories,1)
 local gold=run.gold;eq(Run.endTurn(run),false);eq(run.gold,gold);eq(run.victories,1)
end)
print('LUA_AWAKENED_ONE '..count..' groups; '..failed..' failed')
assert(count>0 and failed==0,'Awakened One source contract regression')
