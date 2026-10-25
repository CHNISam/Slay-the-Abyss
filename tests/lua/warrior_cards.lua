package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local W=require('abyss_warrior_cards')
local Data=require('abyss_data')
local data=W.withFoundationCards(Data)
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok warrior card '..n..' - '..name) end
local function battle(deck,enemies)
 local s=C.new(data,{seed=42,deck=deck or {},enemies=enemies or {'jaw_worm'}})
 s.cardRandomRng=R.fromSeed('42');return s
end
local function uid(s,id)
 for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
 error('missing '..id)
end
local function inst(id,up) return {cardId=id,upgraded=up} end
local function eventIndex(s,kind,status)
 for i,e in ipairs(s.events) do if e.kind==kind and (not status or e.detail.status==status) then return i,e end end
end
test('experimental overrides stay detached and seven-only over the native75 catalog',function()
 eq(#data.cards.cards,#Data.cards.cards)
 local count=0
 for i,c in ipairs(data.cards.cards) do
  if c.experimental then count=count+1 end
  eq(Data.cards.cards[i].experimental,nil)
 end
 local native=0
 for _,c in ipairs(Data.cards.cards)do if c.type=='attack'or c.type=='skill'or c.type=='power'then native=native+1 end end
 eq(native,75);eq(count,7)
 -- Native75 already defines these Powers; opt-in overrides must not duplicate them.
 eq(#data.statuses.statuses,#Data.statuses.statuses)
 eq(Data.experimentalWarrior,nil);eq(data.experimentalWarrior,true)
 eq(pcall(W.withFoundationCards,data),false)
end)
test('experimental Ironclad profile preserves the real starter and Burning Blood',function()
 local d,p=W.prepareProfile(Data)
 eq(p.id,'ironclad');eq(p.color,'red');eq(p.experimental,true)
 eq(d.rules.player.maxHp,80);eq(d.rules.player.energyPerTurn,3);eq(d.rules.player.drawPerTurn,5)
 eq(d.rules.player.startingGold,99);eq(d.rules.player.startingRelics[1],'burning_blood')
 eq(#d.cards.starter_deck.cards,10)
 for i=1,5 do eq(d.cards.starter_deck.cards[i],'strike') end
 for i=6,9 do eq(d.cards.starter_deck.cards[i],'defend') end
 eq(d.cards.starter_deck.cards[10],'bash')
 d.cards.starter_deck.cards[1]='changed';eq(p.starterDeck[1],'strike');eq(Data.cards.starter_deck.cards[1],'strike')
 eq(pcall(W.prepareProfile,d),false)
end)
for _,up in ipairs({false,true}) do
 test('Clash only accepts an attack-only real hand '..tostring(up),function()
  local s=battle({inst('clash',up),'strike'});s.enemies[1].hp=100
  assert(C.play(s,uid(s,'clash'),1));eq(s.enemies[1].hp,up and 82 or 86);eq(s.energy,3)
  local blocked=battle({inst('clash',up),'regret'});local hp=blocked.enemies[1].hp
  eq(C.play(blocked,uid(blocked,'clash'),1),false);eq(blocked.enemies[1].hp,hp);eq(blocked.energy,3)
 end)
 test('True Grit no remaining hand still blocks and never exhausts itself '..tostring(up),function()
  local s=battle({inst('true_grit',up)})
  assert(C.play(s,uid(s,'true_grit')));eq(s.player.block,up and 9 or 7)
  eq(#s.exhaust,0);eq(#s.discard,1);eq(s.cardRandomRng.counter,0);eq(s.energy,2)
 end)
 test('True Grit single remaining hand auto-exhausts with no RNG '..tostring(up),function()
  local s=battle({inst('true_grit',up),'strike'});local strike=uid(s,'strike')
  assert(C.play(s,uid(s,'true_grit')));eq(s.exhaust[1].uid,strike);eq(s.exhaust[1].cardId,'strike')
  eq(s.cardRandomRng.counter,0);eq(s.pendingHandChoice,nil);eq(#s.discard,1)
 end)
 test('Warcry empty draw and no hand simply exhausts itself '..tostring(up),function()
  local s=battle({inst('warcry',up)});local w=uid(s,'warcry')
  assert(C.play(s,w));eq(#s.hand,0);eq(#s.draw,0);eq(#s.exhaust,1)
  eq(s.exhaust[1].uid,w);eq(s.energy,3);eq(s.cardRandomRng.counter,0)
 end)
 test('Warcry one remaining card auto-puts top and consumes one RNG '..tostring(up),function()
  local s=battle({inst('warcry',up),'defend'});local defend=uid(s,'defend')
  assert(C.play(s,uid(s,'warcry')));eq(#s.hand,0);eq(#s.draw,1);eq(s.draw[1].uid,defend)
  eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'warcry');eq(s.cardRandomRng.counter,1)
 end)
 test('Demon Form gains only after the next player draw '..tostring(up),function()
  local s=battle({inst('demon_form',up),'strike'},{'cultist'})
  assert(C.play(s,uid(s,'demon_form')));eq(s.energy,0);eq(s.player.statuses.strength or 0,0)
  eq(#s.discard,0);eq(#s.exhaust,0)
  assert(C.endTurn(s));eq(s.player.statuses.strength,up and 3 or 2)
  local strengthIndex
  for i,e in ipairs(s.events) do
   if e.kind=='status' and e.detail.status=='strength' and e.detail.target==s.player.id then strengthIndex=i;break end
  end
  assert(strengthIndex)
  assert(#s.events[strengthIndex].frame.hand>0,'post-draw Strength must see the new hand')
 end)
 test('Metallicize fixed block precedes Regret and ignores Dexterity/Frail '..tostring(up),function()
  local s=battle({inst('metallicize',up),'regret'},{'cultist'})
  assert(C.play(s,uid(s,'metallicize')));eq(s.player.block,0)
  s.player.statuses.dexterity=10;s.player.statuses.frail=1
  assert(C.endTurn(s))
  local blockIndex,block=eventIndex(s,'block');local lossIndex=eventIndex(s,'hp_loss')
  assert(blockIndex and lossIndex and blockIndex<lossIndex)
  eq(block.detail.amount,up and 4 or 3)
 end)
 test('Whirlwind consumes real X and preserves normal damage reactions '..tostring(up),function()
  local s=battle({inst('whirlwind',up)})
  s.enemies[1].hp=100;s.enemies[1].maxHp=100;s.enemies[1].statuses.thorns=2
  local hp=s.player.hp
  assert(C.play(s,uid(s,'whirlwind')));eq(s.energy,0)
  eq(s.enemies[1].hp,up and 76 or 85);eq(s.player.hp,hp-6);eq(#s.discard,1)
 end)
 test('Whirlwind zero energy is a legal zero-hit attack '..tostring(up),function()
  local s=battle({inst('whirlwind',up)});s.energy=0;local hp=s.enemies[1].hp
  assert(C.play(s,uid(s,'whirlwind')));eq(s.energy,0);eq(s.enemies[1].hp,hp);eq(#s.discard,1)
 end)
 test('Reaper healing is the sum of actual HP loss after block and overkill '..tostring(up),function()
  local s=battle({inst('reaper',up)},{'jaw_worm','jaw_worm'})
  s.player.hp=50;s.enemies[1].hp=1;s.enemies[1].block=0;s.enemies[2].hp=10;s.enemies[2].block=2
  assert(C.play(s,uid(s,'reaper')))
  eq(s.player.hp,up and 54 or 53);eq(s.enemies[1].hp,0);eq(s.enemies[2].hp,up and 7 or 8)
  eq(s.energy,1);eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'reaper')
 end)
end
test('basic True Grit multiple candidates consumes exactly one independent RNG call',function()
 local s=battle({'true_grit','strike','defend'})
 assert(C.play(s,uid(s,'true_grit')));eq(#s.exhaust,1);eq(#s.hand,1)
 eq(s.cardRandomRng.counter,1);eq(s.pendingHandChoice,nil)
end)
test('upgraded True Grit pauses after block then selected UID exhausts',function()
 local s=battle({inst('true_grit',true),'strike','defend'})
 local t,chosen=uid(s,'true_grit'),uid(s,'strike')
 assert(C.play(s,t));eq(s.player.block,9);assert(s.pendingHandChoice)
 eq(s.cardInUse.uid,t);eq(#s.discard,0)
 eq(C.play(s,uid(s,'defend')),false);eq(C.endTurn(s),false)
 eq(C.chooseHand(s,{},s.pendingHandChoice.token),false)
 assert(C.chooseHand(s,{chosen},s.pendingHandChoice.token));eq(s.exhaust[1].uid,chosen)
 eq(s.discard[1].uid,t);eq(s.pendingHandChoice,nil);eq(s.cardRandomRng.counter,0)
end)
test('Warcry pauses after its draw and places only the chosen hand UID on top',function()
 local s=battle({'warcry','strike','defend'});local w=uid(s,'warcry');local chosen=uid(s,'strike')
 assert(C.play(s,w));assert(s.pendingHandChoice);eq(s.cardInUse.uid,w);eq(#s.exhaust,0)
 assert(C.chooseHand(s,{chosen},s.pendingHandChoice.token));eq(s.draw[#s.draw].uid,chosen)
 eq(#s.hand,1);eq(s.hand[1].cardId,'defend');eq(s.exhaust[1].uid,w);eq(s.cardRandomRng.counter,0)
end)
test('Reaper last kill retains its queued heal and respects maximum health',function()
 local s=battle({'reaper'});s.player.hp=79;s.enemies[1].hp=2;s.enemies[1].block=0
 assert(C.play(s,uid(s,'reaper')));eq(s.player.hp,80);eq(s.phase,'victory');eq(#s.exhaust,1)
end)
test('Reaper cannot heal before lethal Sharp Hide retaliation',function()
 local s=battle({'reaper'},{'guardian'});s.player.hp=2;s.enemies[1].hp=20;s.enemies[1].statuses.sharp_hide=3
 assert(C.play(s,uid(s,'reaper')));eq(s.player.hp,0);eq(s.phase,'defeat')
end)
test('Reaper fully blocked damage does not heal',function()
 local s=battle({'reaper'});s.player.hp=50;s.enemies[1].block=999
 assert(C.play(s,uid(s,'reaper')));eq(s.player.hp,50)
end)
test('native75 Clash is playable without experimental activation and keeps its hand restriction',function()
 for _,up in ipairs({false,true})do
  local s=C.new(Data,{seed=42,deck={inst('clash',up)},enemies={'jaw_worm'}})
  local card,hp=s.hand[1],s.enemies[1].hp
  eq(s.catalog.cards.clash.experimental,nil)
  assert(C.play(s,card.uid,1));eq(s.enemies[1].hp,hp-(up and 18 or 14));eq(s.energy,3)
  eq(#s.hand,0);eq(s.discard[1],card);eq(s.cardInUse,nil)
  local blocked=C.new(Data,{seed=42,deck={inst('clash',up),'defend'},enemies={'jaw_worm'}})
  local clash,enemyHp=uid(blocked,'clash'),blocked.enemies[1].hp
  eq(C.play(blocked,clash,1),false);eq(blocked.enemies[1].hp,enemyHp);eq(blocked.energy,3)
  eq(#blocked.hand,2);eq(#blocked.discard,0);eq(blocked.cardInUse,nil)
 end
end)
for _,up in ipairs({false,true}) do
 test('Warcry draws its source amount before offering hand selection '..tostring(up),function()
  local s,w
  for seed=1,16 do
   local candidate=C.new(data,{seed=seed,deck={inst('warcry',up),'strike','defend','bash','strike','defend','strike','defend'},enemies={'cultist'}})
   for _,c in ipairs(candidate.hand) do if c.cardId=='warcry' then s,w=candidate,c.uid;break end end
   if s then break end
  end
  assert(s);s.cardRandomRng=R.fromSeed('42');eq(#s.hand,5);eq(#s.draw,3)
  assert(C.play(s,w));assert(s.pendingHandChoice)
  eq(#s.hand,up and 6 or 5);eq(#s.draw,up and 1 or 2);eq(#s.exhaust,0)
  local selected=s.hand[1].uid
  assert(C.chooseHand(s,{selected},s.pendingHandChoice.token))
  eq(s.draw[#s.draw].uid,selected);eq(#s.draw,up and 2 or 3);eq(s.exhaust[1].uid,w)
 end)
end
test('Warcry still requires putting a card back when NoDraw blocks its draw',function()
 local s=battle({'warcry','strike','defend'});s.player.noDraw=true
 assert(C.play(s,uid(s,'warcry')));assert(s.pendingHandChoice);eq(#s.hand,2)
 local selected=s.hand[1].uid;assert(C.chooseHand(s,{selected},s.pendingHandChoice.token))
 eq(s.draw[#s.draw].uid,selected);eq(#s.hand,1)
end)
test('Whirlwind reuses its original NORMAL matrix after live modifiers change',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('whirlwind',up)},{'red_louse'});local enemy=s.enemies[1]
  enemy.hp=200;enemy.maxHp=200;enemy.block=0;enemy.statuses.curl_up=6;enemy.curlUpTriggered=nil
  enemy.statuses.thorns=2
  local original,hits=C.damage,0
  C.damage=function(state,source,target,base,fixed,reactions,normalAmount)
   local dealt=original(state,source,target,base,fixed,reactions,normalAmount)
   if state==s and source==s.player and target==enemy then
    hits=hits+1
    if hits==1 then s.player.statuses.strength=20;enemy.statuses.vulnerable=2 end
   end
   return dealt
  end
  local ok,result=pcall(C.play,s,uid(s,'whirlwind'))
  C.damage=original
  assert(ok,result);assert(result);eq(hits,3)
  eq(enemy.hp,up and 176 or 185);eq(s.player.hp,74)
  eq(enemy.block,6);eq(enemy.statuses.curl_up,0)
  local damages,lastDamage,curlBlock=0
  for i,e in ipairs(s.events) do
   if e.kind=='damage' and e.detail.source==s.player.id and e.detail.target==enemy.id then
    damages=damages+1;eq(e.detail.amount,up and 8 or 5);eq(e.detail.blocked,0);lastDamage=i
   elseif e.kind=='block' and e.detail.target==enemy.id then curlBlock=i end
  end
  eq(damages,3);assert(curlBlock and curlBlock>lastDamage,'BOTTOM Curl Up must not absorb later rounds')
 end
end)
test('zero-energy Whirlwind still triggers Sharp Hide for playing an attack',function()
 local s=battle({'whirlwind'},{'guardian'});s.energy=0;s.enemies[1].statuses.sharp_hide=3
 local hp=s.enemies[1].hp
 assert(C.play(s,uid(s,'whirlwind')))
 eq(s.energy,0);eq(s.enemies[1].hp,hp);eq(s.player.hp,77);eq(#s.discard,1)
end)
test('failed hand-choice resume restores the current phase without replaying block or draw',function()
 local AI=require('abyss_enemy_ai')
 for _,id in ipairs({'true_grit','warcry'}) do
  local s,using
  if id=='true_grit' then
   s=battle({inst(id,true),'strike','defend'});using=uid(s,id)
  else
   for seed=1,16 do
    local candidate=C.new(data,{seed=seed,deck={'warcry','strike','defend','bash','strike','defend','strike','defend'},enemies={'cultist'}})
    for _,c in ipairs(candidate.hand) do if c.cardId==id then s,using=candidate,c.uid;break end end
    if s then break end
   end
   assert(s);s.cardRandomRng=R.fromSeed('42')
  end
  assert(C.play(s,using));assert(s.pendingHandChoice)
  local pending,context,q,usingCard=s.pendingHandChoice,s.pendingPlay,s.actionQueue,s.cardInUse
  local actions,current=q.actions,q.current
  local hand,draw,discard,exhaust=s.hand,s.draw,s.discard,s.exhaust
  local handCount,drawCount,events,energy,block=#hand,#draw,#s.events,s.energy,s.player.block
  local selected=hand[1].uid;local first=hand[1]
  local rng,primitive=s.cardRandomRng,s.cardRandomRng.primitive;local snapshot=R.snapshot(rng)
  local original=AI.afterCard
  AI.afterCard=function(state,reactions)
   original(state,reactions)
   if state==s then
    R.randomInt(state.cardRandomRng,9);state.player.block=91;state.energy=0
    state.cardInUse.resumeFault=true
    error('warrior resume fault')
   end
  end
  local ok,reason=pcall(C.chooseHand,s,{selected},pending.token)
  AI.afterCard=original
  eq(ok,false);assert(tostring(reason):find('warrior resume fault',1,true))
  eq(s.pendingHandChoice,pending);eq(s.pendingPlay,context);eq(s.actionQueue,q)
  eq(q.actions,actions);eq(q.current,current);eq(q.paused,true);eq(s.cardInUse,usingCard)
  eq(usingCard.resumeFault,nil);eq(s.hand,hand);eq(s.hand[1],first);eq(#hand,handCount)
  eq(s.draw,draw);eq(#draw,drawCount);eq(s.discard,discard);eq(s.exhaust,exhaust)
  eq(#discard,0);eq(#exhaust,0);eq(s.energy,energy);eq(s.player.block,block);eq(#s.events,events)
  eq(s.cardRandomRng,rng);eq(rng.primitive,primitive)
  local restored=R.snapshot(rng);eq(restored.counter,snapshot.counter)
  for k,v in pairs(snapshot.words) do eq(restored.words[k],v) end
  assert(C.chooseHand(s,{selected},pending.token))
  eq(s.pendingHandChoice,nil);eq(s.pendingPlay,nil);eq(s.actionQueue,nil);eq(s.cardInUse,nil)
  eq(s.energy,energy);eq(s.player.block,block);eq(#s.hand,handCount-1)
  if id=='true_grit' then eq(s.player.block,9);eq(s.exhaust[1].uid,selected);eq(s.discard[1].uid,using)
  else eq(#s.draw,drawCount+1);eq(s.draw[#s.draw].uid,selected);eq(s.exhaust[1].uid,using) end
 end
end)
for _,id in ipairs({'whirlwind','reaper'}) do
 test(id..' lethal Sharp Hide leaves the original card in use without disposal',function()
  for _,up in ipairs({false,true}) do
   local s=battle({inst(id,up)},{'guardian'})
   s.player.hp=2
   local enemy=s.enemies[1]
   enemy.hp=100;enemy.block=0;enemy.statuses.sharp_hide=3
   local usingCard=s.hand[1];local usingUid=usingCard.uid
   assert(C.play(s,usingUid))
   eq(s.player.hp,0);eq(s.phase,'defeat')
   eq(s.cardInUse,usingCard);eq(s.cardInUse.uid,usingUid)
   eq(#s.hand,0);eq(#s.discard,0);eq(#s.exhaust,0)
   eq(s.pendingPlay,nil);eq(s.actionQueue,nil)
   -- Whirlwind's deferred attacks never start; Reaper's native attack has
   -- already resolved, but its queued healing cannot undo lethal retaliation.
   eq(enemy.hp,id=='whirlwind' and 100 or (up and 95 or 96))
   eq(s.energy,id=='whirlwind' and 0 or 1)
   local reactions=0
   for _,e in ipairs(s.events) do
    if e.kind=='status_damage' and e.detail.status=='sharp_hide' then reactions=reactions+1 end
    assert(e.kind~='heal','death must stop deferred Reaper healing')
   end
   eq(reactions,1)
  end
 end)
end
print('WARRIOR_CARDS_PASS '..n)
