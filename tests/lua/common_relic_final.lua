package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H,C,I,R,A,U,N,Map,S=require('abyss_relic_hooks'),require('abyss_combat'),require('abyss_inventory'),require('abyss_run'),require('abyss_actor'),require('abyss_unknown'),require('abyss_nodes'),require('abyss_map'),require('abyss_sts_random')
local data=require('abyss_data')
local Q=require('abyss_card_actions')
local count=0
local function test(name,f)f();count=count+1;print('PASS '..name)end
local function battle(ids,hp,context,advanced)
 local q=assert(I.opening(data.relics.relics,ids,nil,context))
 local s=assert(C.new(data,{seed=42,hp=hp or 80,deck={'strike','defend','defend','defend','defend','defend','defend','defend','defend','defend'},enemies={'cultist'},enableStances=advanced,
 beforeOpeningDraw=function(s)return I.applyOpening(s,q.beforeDraw)end}));assert(I.applyOpening(s,q.afterDraw));return s
end
local function withHooks(hooks,fn)
 local saved={}
 for i,h in ipairs(hooks)do saved[i]=h[1][h[2]];h[1][h[2]]=h[3](saved[i])end
 local ok,why=pcall(fn)
 for i,h in ipairs(hooks)do h[1][h[2]]=saved[i]end
 assert(ok,why)
end
local function puzzleAction(s)
 local actions=s.actionQueue and s.actionQueue.actions or s.cardActions
 assert(actions and actions[1].effect.op=='draw' and actions[1].effect.value==3,'Puzzle must enqueue TOP draw 3')
 return actions
