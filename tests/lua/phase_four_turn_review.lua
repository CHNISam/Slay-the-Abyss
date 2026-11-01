-- Independent frozen238 review. Real Core commands, no replaced services.
-- These controlled fixtures do not prove natural acquisition or client parity.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local A=require('abyss_actor')
local P=require('abyss_character_profiles')
local Data=require('abyss_data')
local passed,failed=0,0
local function eq(a,b,why)assert(a==b,(why or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('ok phase_four_turn_review '..name)
 else failed=failed+1;print('not ok phase_four_turn_review '..name..' -- '..tostring(why))end
end
local function find(pile,id)for _,c in ipairs(pile)do if c.cardId==id then return c end end;error('missing '..id)end
local function has(pile,uid)for _,c in ipairs(pile)do if c.uid==uid then return true end end;return false end
local function play(s,id,target)local ok,why=C.play(s,find(s.hand,id).uid,target);assert(ok,why)end
local function arrange(s,handIds,drawIds,discardIds)
 local all={};for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do all[#all+1]=c end end
 s.hand={};s.draw={};s.discard={};s.exhaust={}
 for _,spec in ipairs({{'hand',handIds},{'draw',drawIds},{'discard',discardIds}})do
  for _,id in ipairs(spec[2]or{})do
   local card;for i,c in ipairs(all)do if c.cardId==id then card=table.remove(all,i);break end end
   s[spec[1]][#s[spec[1]]+1]=assert(card,'fixture lacks '..id)
  end
 end
 assert(#all==0,'fixture left unassigned original instances')
end

test('ordinary Dagger Throw pauses before Sharp Hide and using-card disposal without stance feature',function()
 -- Silent has no stance mechanic. Combat.new accepts this same no-stance
 -- entry used by existing Silent foundational Core tests.
 local s=C.new(P.prepare(Data,'silent'),{seed=42,cardRandomSeed='42',
  deck={'dagger_throw','tactician','defend_green'},enemies={'cultist'}})
 eq(s.player.stance,nil);s.player.hp=3;s.enemies[1].hp=100
 assert(A.applyPower(s,s.enemies[1],'sharp_hide',3,s.enemies[1]))
 local card=find(s.hand,'dagger_throw');local tactician=find(s.hand,'tactician')
 play(s,'dagger_throw',1)
 eq(s.player.hp,3,'manual discard must pause before onUse Sharp Hide')
 eq(s.phase,'player');assert(s.pendingDiscard);assert(s.pendingPlay);assert(s.actionQueue)
 assert(s.cardInUse==card);assert(not has(s.discard,card.uid));eq(s.energy,2)
 assert(C.chooseDiscard(s,{tactician.uid},s.pendingDiscard.token))
 eq(s.energy,3,'Tactician TOP energy executes before subsequent Sharp Hide')
 eq(s.player.hp,0);eq(s.phase,'defeat');assert(s.cardInUse==card)
 assert(not has(s.discard,card.uid));assert(has(s.discard,tactician.uid))
end)
test('same Dagger Throw source sequence is correct with the Neutral stance option used by Run',function()
 local s=C.new(P.prepare(Data,'silent'),{seed=42,cardRandomSeed='42',enableStances=true,
  deck={'dagger_throw','tactician','defend_green'},enemies={'cultist'}})
 eq(s.player.stance,'Neutral');s.player.hp=3;s.enemies[1].hp=100
 assert(A.applyPower(s,s.enemies[1],'sharp_hide',3,s.enemies[1]))
 local using=find(s.hand,'dagger_throw');local tactician=find(s.hand,'tactician')
 play(s,'dagger_throw',1);eq(s.player.hp,3);assert(s.pendingDiscard);assert(s.cardInUse==using)
 assert(C.chooseDiscard(s,{tactician.uid},s.pendingDiscard.token))
 eq(s.energy,3);eq(s.player.hp,0);eq(s.phase,'defeat');assert(s.cardInUse==using)
 assert(has(s.discard,tactician.uid));assert(not has(s.discard,using.uid))
end)

local function scryState(noDraw,selectWeave)
 local deck={'cut_through_fate','weave'};for i=1,9 do deck[#deck+1]='protect'end
 for i=1,3 do deck[#deck+1]='defend_purple'end
 local s=C.new(P.prepare(Data,'watcher'),{seed=42,cardRandomSeed='42',enableStances=true,deck=deck,enemies={'cultist'}})
 s.enemies[1].hp=100
 local hand={'cut_through_fate'};for i=1,9 do hand[#hand+1]='protect'end
 local draw={'defend_purple','defend_purple','defend_purple'}
 if selectWeave then draw[#draw+1]='weave' end
 arrange(s,hand,draw,selectWeave and {}or{'weave'})
 assert(A.applyPower(s,s.player,'nirvana',3,s.player));s.player.noDraw=noDraw
 return s
end
for _,noDraw in ipairs({false,true})do
 test('Weave recall respects full-hand native Draw and NoDraw after Scry pause '..tostring(noDraw),function()
  local s=scryState(noDraw,false);local weave=s.discard[1];local using=find(s.hand,'cut_through_fate')
  play(s,'cut_through_fate',1);local p=assert(s.pendingScry)
  eq(#s.hand,9);assert(s.cardInUse==using);eq(s.player.block,0);eq(s.enemies[1].hp,93)
  assert(C.chooseScry(s,{},p.token));eq(s.enemies[1].hp,93);eq(s.player.block,3);eq(#s.hand,10)
  eq(has(s.hand,weave.uid),noDraw);eq(has(s.discard,weave.uid),not noDraw)
  eq(#s.draw,noDraw and 3 or 2);assert(has(s.discard,using.uid));eq(s.cardInUse,nil)
  local block;for _,event in ipairs(s.events)do if event.kind=='block'then block=event end end
  assert(block);assert(not has(block.frame.hand,weave.uid),'Nirvana runs before Weave tail')
  assert(has(block.frame.discard,using.uid),'UseCard cleanup precedes Nirvana tail')
 end)
end
test('Scry selecting Weave resumes exactly once and full native Draw blocks late recall',function()
 local s=scryState(false,true);local using=find(s.hand,'cut_through_fate');local weave=find(s.draw,'weave')
 play(s,'cut_through_fate',1);local p=assert(s.pendingScry);local queue=s.actionQueue
 local hp,energy,events=s.enemies[1].hp,s.energy,#s.events
 local ok=C.chooseScry(s,{using.uid},p.token);eq(ok,false)
 eq(s.pendingScry,p);eq(s.actionQueue,queue);eq(s.enemies[1].hp,hp);eq(s.energy,energy);eq(#s.events,events)
 assert(C.chooseScry(s,{weave.uid},p.token));eq(s.enemies[1].hp,hp);eq(s.energy,energy)
 eq(#s.hand,10);assert(has(s.discard,weave.uid));assert(not has(s.hand,weave.uid))
 eq(s.pendingScry,nil);eq(s.actionQueue,nil);eq(s.pendingPlay,nil);eq(s.cardInUse,nil)
 local before=#s.events;eq(C.chooseScry(s,{weave.uid},p.token),false);eq(#s.events,before)
end)
print('PHASE_FOUR_TURN_REVIEW_PASS '..passed..' FAIL '..failed)
if failed>0 then error('phase_four_turn_review found '..failed..' source-contract violation(s)')end
