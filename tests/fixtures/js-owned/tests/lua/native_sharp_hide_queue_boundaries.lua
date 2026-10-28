local F=dofile('tests/lua/support/native_sharp_hide_fixture.lua')
local Run,C,eq,same=F.Run,F.C,F.eq,F.same
local Actions,A=require('abyss_card_actions'),require('abyss_actor')
local count,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
test('no Rod still draws TOP while the native card remains in limbo and before disposal',function()
 local r,s,c=F.setup({rod=false});local before=s.shuffleRng.counter;local hp=s.player.hp
 local original=Actions.apply;local observed=false
 Actions.apply=function(combat,state,item)
  if state==s and item.effect.op=='draw'then
   observed=true;eq(state.cardInUse,c);eq(#state.discard,0);eq(state.player.hp,hp-3)
  end;return original(combat,state,item)
 end
 local ok,why=pcall(Run.play,r,c.uid,1);Actions.apply=original;assert(ok and why)
 assert(observed);eq(#s.hand,0);eq(#s.discard,1);eq(s.discard[1],c);eq(s.shuffleRng.counter,before)
end)
test('native independent Sharp Hide is queued once and never broadens the four-argument Actor label',function()
 local r,s,c=F.setup({puzzle=false});local enemy=s.enemies[1];local hp=s.player.hp;local start=#s.events+1
 assert(Run.play(r,c.uid,1));eq(s.player.hp,hp-2)
 local hits=0;for i=start,#s.events do local ev=s.events[i]
  if ev.kind=='status_damage'and ev.detail.status=='sharp_hide'then hits=hits+1;eq(ev.detail.source,enemy.id)end
 end;eq(hits,1)
 local before=s.player.hp;eq(A.retaliate(s,enemy,s.player,3),2);eq(s.player.hp,before-2)
 eq(s.events[#s.events].detail.status,'thorns')
 local snapshot=C.copy(s);assert(not pcall(A.retaliate,s,enemy,s.player,3,'thorns'));same(s,snapshot)
end)
test('dead final owner DAMAGE survives victory while simultaneous player death stops disposal',function()
 for _,row in ipairs({{hp=2,rod=true,outcome='defeat',after=0},
  {hp=3,rod=true,outcome='victory',after=1},{hp=3,rod=false,outcome='defeat',after=0},
  {hp=2,rod=true,fairy=true,outcome='victory',after=24}})do
  local r,s,c=F.setup({hp=row.hp,rod=row.rod,fairy=row.fairy,finisher=true});local enemy=s.enemies[1]
  local original=C.capturedSharpHide;local observed=false
  C.capturedSharpHide=function(state,effect)
   if state==s then observed=true;eq(enemy.hp,0);eq(effect.sourceId,enemy.id);eq(state.cardInUse,c)end
   return original(state,effect)
  end
  local called,ok=pcall(Run.play,r,c.uid,1);C.capturedSharpHide=original;assert(called and ok and observed)
  eq(s.player.hp,row.after);eq(s.phase,row.outcome)
  if row.outcome=='defeat'then eq(s.cardInUse,c)else eq(s.cardInUse,nil)end
  if row.fairy then eq(s.potionInventory[1],nil)end
  local wins,losses=0,0;for _,ev in ipairs(s.events)do if ev.kind=='victory'then wins=wins+1 elseif ev.kind=='defeat'then losses=losses+1 end end
  eq(wins,row.outcome=='victory'and 1 or 0);eq(losses,row.outcome=='defeat'and 1 or 0)
 end
end)
test('Core late throw after the actual TOP draw restores all original graph aliases and retries same UID',function()
 local r,s,c=F.setup();local before=C.copy(r)
 local hand,discard,events,potions,enemy,rng=s.hand,s.discard,s.events,s.potionInventory,s.enemies[1],s.shuffleRng
 local original=Actions.apply;local reached=false
 Actions.apply=function(combat,state,item)
  local result=original(combat,state,item)
  if state==s and item.effect.op=='draw'then eq(state.cardInUse,c);eq(state.player.hp,78);reached=true;error('late actual TOP draw')end
  return result
 end
 local called=pcall(Run.play,r,c.uid,1);Actions.apply=original;assert(not called and reached)
 same(r,before);eq(r.combat,s);eq(s.hand,hand);eq(s.hand[1],c);eq(s.discard,discard);eq(s.events,events)
 eq(s.potionInventory,potions);eq(s.enemies[1],enemy);eq(s.shuffleRng,rng)
 assert(Run.play(r,c.uid,1));eq(s.player.hp,78);eq(#s.hand,0);eq(s.discard[1],c)
end)
test('public outer transaction late validator rejects the completed native play atomically',function()
 local r,s,c=F.setup();local before=C.copy(r);local deck,hand,enemy,rng=r.deck,s.hand,s.enemies[1],s.shuffleRng
 local reached=false;local accepted,why=Run.transaction(r,function(staged)
  local stagedCard=staged.combat.hand[1];assert(stagedCard~=c);eq(stagedCard.uid,c.uid)
  assert(Run.play(staged,c.uid,1));eq(staged.combat.player.hp,78);eq(staged.combat.discard[1],stagedCard)
  reached=true;return false,'native_sharp_hide_late_validator'
 end)
 assert(reached);eq(accepted,false);eq(why,'native_sharp_hide_late_validator');same(r,before)
 eq(r.combat,s);eq(r.deck,deck);eq(s.hand,hand);eq(s.hand[1],c);eq(s.enemies[1],enemy);eq(s.shuffleRng,rng)
 assert(Run.play(r,c.uid,1));eq(#s.hand,0);eq(s.discard[1],c)
end)
test('illegal UID rejects before mutation while actual Hex metadata keeps its existing disposal path',function()
 local r,s,c=F.setup();local before=C.copy(r);eq(Run.play(r,c.uid+999,1),false);same(r,before)
 -- Actual Chosen grants Hex on its second turn; the native Armaments has no
 -- other eligible hand cards, so its ordinary disposal creates one real Dazed.
 local data=Run.new(F.D,42).data
 local chosen=C.new(data,{seed=42,deck={'armaments'},enemies={'chosen'}})
 assert(C.endTurn(chosen));assert(C.endTurn(chosen));eq(chosen.player.statuses.hex,1)
 local arm=chosen.hand[1];eq(arm.cardId,'armaments');eq(C.cardDefinition(chosen,arm).runNativeABI,true)
 assert(C.play(chosen,arm.uid,1));eq(chosen.pendingChoice,nil)
 local dazed=0;for _,pile in ipairs({chosen.hand,chosen.draw,chosen.discard})do for _,v in ipairs(pile)do if v.cardId=='dazed'then dazed=dazed+1 end end end
 eq(dazed,1);eq(chosen.discard[1],arm)
end)
print('NATIVE_SHARP_HIDE_QUEUE_BOUNDARIES '..count..' groups; '..failed..' failed');assert(failed==0)