end
local function lose(s)C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player)end
test('PreservedInsect sets only elite current HP to floor 75 percent and preserves max HP',function()
 local normal=battle({'preserved_insect'},80,{tier='normal'})
 local elite=battle({'preserved_insect'},80,{tier='elite'})
 assert(elite.enemies[1].maxHp==normal.enemies[1].maxHp)
 assert(elite.enemies[1].hp==math.floor(S.float32(normal.enemies[1].maxHp*.75)))
end)
test('RedSkull starts at half HP, adds three Strength and removes it after healing above half',function()
 local s=battle({'red_skull'},40);assert(s.player.statuses.strength==3)
 local before=s.player.hp;s.player.hp=41;H.hpChanged(s,s.player,before);assert(s.player.statuses.strength==0)
 before=s.player.hp;C.applyEffects(s,{{op='loseHp',value=1}},s.player,s.player);assert(s.player.hp==40 and s.player.statuses.strength==3)
end)
-- Pinned aeubanks/sts@319009d5: CentennialPuzzle.wasHPLost adds draw 3
-- to TOP once. Actor callbacks enqueue only; the outer Combat owner settles.
-- A pre-existing real BOTTOM action makes the queued boundary observable.
test('CentennialPuzzle first positive HP loss queues TOP draw once including self-loss and thorns',function()
 for _,kind in ipairs({'self','thorns','attack'})do
  local s=battle({'centennial_puzzle'});local n,d,energy=#s.hand,#s.draw,s.energy
  Q.enqueue(s,{op='energy',value=1})
  if kind=='self'then lose(s)
  elseif kind=='thorns'then C.addStatus(s.enemies[1],'thorns',1);C.damage(s,s.player,s.enemies[1],1)
  else A.damage(s,s.enemies[1],s.player,1)end
  assert(s.player.hp==79 and #s.hand==n and s.relicCombat.centennialUsed)
  local actions=puzzleAction(s);assert(#actions==2 and actions[2].effect.op=='energy')
  lose(s);assert(#s.hand==n and #s.cardActions==2 and s.cardActions[1]==actions[1])
  local draws=0
  withHooks({{C,'draw',function(old)return function(state,amount)
   if state==s then draws=draws+1;assert(amount==3 and state.energy==energy,'TOP draw must precede BOTTOM energy')end
   return old(state,amount)
  end end}},function()Q.drain(C,s);Q.drain(C,s)end)
  assert(draws==1 and #s.hand==n+3 and #s.draw==d-3 and s.energy==energy+1)
  assert(s.cardActions==nil and s.actionQueue==nil)
  lose(s);assert(#s.hand==n+3 and s.cardActions==nil,'later HP loss must not draw twice')
 end
end)
test('Puzzle ignores fully blocked attacks and lethal loss does not draw after death',function()
 local s=battle({'centennial_puzzle'});local n,d=#s.hand,#s.draw;s.player.block=10
 A.damage(s,s.enemies[1],s.player,5)
 assert(s.player.hp==80 and #s.hand==n and s.cardActions==nil and not s.relicCombat.centennialUsed)
 C.applyEffects(s,{{op='loseHp',value=80}},s.player,s.player);Q.drain(C,s)
 assert(s.player.hp==0 and #s.hand==n and #s.draw==d and s.cardActions==nil)
 for _,ending in ipairs({'defeat','victory'})do
  local queued=battle({'centennial_puzzle'});n,d=#queued.hand,#queued.draw;local energy=queued.energy
  Q.enqueue(queued,{op='energy',value=1});lose(queued);assert(#puzzleAction(queued)==2)
  if ending=='defeat'then C.applyEffects(queued,{{op='loseHp',value=80}},queued.player,queued.player)
  else queued.enemies[1].hp=0 end
  assert(C.outcome(queued)==ending);Q.drain(C,queued)
  assert(#queued.hand==n and #queued.draw==d and queued.cardActions==nil,'queued draw must not survive combat end')
  assert(queued.energy==energy,'terminal queue must not grant later energy')
 end
 local ended=battle({'centennial_puzzle'});ended.enemies[1].hp=0;n=#ended.hand
 local before=ended.player.hp;ended.player.hp=before-1;H.hpChanged(ended,ended.player,before)
 assert(#ended.hand==n and ended.cardActions==nil)
end)
test('RedSkull updates on actual normal damage and regeneration healing; Artifact may block negative Strength',function()
 local s=battle({'red_skull'},41);A.damage(s,s.enemies[1],s.player,1);assert(s.player.statuses.strength==3)
 C.addStatus(s.player,'regen',2);A.endTurn(s,s.player);assert(s.player.hp==42 and s.player.statuses.strength==0)
 s.player.hp=40;H.hpChanged(s,s.player,42);C.addStatus(s.player,'artifact',1)
 s.player.hp=41;H.hpChanged(s,s.player,40);assert(s.player.statuses.strength==3 and s.player.statuses.artifact==0)
end)
test('TinyChest equipment resets its actual unknown-room counter',function()
 local r=R.new(data,42);r.relics={'tiny_chest'};r.unknown.chances.tinyChestCount=3
 H.onEquip(r,'tiny_chest');assert(r.unknown.chances.tinyChestCount==0)
end)
test('Juzu and fourth TinyChest use existing formal Nodes unknown-room ownership adapters',function()
 for _,kind in ipairs({'juzu_bracelet','tiny_chest'})do
  local d=C.copy(data);d.rules.events.encounterId=nil
  local r,m=R.new(d,42),Map.generate(d,42);r.relics[#r.relics+1]=kind
  r.unknown.chances.tinyChestCount=3
  local target
  for _=1,15 do
   local options=Map.available(m)
   for _,node in ipairs(options)do if node.type=='event' then target=node;break end end
   if target then break end
   assert(options[1]);assert(Map.choose(m,options[1].id))
  end
  assert(target);local old=S.randomFloat
  S.randomFloat=function(rng)old(rng);return 0 end
  local called,ok,why=pcall(N.enter,r,m,target.id);S.randomFloat=old
  assert(called and ok,tostring(why))
  assert(r.nodeFlow.type==(kind=='tiny_chest' and 'treasure' or 'event'))
 end
end)
test('DreamCatcher rest hook requests the ordinary card reward once and refuses missing production adapter',function()
 local r={relics={'dream_catcher'}};local n=0
 local result=H.onRest(r,function(owner)assert(owner==r);n=n+1;return {'card1','card2','card3'}end)
 assert(n==1 and #result==3)
 assert(not pcall(H.onRest,r));r.relics={};assert(H.onRest(r)==nil)
end)
test('Standalone HP-loss and thorns owners settle once only after the HP callback returns',function()
 for _,kind in ipairs({'self','thorns'})do
  local s=battle({'centennial_puzzle'});local n,d=#s.hand,#s.draw;local trace={}
  withHooks({{H,'hpChanged',function(old)return function(state,actor,before)
   old(state,actor,before)
   if state==s and actor==s.player and before>actor.hp then
    assert(#s.hand==n,'HP callback must not draw synchronously')
    assert(#puzzleAction(s)==1);trace[#trace+1]='hp'
   end
  end end},{C,'draw',function(old)return function(state,amount)
   if state==s then
    assert(state.drainingCardActions and trace[1]=='hp','outer owner must settle after the HP callback')
    assert(amount==3);trace[#trace+1]='draw'
   end
   return old(state,amount)
  end end}},function()
   if kind=='self'then lose(s)
   else C.addStatus(s.enemies[1],'thorns',1);C.damage(s,s.player,s.enemies[1],1)end
  end)
  assert(table.concat(trace,',')=='hp,draw' and #s.hand==n+3 and #s.draw==d-3)
  assert(s.cardActions==nil and s.actionQueue==nil and s.relicCombat.centennialUsed)
  Q.drain(C,s);lose(s);assert(#s.hand==n+3 and #s.draw==d-3 and s.cardActions==nil)
 end
end)
test('Real Bloodletting with Rupture keeps Puzzle TOP in both native and shared action queues',function()
 for _,advanced in ipairs({false,true})do
  local s=battle({'centennial_puzzle'},nil,nil,advanced)
  -- Rupture already selects individual HP-loss actions in both real owners.
  -- Ordinary effectBatch card-boundary parity is tracked separately.
  A.applyPower(s,s.player,'rupture',1,s.player)
  local card={cardId='bloodletting',uid=s.nextUid,upgraded=false};s.nextUid=s.nextUid+1;s.hand={card}
  local d,energy=#s.draw,s.energy;local trace={}
  withHooks({{H,'hpChanged',function(old)return function(state,actor,before)
   old(state,actor,before)
   if state==s and actor==s.player and before>actor.hp then
    assert(#s.hand==0,'Puzzle cannot draw during Bloodletting HP loss')
    assert((s.actionQueue~=nil)==advanced,'must use the actual current card owner')
    local actions=puzzleAction(s)
    local energyTail=false
    for i=2,#actions do if actions[i].effect and actions[i].effect.op=='energy' and actions[i].effect.value==2 then energyTail=true end end
    assert(energyTail,'source GainEnergy action must remain behind TOP draw')
    assert(advanced and s.cardActions==nil or not advanced and s.actionQueue==nil)
    trace[#trace+1]='hp'
   end
  end end},{C,'draw',function(old)return function(state,amount)
   if state==s then assert(amount==3 and s.energy==energy,'Puzzle draw must run before Bloodletting energy');trace[#trace+1]='draw'end
   return old(state,amount)
  end end}},function()assert(C.play(s,card.uid,1))end)
  assert(table.concat(trace,',')=='hp,draw' and s.player.hp==77 and s.energy==energy+2)
  assert(#s.hand==3 and #s.draw==d-3 and s.discard[1]==card)
  assert(s.cardActions==nil and s.actionQueue==nil and s.pendingPlay==nil and s.cardInUse==nil)
  lose(s);Q.drain(C,s);assert(#s.hand==3 and #s.draw==d-3,'neither queue may redeliver Puzzle')
 end
end)
test('Puzzle consumes its one trigger even with no cards, No Draw or a full hand',function()
 -- DrawCardAction.update guards empty piles/No Draw/full hand before a
 -- shuffle or movement; restoring resources later cannot retrigger Puzzle.
 for _,kind in ipairs({'empty','no_draw','full','one_slot'})do
  local s=battle({'centennial_puzzle'});s.shuffleRng=S.fromSeed('42')
  if kind=='empty'then s.draw={};s.discard={}
  elseif kind=='no_draw'then s.player.noDraw=true
  else
   while #s.hand<(kind=='full' and 10 or 9)do
    s.hand[#s.hand+1]={cardId='defend',uid=s.nextUid};s.nextUid=s.nextUid+1
   end
  end
  local n,d,discard,counter=#s.hand,#s.draw,#s.discard,s.shuffleRng.counter
  lose(s)
  local drawn=kind=='one_slot' and 1 or 0
  assert(#s.hand==n+drawn and #s.draw==d-drawn and #s.discard==discard)
  assert(s.shuffleRng.counter==counter and s.relicCombat.centennialUsed and s.cardActions==nil)
  s.player.noDraw=false;s.hand={};s.draw={{cardId='defend',uid=s.nextUid}};s.nextUid=s.nextUid+1
  lose(s);Q.drain(C,s);assert(#s.hand==0 and #s.draw==1 and s.cardActions==nil)
 end
end)
print('LUA_COMMON_RELIC_FINAL_PASS '..count)
