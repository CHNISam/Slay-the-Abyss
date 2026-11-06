-- Complete unchanged original fixture bodies; selection is injected only at
-- the test(name, fn) dispatcher. JS verifies every complete LF source hash.
return {
fatal={path='tests/lua/fatal_hp_loss_callbacks.lua',sha256='a22380ec83214ee7a3780ef91b6663d8d38751c76ba625f67257428305ebab19',source=[====[-- Independent source oracle, not the former known-gap characterization.
-- aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0:
-- AbstractPlayer.damage:1420-1474, RupturePower.wasHPLost:31-35,
-- CentennialPuzzle.wasHPLost:35-41, FairyPotion.use:32-39;
-- Bloodletting.use:25-27 / Hemokinesis.use:31-36. Community decompile,
-- not certified original-PC execution. Exact lethal costs avoid overkill claims.
-- Power then relic TOP insertion precedes Fairy; execution is Draw3, Strength2,
-- captured card tail, disposal. Bloom consumes Puzzle's trigger but executes none.
-- DeathScreen suspends the original manager; this test DOES NOT certify host
-- death queue retention equivalence or change its existing terminal policy.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,H,Q,AQ,D,F,R=require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks'),
 require('abyss_card_actions'),require('abyss_action_queue'),require('abyss_data'),
 require('abyss_potion_fairy'),require('abyss_sts_random')
local I=require('abyss_inventory')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or'FAIL ')..name..(ok and ''or': '..tostring(why)))
end
local function hooks(specs,fn)
 local saved={};for i,h in ipairs(specs)do saved[i]=h[1][h[2]];h[1][h[2]]=h[3](saved[i])end
 local ok,why=pcall(fn);for i,h in ipairs(specs)do h[1][h[2]]=saved[i]end;assert(ok,why)
end
local function unchanged(root)
 local saved={};local function visit(t)
  if type(t)~='table'or saved[t]then return end
  local values={};saved[t]=values;for k,v in pairs(t)do values[k]=v;visit(k);visit(v)end
 end;visit(root)
 return function()for t,values in pairs(saved)do
  for k,v in pairs(values)do eq(t[k],v,'original key '..tostring(k))end
  for k,v in pairs(t)do eq(v,values[k],'extra key '..tostring(k))end
 end end
end
local function card(s,id)
 local c={cardId=id,uid=s.nextUid,upgraded=false};s.nextUid=s.nextUid+1;return c
end
local function battle(mode,id,bloom)
 local s=C.new(D,{seed=42,deck={},enemies={'cultist'},enableStances=mode=='shared',
  orbSlots=mode=='orb'and 0 or nil,orbRandomSeed=mode=='orb'and '42'or nil})
 H.bindBattle(s,bloom and {'centennial_puzzle','mark_of_bloom'}or {'centennial_puzzle'})
 A.applyPower(s,s.player,'rupture',2,s.player)
 local c=card(s,id or 'bloodletting');s.hand={c};s.draw={};s.discard={}
 for _=1,6 do s.draw[#s.draw+1]=card(s,'defend')end
 s.player.hp=id=='hemokinesis'and 2 or 3;s.player.maxHp=80
 s.enemies[1].hp=200;s.enemies[1].maxHp=200
 s.potionInventory={[1]='fairy_in_a_bottle',[3]='dexterity'};s.potionCapacity=3
 return s,c
end
local function clear(s)
 eq(s.cardActions,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil);eq(s.pendingChoice,nil)
 eq(s.drainingCardActions,nil);eq(s.resolvingCard,nil)
end
local function queue(s,mode)
 if mode=='native'then eq(s.actionQueue,nil);return s.cardActions end
 eq(s.cardActions,nil);return s.actionQueue and s.actionQueue.actions
end
local function eventCount(s,kind)
 local n=0;for _,e in ipairs(s.events)do if e.kind==kind then n=n+1 end end;return n
end
for _,mode in ipairs({'native','shared','orb'})do
 for _,id in ipairs({'bloodletting','hemokinesis'})do
  for _,bloom in ipairs({false,true})do
   test(mode..' '..id..(bloom and ' Bloom' or ' Fairy')..' source oracle',function()
    local s,c=battle(mode,id,bloom);local inventory=s.potionInventory;local trace={}
    local beforeFairy,planned,drawStrength,tailStrength
    hooks({{Q,'enqueueReaction',function(old)return function(state,e,top)
     if state==s then
      eq(top,true);trace[#trace+1]=e.op=='draw'and 'planDraw'or 'planStrength'
     end;return old(state,e,top)
    end end},{F,'fatal',function(old)return function(state)
     if state==s then
      trace[#trace+1]='fairy';beforeFairy=s.relicCombat.centennialUsed
      local q=queue(s,mode);planned=q and q[1].effect.op..','..q[2].effect.op
     end;return old(state)
    end end},{C,'draw',function(old)return function(state,n)
     if state==s then
      eq(n,3);eq(s.cardInUse,c);eq(#s.discard,0);eq(s.energy,id=='bloodletting'and 3 or 2)
      drawStrength=s.player.statuses.strength or 0;trace[#trace+1]='draw'
     end;return old(state,n)
    end end},{A,'applyPower',function(old)return function(state,target,status,n,source,...)
     if state==s and status=='strength'then
      eq(n,2);eq(target,s.player);eq(source,s.player);eq(#s.hand,3);eq(s.cardInUse,c)
      trace[#trace+1]='strength'
     end;return old(state,target,status,n,source,...)
    end end},{C,'applyEffects',function(old)return function(state,effects,...)
     if state==s and (effects[1].op=='energy'or effects[1].op=='damage')then
      eq(#effects,1);eq(s.cardInUse,c);eq(#s.discard,0)
      tailStrength=s.player.statuses.strength;trace[#trace+1]='tail'
     end;return old(state,effects,...)
    end end}},function()assert(C.play(s,c.uid,1))end)
    eq(s.player.hp,bloom and 0 or 24);eq(s.potionInventory,inventory,'physical inventory owner')
    eq(inventory[1],bloom and 'fairy_in_a_bottle'or nil);eq(inventory[2],nil);eq(inventory[3],'dexterity')
    eq(s.relicCombat.centennialUsed,true,'Puzzle consumed by actual lethal loss')
    eq(beforeFairy,true,'relic callback precedes Fairy');eq(planned,'draw,gainStatus')
    eq(s.player.damagedThisCombat,1);eq(eventCount(s,'hp_loss'),1)
    eq(eventCount(s,'potion_revive'),bloom and 0 or 1)
    eq(s.enemies[1].hp,not bloom and id=='hemokinesis'and 185 or 200,'captured damage excludes new Strength')
    eq(s.energy,bloom and (id=='bloodletting'and 3 or 2)or (id=='bloodletting'and 5 or 2))
    eq(s.player.statuses.strength or 0,bloom and 0 or 2);eq(#s.hand,bloom and 0 or 3);eq(#s.draw,bloom and 6 or 3)
    eq(#s.discard,bloom and 0 or 1);eq(s.cardInUse,bloom and c or nil)
    if bloom then eq(s.phase,'defeat');eq(drawStrength,nil);eq(tailStrength,nil)
    else eq(s.discard[1],c);eq(drawStrength,0);eq(tailStrength,2)end
    eq(table.concat(trace,','),'planStrength,planDraw,fairy'..(bloom and ''or ',draw,strength,tail'))
    clear(s);local check=unchanged(s);Q.drain(C,s);Q.drain(C,s);check()
   end)
  end
 end
 for _,kind in ipairs({'null','enemy'})do
  test(mode..' '..kind..' owner lethal revival fires Puzzle but not Rupture',function()
   local s=battle(mode);s.player.hp=2;local inserted={}
   if mode~='native'then AQ.start(s,{})end
   hooks({{Q,'enqueueReaction',function(old)return function(state,e,top)
    if state==s then eq(top,true);inserted[#inserted+1]=e.op end;return old(state,e,top)
   end end}},function()
    if kind=='null'then s.player.statuses.poison=2;A.startTurnEffects(s,s.player)
    else A.damage(s,s.enemies[1],s.player,2,true)end
   end)
   eq(s.player.hp,24);eq(s.potionInventory[1],nil);eq(s.relicCombat.centennialUsed,true)
   eq(table.concat(inserted,','),'draw');eq(s.player.damagedThisCombat,1);eq(s.player.statuses.strength,nil)
   if mode=='native'then Q.drain(C,s)else AQ.run(s,{
    effect=function(state,item)C.applyEffects(state,{item.effect},state.player);return true end})end
   eq(#s.hand,4);eq(#s.draw,3);eq(s.player.statuses.strength,nil);clear(s)
  end)
 end
 test(mode..' Fairy loss discounts actual Blood for Blood cost exactly once',function()
  local s,c=battle(mode);local b=card(s,'blood_for_blood');s.hand[#s.hand+1]=b
  assert(C.play(s,c.uid,1));eq(s.player.damagedThisCombat,1)
  eq(b.costReduction,1);eq(b.combatCost,3);eq(b.turnCost,3);eq(C.cardDefinition(s,b).cost,3)
  eq(s.relicCombat.centennialUsed,true);eq(#s.hand,4);clear(s)
 end)
 test(mode..' heal-only hooks update Red Skull without consuming Puzzle',function()
  local s=battle(mode);H.bindBattle(s,{'centennial_puzzle','red_skull'});s.player.hp=20
  H.battleStart(s,'red_skull');eq(s.player.statuses.strength,3)
  local notified=0
  hooks({{H,'wasHpLost',function(old)return function(...)
   notified=notified+1;return old(...)
  end end}},function()
   if mode=='native'then Q.enqueue(s,{op='heal',value=30});Q.drain(C,s)
   else AQ.start(s,{{kind='effect',effect={op='heal',value=30}}});AQ.run(s,{
    effect=function(state,item)C.applyEffects(state,{item.effect},state.player);return true end})end
   eq(s.player.hp,50);eq(s.player.statuses.strength,0);eq(s.relicCombat.redSkullActive,false)
   assert(I.apply(s,{{op='increaseMaxHp',value=4}}));eq(s.player.hp,54);eq(s.player.maxHp,84)
   H.battleStart(s,'blood_vial');eq(s.player.hp,56)
   A.addStatus(s.player,'regen',2);A.endTurn(s,s.player);eq(s.player.hp,58)
  end)
  eq(notified,0);eq(s.relicCombat.centennialUsed,nil);eq(s.player.damagedThisCombat,nil)
  eq(s.potionInventory[1],'fairy_in_a_bottle');eq(eventCount(s,'hp_loss'),0);clear(s)
 end)
 for _,stage in ipairs({'fairy','draw'})do
  test(mode..' rollback after real '..stage..' then successful real retry',function()
   local s,c=battle(mode);s.shuffleRng=R.fromSeed('42');s.discard=s.draw;s.draw={}
   local oldNative,oldShared=s.cardActions,s.actionQueue
   local check=unchanged(s);local marker={stage=stage};local injected=false
   local function fail()
    eq(s.player.hp,24);eq(s.potionInventory[1],nil);eq(s.relicCombat.centennialUsed,true)
    assert(queue(s,mode),'existing owner must hold pending reactions/tail')
    injected=true;error(marker)
   end
   hooks({{F,'fatal',function(old)return function(state)
    local result=old(state);if state==s and stage=='fairy'then eq(result,true);fail()end;return result
   end end},{C,'draw',function(old)return function(state,...)
    local result=old(state,...);if state==s and stage=='draw'then
     eq(#s.hand,3);eq(s.shuffleRng.counter,1,'real reshuffle consumed its stream');fail()
    end;return result
   end end}},function()
    local ok,why=pcall(C.play,s,c.uid,1);eq(injected,true);eq(ok,false);eq(why,marker,'original error identity')
    check();eq(s.cardActions,oldNative);eq(s.actionQueue,oldShared)
   end)
   assert(C.play(s,c.uid,1));eq(s.player.hp,24);eq(s.potionInventory[1],nil)
   eq(s.relicCombat.centennialUsed,true);eq(s.player.damagedThisCombat,1);eq(s.player.statuses.strength,2)
   eq(s.shuffleRng.counter,1);eq(#s.hand,3);eq(s.energy,5);eq(s.cardInUse,nil);eq(s.discard[1],c);clear(s)
  end)
 end
end
-- The legacy Guardian disposal callback has no hpChanged call of its own.
-- Exercise its existing actual-loss notifier, without certifying its full queue order.
test('real Guardian Sharp Hide public play consumes Puzzle once, never Rupture',function()
 local s=C.new(D,{seed=42,deck={},enemies={'guardian'}})
 C.damage(s,s.player,s.enemies[1],30,true);assert(C.endTurn(s))
 eq(s.enemies[1].statuses.sharp_hide,3);eq(s.player.hp,80)
 H.bindBattle(s,{'centennial_puzzle'});A.applyPower(s,s.player,'rupture',2,s.player)
 local c=card(s,'strike');s.hand={c};s.draw={};s.discard={}
 for _=1,6 do s.draw[#s.draw+1]=card(s,'defend')end
 local draws=0
 hooks({{C,'draw',function(old)return function(state,n)
  if state==s then draws=draws+1;eq(n,3)end;return old(state,n)
 end end}},function()assert(C.play(s,c.uid,1))end)
 eq(s.player.hp,77);eq(s.player.damagedThisCombat,1);eq(s.relicCombat.centennialUsed,true)
 eq(s.player.statuses.strength,nil);eq(draws,1);eq(#s.hand,3);eq(#s.draw,3)
 eq(s.discard[1],c);eq(s.cardInUse,nil);clear(s)
end)
print('FATAL_HP_LOSS_CALLBACKS '..count..' passed='..(count-failed)..' failed='..failed)
assert(failed==0,'fatal HP-loss source oracle failed')
]====]},
turns={path='tests/lua/common_relic_turns.lua',sha256='529069476443ec8916fcbbb12558499a4c7870b84aab25666e015c05c31b054c',source=[====[package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local H,C,I,S=require('abyss_relic_hooks'),require('abyss_combat'),require('abyss_inventory'),require('abyss_sts_random')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function battle(ids,counters)
 local opening=assert(I.opening(data.relics.relics,ids,counters))
 local s=assert(C.new(data,{seed=42,deck={'strike','defend','defend','defend','defend','defend','defend'},enemies={'cultist'},
  beforeOpeningDraw=function(s)return I.applyOpening(s,opening.beforeDraw)end}))
 assert(I.applyOpening(s,opening.afterDraw));return s
end
test('HappyFlower grants one energy on every third player turn and persists its counter',function()
 local s=battle({'happy_flower'},{happy_flower=0});assert(s.energy==3 and s.relicCounters.happy_flower==1)
 assert(C.endTurn(s));assert(s.energy==3 and s.relicCounters.happy_flower==2)
 assert(C.endTurn(s));assert(s.energy==4 and s.relicCounters.happy_flower==0)
 local nextBattle=battle({'happy_flower'},{happy_flower=2});assert(nextBattle.energy==4 and nextBattle.relicCounters.happy_flower==0)
end)
test('HappyFlower original legacy minus-one counter advances to one',function()
 local s=battle({'happy_flower'},{happy_flower=-1});assert(s.energy==3 and s.relicCounters.happy_flower==1)
end)
test('AncientTeaSet arms entering camp regardless selected action then grants two on next battle first turn only',function()
 local r={relics={'ancient_tea_set'},relicCounters={ancient_tea_set=-1},gold=0,hp=40,maxHp=80}
 H.onEnterRoom(r,'camp');assert(r.relicCounters.ancient_tea_set==-2)
 local s=battle(r.relics,r.relicCounters);assert(s.energy==5 and s.relicCounters.ancient_tea_set==-1)
 assert(r.relicCounters.ancient_tea_set==-2,'uncommitted battle escaped into run counter')
 assert(C.endTurn(s));assert(s.energy==3)
 local nextBattle=battle(r.relics,s.relicCounters);assert(nextBattle.energy==3)
end)
test('ArtOfWar skips first-turn bonus and tracks attacks even after they leave hand',function()
 local s=battle({'art_of_war'});assert(s.energy==3)
 assert(C.endTurn(s));assert(s.energy==4)
 local uid
 for _,card in ipairs(s.hand)do if card.cardId=='strike' then uid=card.uid end end
 if not uid then C.draw(s,10);for _,card in ipairs(s.hand)do if card.cardId=='strike'then uid=card.uid end end end
 assert(uid);assert(C.play(s,uid,1));assert(C.endTurn(s));assert(s.energy==3)
 assert(C.endTurn(s));assert(s.energy==4)
end)
test('a failed attack restores ArtOfWar eligibility and retained counter objects',function()
 local s=battle({'art_of_war'});local uid
 for _,card in ipairs(s.hand)do if card.cardId=='strike'then uid=card.uid end end
 if not uid then C.draw(s,10);for _,card in ipairs(s.hand)do if card.cardId=='strike'then uid=card.uid end end end
 local original=s.relicCombat;local damage=C.damage
 C.damage=function()error('POST_ATTACK_HOOK_FAILURE')end
 local ok=pcall(C.play,s,uid,1);C.damage=damage
 assert(not ok);assert(s.relicCombat==original and not original.attackPlayed)
end)
print('LUA_COMMON_RELIC_TURNS_PASS '..n)
]====]},
attacks={path='tests/lua/common_relic_attacks.lua',sha256='a85ff909c7b4c6115a5132e772400ba79f0e8fabfa7e5b0846d1fd8050d0a676',source=[====[package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,I=require('abyss_combat'),require('abyss_inventory')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function battle(ids,counters,deck,enemies)
 local q=assert(I.opening(data.relics.relics,ids,counters))
 local s=assert(C.new(data,{seed=42,deck=deck or {'strike','strike','defend'},enemies=enemies or {'cultist'},
 beforeOpeningDraw=function(s)return I.applyOpening(s,q.beforeDraw)end}))
 assert(I.applyOpening(s,q.afterDraw))
 for _,e in ipairs(s.enemies)do e.hp=300;e.maxHp=300 end
 return s
end
local function play(s,id,target)
 for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid,target or 1));return end end;error('missing '..id)
end
test('Boot raises post-block NORMAL player damage from one through four to five only',function()
 local s=battle({'boot'});local e=s.enemies[1];e.block=5;play(s,'strike');assert(e.hp==295 and e.block==0)
 e.block=6;play(s,'strike');assert(e.hp==295 and e.block==0)
 C.damage(s,s.player,e,1,true);assert(e.hp==294,'fixed potion damage incorrectly raised')
end)
test('Akabeko vigor applies eight to each hit of first attack, consumed only by attacks',function()
 local s=battle({'akabeko'},nil,{'defend','twin_strike','strike'});local e=s.enemies[1]
 play(s,'defend');assert(s.player.statuses.vigor==8)
 play(s,'twin_strike');assert(e.hp==274 and (s.player.statuses.vigor or 0)==0)
 s.energy=3;play(s,'strike');assert(e.hp==268)
end)
test('PenNib doubles tenth attack and preserves source priority with Vigor Weak and Vulnerable',function()
 local s=battle({'akabeko','pen_nib'},{pen_nib=9});local e=s.enemies[1]
 C.addStatus(s.player,'strength',1);C.addStatus(s.player,'weak',1);C.addStatus(e,'vulnerable',1)
 assert(C.attackAmount(s,s.player,e,6)==33)
 play(s,'strike');assert(e.hp==267 and s.relicCounters.pen_nib==0)
 assert((s.player.statuses.pen_nib or 0)==0 and (s.player.statuses.vigor or 0)==0)
end)
test('ninth attack enables PenNib for next card instead of doubling itself',function()
 local s=battle({'pen_nib'},{pen_nib=8});local e=s.enemies[1]
 play(s,'strike');assert(e.hp==294 and s.player.statuses.pen_nib==1)
 play(s,'strike');assert(e.hp==282 and s.relicCounters.pen_nib==0 and s.player.statuses.pen_nib==0)
end)
test('Nunchaku tenth attack grants one energy after resolution; counter persists and skills do not count',function()
 local s=battle({'nunchaku'},{nunchaku=9});play(s,'defend');assert(s.relicCounters.nunchaku==9)
 local before=s.energy;play(s,'strike');assert(s.energy==before and s.relicCounters.nunchaku==0)
end)
test('failed attack restores counts powers and temporary attack hook state',function()
 local s=battle({'pen_nib','nunchaku','akabeko'},{pen_nib=9,nunchaku=9});local old=C.damage
 C.damage=function()error('AFTER_RELIC_COUNTERS')end
 local uid=s.hand[1].uid;local ok=pcall(C.play,s,uid,1);C.damage=old
 assert(not ok and s.relicCounters.pen_nib==9 and s.relicCounters.nunchaku==9)
 assert(s.player.statuses.vigor==8 and s.player.statuses.pen_nib==1)
end)
print('LUA_COMMON_RELIC_ATTACKS_PASS '..n)
]====]},
uncommon={path='tests/lua/uncommon_relics_lifecycle.lua',sha256='e3d6b985af2ed633a99b5cc3ef4cd90b8e2241d48c4f8b45653809e0160e4786',source=[====[package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,U=require('abyss_run'),require('abyss_combat'),require('abyss_uncommon_relics')
local Data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function begin(ids,deck)
 local r=Run.new(Data,42)
 for _,id in ipairs(ids)do assert(Run.obtainRelic(r,id),'cannot obtain '..id)end
 if deck then r.deck={};for i,id in ipairs(deck)do r.deck[i]={uid=i,cardId=id,upgraded=false}end;r.nextDeckUid=#deck+1 end
 assert(Run.startCombat(r,'cultist_solo'));return r,r.combat
end
local function find(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 C.draw(s,10)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error('missing '..id)
end
test('normal obtain activates three attack relics in real plays and resets next turn',function()
 local r,s=begin({'Kunai','Shuriken','Ornamental Fan'},{'strike','strike','strike','defend','defend','defend','defend'})
 s.enemies[1].hp=200;s.enemies[1].maxHp=200
 for i=1,3 do local c=find(s,'strike');assert(Run.play(r,c.uid,1))end
 assert(s.player.statuses.strength==1 and s.player.statuses.dexterity==1 and s.player.block==4)
 assert(Run.endTurn(r));assert(s.relicCounters.kunai==0 and s.relicCounters.shuriken==0)
end)
test('normal obtain enables Blue Candle playable exact curse exhausted and HP lost',function()
 local r,s=begin({'Blue Candle'},{'injury','defend','defend','defend','defend','defend'})
 local c=find(s,'injury');local hp=s.player.hp;local energy=s.energy
 assert(Run.play(r,c.uid));assert(s.player.hp==hp-1 and s.energy==energy)
 local found=false;for _,card in ipairs(s.exhaust)do if card.uid==c.uid then found=true end end;assert(found)
end)
test('normal obtain Strike Dummy adds three before vulnerable Paper Frog',function()
 local r,s=begin({'StrikeDummy','Paper Frog'},{'strike','defend','defend','defend','defend','defend'})
 local c=find(s,'strike');s.enemies[1].statuses.vulnerable=2;local hp=s.enemies[1].hp
 assert(Run.play(r,c.uid,1));assert(s.enemies[1].hp==hp-15)
end)
test('normal obtain Hourglass turn one and Horn Cleat turn two',function()
 local r,s=begin({'Mercury Hourglass','HornCleat'})
 local found=false;for _,e in ipairs(s.events)do if e.kind=='damage'and e.detail.amount==3 then found=true end end;assert(found)
 assert(Run.endTurn(r));assert(s.player.block==14)
end)
test('normal obtain Clay actual HP-loss hooks creates next-turn block',function()
 local r,s=begin({'Self Forming Clay'});C.applyEffects(s,{{op='loseHp',value=1}},s.player)
 assert(s.player.statuses.next_turn_block==3);assert(Run.endTurn(r));assert(s.player.block==3)
end)
test('normal obtain Ink Bottle carries ten-play counter and triggers real draw',function()
 local r,s=begin({'InkBottle'},{'defend','defend','defend','defend','defend','defend'})
 s.relicCounters.ink_bottle=9;local c=find(s,'defend');local count=#s.hand
 assert(Run.play(r,c.uid));assert(s.relicCounters.ink_bottle==0 and #s.hand==count)
end)
test('normal obtain Sundial counts runtime shuffle and spends real energy action',function()
 local r,s=begin({'Sundial'},{'defend','defend','defend','defend','defend','defend'})
 s.relicCounters.sundial=2;s.discard=s.draw;s.draw={};local energy=s.energy
 C.draw(s,1);require('abyss_card_actions').drain(C,s)
 assert(s.energy==energy+2 and s.relicCounters.sundial==0)
end)
test('Toolbox pauses ordinary opening draw then resolves one choice without reroll',function()
 local r,s=begin({'Toolbox'});local p=assert(s.pendingChoice);assert(p.op=='toolbox'and #s.hand==0)
 local rng=s.cardRandomRng.counter;local token=p.token;local selected=p.cards[1].cardId
 assert(Run.chooseCard(r,token,1));assert(not s.pendingChoice and #s.hand==6 and s.energy==3)
 local found=false;for _,card in ipairs(s.hand)do if card.cardId==selected then found=true end end;assert(found)
 assert(s.cardRandomRng.counter==rng,'Toolbox rerolled on retrieval')
 assert(not Run.chooseCard(r,token,1));assert(s.cardRandomRng.counter==rng)
end)
test('Mummified Hand actual power play makes an eligible strike free this turn',function()
 local r,s=begin({'Mummified Hand'},{'inflame','strike','strike','strike','strike','strike'})
 local power=find(s,'inflame');assert(Run.play(r,power.uid))
 local free;for _,card in ipairs(s.hand)do if card.cardId=='strike'and C.cardDefinition(s,card).cost==0 then free=card end end
 assert(free);local energy=s.energy;assert(Run.play(r,free.uid,1));assert(s.energy==energy)
 assert(Run.endTurn(r));for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,card in ipairs(pile)do if card.cardId=='strike'then assert(C.cardDefinition(s,card).cost==1)end end end
end)
test('Gremlin Horn actual death grants energy and draw only before final enemy',function()
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Gremlin Horn'))
 r.deck={};for i=1,7 do r.deck[i]={uid=i,cardId='strike'}end;r.nextDeckUid=8
 assert(Run.startCombat(r,'louse_pair'));local s=r.combat
 for _,enemy in ipairs(s.enemies)do enemy.hp=1 end
 local before=#s.hand;assert(Run.play(r,find(s,'strike').uid,1));assert(s.energy==3 and #s.hand==before)
 assert(Run.play(r,find(s,'strike').uid,2));assert(s.energy==2 and #s.hand==before-1)
end)
test('Meat triggers before Burning Blood once at the exact half-HP boundary',function()
 local function win(hp,bloom)
  local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Meat on the Bone'));if bloom then assert(Run.obtainRelic(r,'Mark of the Bloom'))end
  r.hp=hp;r.maxHp=80;assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;s.enemies[1].hp=1
  local card=find(s,'strike');assert(Run.play(r,card.uid,1));return r,card
 end
 local r,card=win(40);assert(r.hp==58 and r.phase=='reward')
 assert(not Run.play(r,card.uid,1));assert(r.hp==58,'victory healing repeated')
 assert(win(41).hp==47,'Meat fired above half HP')
 assert(win(40,true).hp==40,'Bloom allowed victory healing')
end)
print('LUA_UNCOMMON_RELIC_LIFECYCLE_PASS '..n)
]====]},
shop={path='tests/lua/shop_relics_effects.lua',sha256='aa296ae81896c2dfb36356dc37ffe019ac59385cf6e3bc12b6980d8c4702793d',source=[====[package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Shop=require('abyss_shop_relics')
local C,R=require('abyss_combat'),require('abyss_run')
local A,Actions=require('abyss_actor'),require('abyss_card_actions')
local Random=require('abyss_sts_random')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function battle(ids)
 local run=R.new(data,42);assert(R.startCombat(run,'cultist_solo'))
 local s=run.combat;s.relics=ids;s.shopRelicCombat={};return s
end
test('source aliases and owners are exact',function()
 for source,id in pairs(Shop.aliases)do assert(Shop.owns({relics={source}},id))end
 assert(not Shop.owns({relics={'chemical_x'}},'sling'))
end)
test('Sling only grants elite strength and Clockwork grants artifact',function()
 local s=battle({'Sling','clockwork_souvenir'})
 assert(#Shop.battleStartActions(s,{eliteTrigger=false})==1)
 local effects=Shop.battleStartActions(s,{eliteTrigger=true});assert(#effects==2)
 for _,e in ipairs(effects)do A.applyPower(s,s.player,e.status,e.value,s.player)end
 assert(s.player.statuses.strength==2 and s.player.statuses.artifact==1)
end)
test('Hand Drill queues actual vulnerable and respects Artifact',function()
 local s=battle({'hand_drill'});local enemy=s.enemies[1]
 Shop.onBlockBroken(s,enemy);assert(#s.cardActions==1)
 Shop.execute(s,s.cardActions[1].effect);assert(enemy.statuses.vulnerable==2)
 A.applyPower(s,enemy,'artifact',1,enemy)
 Shop.execute(s,s.cardActions[1].effect);assert(enemy.statuses.vulnerable==2 and enemy.statuses.artifact==0)
 Shop.onBlockBroken(s,s.player);assert(#s.cardActions==1)
end)
test('Abacus fixed block ignores dexterity and frail',function()
 local s=battle({'the_abacus'});A.addStatus(s.player,'dexterity',9);A.addStatus(s.player,'frail',2)
 Shop.onShuffle(s);local e=s.cardActions[1].effect
 A.block(s,s.player,e.value,e.fixed);assert(s.player.block==6)
end)
test('Chemical X, Medical Kit and Frozen Eye preserve unrelated cards',function()
 local s=battle({'chemical_x','medical_kit','frozen_eye'})
 assert(Shop.xBonus(s)==2 and Shop.drawOrderVisible(s))
 local d={type='status',cost=-2,exhaust=false};local actual=Shop.medicalCard(s,d)
 assert(actual.cost==0 and actual.exhaust and d.cost==-2 and not d.exhaust)
 local attack={type='attack',cost=1};assert(Shop.medicalCard(s,attack)==attack)
 local slime=Shop.medicalCard(s,{type='status',cost=1});assert(slime.cost==1 and slime.exhaust)
end)
test('Spoon consumes one source boolean at disposal only',function()
 local s=battle({'strange_spoon'});s.cardRandomRng=Random.fromSeed('912')
 local oracle=Random.cloneState(s.cardRandomRng)
 for _=1,20 do
  assert(Shop.exhaustAfterUse(s,{type='skill'},true,false)==not Random.randomBoolean(oracle))
 end
 assert(Random.snapshot(s.cardRandomRng).counter==Random.snapshot(oracle).counter)
 local before=Random.snapshot(s.cardRandomRng).counter
 assert(Shop.exhaustAfterUse(s,{type='power'},true,false))
 assert(not Shop.exhaustAfterUse(s,{type='skill'},false,false))
 assert(Shop.exhaustAfterUse(s,{type='skill'},true,true))
 assert(Random.snapshot(s.cardRandomRng).counter==before)
end)
test('Orange Pellets removes debuffs but retains positive strength',function()
 local s=battle({'orange_pellets'});local p=s.player
 A.applyPower(s,p,'weak',2,p);A.applyPower(s,p,'strength',3,p)
 Shop.turnStartActions(s)
 Shop.onUseCard(s,{type='attack'});Shop.onUseCard(s,{type='skill'});assert(not s.cardActions)
 Shop.onUseCard(s,{type='power'});assert(#s.cardActions==1)
 Shop.execute(s,s.cardActions[1].effect);assert(p.statuses.weak==nil and p.statuses.strength==3)
 Shop.onUseCard(s,{type='power'});assert(#s.cardActions==1)
 Shop.onUseCard(s,{type='attack'});Shop.onUseCard(s,{type='skill'});assert(#s.cardActions==2)
end)
test('Brimstone grants both sides strength each turn',function()
 local s=battle({'brimstone'})
 for _=1,2 do for _,e in ipairs(Shop.turnStartActions(s))do
  local target=e.targetId and s.enemies[1]or s.player
  A.applyPower(s,target,e.status,e.value,target)
 end end
 assert(s.player.statuses.strength==4 and s.enemies[1].statuses.strength==2)
end)
test('Toolbox offers three distinct source cards and preserves real costs',function()
 local s=battle({'toolbox'});Shop.beginToolbox(C,s)
 local p=s.pendingChoice;local seen={}
 for _,c in ipairs(p.cards)do assert(not seen[c.cardId]);seen[c.cardId]=true end
 local chosen=p.cards[1].cardId;local count=#s.hand+#s.discard
 assert(not Shop.chooseToolbox(C,s,p.token+1,1,Actions))
 assert(Shop.chooseToolbox(C,s,p.token,1,Actions));assert(not s.pendingChoice)
 assert(#s.hand+#s.discard==count+1)
 local added=s.hand[#s.hand].cardId==chosen and s.hand[#s.hand]or s.discard[#s.discard]
 assert(added.cardId==chosen and added.costForTurn==nil)
 assert(not Shop.chooseToolbox(C,s,p.token,1,Actions))
end)
test('Battle Trance attack and power clear real NoDraw and permit subsequent draw',function()
 local s=C.new(data,{seed=42,deck={'battle_trance','strike','inflame','defend','defend','defend','defend','defend','defend','defend'},enemies={'cultist'}})
 s.relics={'orange_pellets'};s.shopRelicCombat={}
 local cards={};for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do cards[#cards+1]=c end end
 s.hand={};s.draw={};s.discard={};local uid={}
 for _,c in ipairs(cards)do
  if c.cardId=='battle_trance'or c.cardId=='strike'or c.cardId=='inflame'then
   s.hand[#s.hand+1]=c;uid[c.cardId]=c.uid
  else s.draw[#s.draw+1]=c end
 end
 assert(C.play(s,uid.battle_trance));assert(s.player.noDraw)
 assert(C.play(s,uid.strike,1));assert(s.player.noDraw)
 assert(C.play(s,uid.inflame));assert(not s.player.noDraw)
 for _,id in ipairs(s.player.powerOrder)do assert(id~='no_draw')end
 for _,entry in ipairs(s.player.powerScheduleOrder or {})do assert(entry.id~='no_draw')end
 local before=#s.hand;C.draw(s,1);assert(#s.hand==before+1)
 assert(not C.play(s,uid.inflame));assert(not s.player.noDraw)
end)
test('Pellets removal precedes already queued draw and late execution is idempotent',function()
 local s=battle({'orange_pellets'});assert(A.applyNoDraw(s,s.player))
 Actions.enqueue(s,{op='shopRelic',kind='pellets'})
 Actions.enqueue(s,{op='draw',value=1})
 local before=#s.hand;Actions.drain(C,s)
 assert(not s.player.noDraw and #s.hand==before+1)
 local count=#s.player.powerOrder;Shop.execute(s,{kind='pellets'})
 assert(#s.player.powerOrder==count and #s.hand==before+1)
end)
test('queued Pellets never removes Powers from a dead owner',function()
 local s=battle({'orange_pellets'});assert(A.applyNoDraw(s,s.player))
 A.applyPower(s,s.player,'weak',2,s.player);s.player.hp=0
 Shop.execute(s,{kind='pellets'})
 assert(s.player.noDraw and s.player.statuses.weak==2)
end)
print('LUA_SHOP_RELIC_EFFECTS_PASS '..n)
]====]},
parasite={path='tests/lua/act3_writhing_parasite.lua',sha256='7b06fd90e1672c11c3bb58fcca2fb66baad9274c0750e004a35b74bd8387516d',source=[====[local Run,C,D,Q,R,A,W,H=require('abyss_run'),require('abyss_combat'),require('abyss_data'),
 require('abyss_encounter_queue'),require('abyss_sts_random'),require('abyss_actor'),
 require('abyss_writhing_mass'),require('abyss_relic_hooks')
local passed,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function test(name,fn)local ok,why=pcall(fn)
 if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;e.writhingLast=id;return end end;error(id)end
local function battle(relics,counters,data)
 local streams={};for _,k in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[k]=R.fromSeed('42')end
 return C.new(data or D,{enemies={'writhing_mass'},deck={},roomSeed='42',roomStreams=streams,
  masterDeck={{uid=9,cardId='strike',upgraded=false}},nextMasterDeckUid=31,
  beforeFirstTurn=function(s)H.bindBattle(s,relics or {},counters or {});return true end})
end
local function stage(relics)
 local r=Run.new(D,'34',{campaign=true,experimental=true});r.act,r.floor,r.encounters=3,35,Q.new('34',3)
 for _=1,2 do local _,q=Q.consume(r.encounters,'normal');r.encounters=q;r.floor=r.floor+1 end
 for _,id in ipairs(relics or {})do assert(Run.obtainRelic(r,id))end
 assert(Run.startRoomCombat(r,'normal'));return r
end
local function combatParasites(s)
 local n=0;for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do
  for _,c in ipairs(pile)do if c.cardId=='parasite'then n=n+1 end end
 end;return n
end
test('A0 four attack payloads execute source values and attack-block retains fixed15',function()
 for _,v in ipairs({{'big_hit',32},{'multi_hit',21},{'attack_block',15},{'attack_debuff',10}})do
  local s=battle();local e=s.enemies[1];force(e,v[1]);local hp=s.player.hp
  assert(C.endTurn(s));eq(s.player.hp,hp-v[2]);eq(e.block,v[1]=='attack_block'and 15 or 0)
  if v[1]=='attack_debuff'then eq(s.player.statuses.weak,2);eq(s.player.statuses.vulnerable,2)end
 end
 local s=battle();local e=s.enemies[1];force(e,'attack_block')
 A.applyPower(s,e,'strength',3,e);A.applyPower(s,e,'dexterity',20,e);A.applyPower(s,e,'frail',2,s.player)
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-18);eq(e.block,15)
end)
test('attack-debuff spends Artifact Weak then Vulnerable and does not deal extra damage',function()
 for _,n in ipairs({1,2})do
  local s=battle();force(s.enemies[1],'attack_debuff');A.applyPower(s,s.player,'artifact',n,s.player)
  assert(C.endTurn(s));eq(s.player.hp,70);eq(s.player.statuses.weak or 0,0)
  eq(s.player.statuses.vulnerable or 0,n==1 and 2 or 0);eq(s.player.statuses.artifact,0)
 end
end)
test('real Run Implant obtains one permanent UID only and survives into next battle/removal',function()
 local r=stage();local s,e=r.combat,r.combat.enemies[1];local uid,count,combatUid=r.nextDeckUid,#r.deck,s.nextUid
 force(e,'implant');assert(Run.endTurn(r));eq(e.writhingUsedImplant,true)
 eq(#r.deck,count+1);local card=r.deck[#r.deck];eq(card.uid,uid);eq(card.cardId,'parasite');eq(card.upgraded,false)
 eq(r.nextDeckUid,uid+1);eq(s.nextMasterDeckUid,uid+1);eq(s.nextUid,combatUid)
 eq(combatParasites(s),0);eq(#s.masterDeck,#r.deck);eq(s.masterDeckObtains,nil)
 local streams={};for _,k in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[k]=R.fromSeed('42')end
 local nextBattle=C.new(r.data,{enemies={'cultist'},deck=r.deck,masterDeck=r.deck,roomSeed='42',roomStreams=streams})
 eq(combatParasites(nextBattle),1)
 local maximum=r.maxHp;r.phase,r.combat='map',nil -- explicit post-room removal boundary
 assert(Run.removeCard(r,uid));eq(r.maxHp,maximum-3);eq(#r.deck,count)
 local before=C.copy(r);local ok=Run.removeCard(r,uid);eq(ok,false);same(r,before)
end)
test('Omamori blocks before UID hooks gold health or combat cards but still spends the only Implant',function()
 for _,n in ipairs({2,1,0})do
  local s=battle({'omamori','ceramic_fish','darkstone_periapt'},{omamori=n});local e=s.enemies[1]
  local gold,hp,maximum,uid=s.player.gold,s.player.hp,s.player.maxHp,s.nextMasterDeckUid
  force(e,'implant');assert(C.endTurn(s));eq(e.writhingUsedImplant,true)
  eq(s.relicCounters.omamori,math.max(0,n-1));eq(combatParasites(s),0)
  eq(#s.masterDeck,n>0 and 1 or 2);eq(s.nextMasterDeckUid,uid+(n>0 and 0 or 1))
  eq(s.player.gold,gold+(n>0 and 0 or 9));eq(s.player.maxHp,maximum+(n>0 and 0 or 6))
  eq(s.player.hp,hp+(n>0 and 0 or 6))
  -- Legitimate future rolls can never announce another Implant after use.
  for _=1,20 do W.advance(s,e,function()error('unexpected legacy RNG')end);assert(e.intents[e.intentIndex].id~='implant')end
 end
end)
test('Darkstone in-combat health uses source healing modifiers and CeramicFish respects Ectoplasm',function()
 for _,v in ipairs({{{'darkstone_periapt','ceramic_fish'},6,9},
  {{'darkstone_periapt','magic_flower','ceramic_fish','ectoplasm'},9,0},
  {{'darkstone_periapt','mark_of_bloom','ceramic_fish'},0,9}})do
  local s=battle(v[1]);local e=s.enemies[1];s.player.hp=40
  s.potionInventory={'fairy_in_a_bottle'};s.relics[#s.relics+1]='red_skull'
  H.hpChanged(s,s.player,80);eq(s.player.statuses.strength,3)
  force(e,'implant');local maximum,gold=s.player.maxHp,s.player.gold;assert(C.endTurn(s))
  eq(s.player.maxHp,maximum+6);eq(s.player.hp,40+v[2]);eq(s.player.gold,gold+v[3]);eq(#s.masterDeck,2)
  eq(s.scoreStats.goldGained,v[3])
  eq(s.potionInventory[1],'fairy_in_a_bottle');eq(s.player.statuses.strength,v[2]>0 and 0 or 3)
 end
 -- Ordinary Run.obtainCard still refuses an unadapted combat health context.
 local r=stage({'darkstone_periapt'});local before=C.copy(r)
 local ok,why=Run.obtainCard(r,'parasite');eq(ok,false);eq(why,'darkstone_health_context_unavailable');same(r,before)
end)
test('real Run synchronizes Darkstone master health gold and Omamori charges exactly once',function()
 for _,omamori in ipairs({false,true})do
  local r=stage(omamori and {'darkstone_periapt','ceramic_fish','omamori'}or {'darkstone_periapt','ceramic_fish'})
  local s,e=r.combat,r.combat.enemies[1];local maximum,gold,uid,count=r.maxHp,r.gold,r.nextDeckUid,#r.deck
  force(e,'implant');assert(Run.endTurn(r))
  eq(r.maxHp,maximum+(omamori and 0 or 6));eq(r.gold,gold+(omamori and 0 or 9));eq(#r.deck,count+(omamori and 0 or 1))
  eq(r.nextDeckUid,uid+(omamori and 0 or 1));eq(r.relicCounters.omamori,omamori and 1 or nil)
  if not omamori then eq(r.hp,s.player.hp)end
 end
end)
test('public active Run obtains keep the later monster UID counter and Omamori snapshot coherent',function()
 for _,blocked in ipairs({false,true})do
  local r=stage(blocked and {'omamori','ceramic_fish'}or {'ceramic_fish'})
  if blocked then r.relicCounters.omamori=1;r.combat.relicCounters.omamori=1 end
  local uid,count,gold=r.nextDeckUid,#r.deck,r.gold
  assert(Run.obtainCard(r,'parasite'));local s,e=r.combat,r.combat.enemies[1]
  eq(s.nextMasterDeckUid,r.nextDeckUid);eq(#s.masterDeck,#r.deck);eq(combatParasites(s),0)
  eq(r.nextDeckUid,uid+(blocked and 0 or 1));eq(#r.deck,count+(blocked and 0 or 1))
  if blocked then eq(s.relicCounters.omamori,0)end
  force(e,'implant');assert(Run.endTurn(r))
  eq(#r.deck,count+(blocked and 1 or 2));eq(r.nextDeckUid,uid+(blocked and 1 or 2))
  eq(r.gold,gold+(blocked and 9 or 18));eq(r.deck[#r.deck].uid,r.nextDeckUid-1)
  eq(s.nextMasterDeckUid,r.nextDeckUid);eq(combatParasites(s),0)
 end
 -- Non-Writhing battles retain the old copied snapshot and have no new cursor.
 local s=C.new(D,{enemies={'cultist'},deck={},masterDeck={{uid=3,cardId='strike',upgraded=false}}})
 same(s.masterDeck,{{uid=3,cardId='strike',upgraded=false}});eq(s.nextMasterDeckUid,nil)
end)
test('late permanent hook and publication failures restore Run battle master deck relics and aliases',function()
 for _,where in ipairs({'hook','sync','blocked'})do
  local r=stage(where=='blocked'and {'omamori'}or {'darkstone_periapt','ceramic_fish'})
  local s,e=r.combat,r.combat.enemies[1];force(e,'implant')
  local before=C.copy(r);local deck,master,player,counters,ai=r.deck,s.masterDeck,s.player,s.relicCounters,s.aiRng
  local obtain,sync,emit=H.onObtainCard,W.syncMaster,require('abyss_events').emit;local fired=false
  if where=='hook'then H.onObtainCard=function(...)local ok,why=obtain(...);fired=true;error('LATE_PARASITE_HOOK');return ok,why end
  elseif where=='sync'then W.syncMaster=function(...)sync(...);fired=true;error('LATE_PARASITE_SYNC')end
  else require('abyss_events').emit=function(st,kind,detail)
   local result=emit(st,kind,detail);if kind=='permanent_card_blocked'then fired=true;error('LATE_OMAMORI_BLOCK')end;return result
  end end
  local ok=pcall(Run.endTurn,r);H.onObtainCard,W.syncMaster,require('abyss_events').emit=obtain,sync,emit
  assert(not ok and fired);same(r,before);eq(r.deck,deck);eq(s.masterDeck,master);eq(s.player,player);eq(s.relicCounters,counters);eq(s.aiRng,ai)
 end
end)
test('read-only source intent projection explains multi-hit block and permanent curse without RNG writes',function()
 local View=require('abyss_battle_intent_view');local s=battle();local e=s.enemies[1]
 for _,id in ipairs({'multi_hit','attack_block','attack_debuff','implant'})do
  force(e,id);local before=C.copy(s);local view=View.intentView(s,1);same(s,before)
  assert(not view.text:find('未知',1,true))
  if id=='multi_hit'then eq(view.value,'7×3')
  elseif id=='attack_block'then eq(view.value,'15');eq(view.badge,'defend')
  elseif id=='implant'then assert(view.text:find('永久',1,true)and view.text:find('本场',1,true));eq(view.kind,'debuff')end
 end
end)
print('ACT3_WRITHING_PARASITE '..passed..' passed; '..failed..' failed');assert(failed==0)
]====]},
}
