-- Deterministic public API fixtures, not natural acquisition/client evidence.
local Run,C,H,Data=require('abyss_run'),require('abyss_combat'),require('abyss_relic_hooks'),require('abyss_data')
local R,Pool=require('abyss_sts_random'),require('abyss_relic_pool')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'extra '..tostring(k))end
end
local function snap(r)return C.copy(r,{[r.data]=r.data})end
local function fresh()
 local r=Run.new(Data,'42');assert(Run.obtainRelic(r,'Darkstone Periapt'));return r
end
local function rejected(r,fn,reason)
 local before=snap(r);local deck,owner,pending=r.deck,r.relicPool,r.pendingCombatRewards
 local ok,why=fn(r);eq(ok,false);eq(why,reason);same(r,before)
 eq(r.deck,deck);eq(r.relicPool,owner);eq(r.pendingCombatRewards,pending)
end
local count=0
local function test(name,fn)fn();count=count+1;print('PASS Darkstone '..count..' '..name)end

test('source and local IDs resolve to same unique uncommon owner without retroactive curse gains',function()
 local r=Run.new(Data,'42');assert(Run.obtainCard(r,'Writhe'));assert(Run.obtainCard(r,'Regret'))
 r.hp=20;local before=snap(r);assert(Run.obtainRelic(r,'Darkstone Periapt'))
 eq(r.relics[#r.relics],'darkstone_periapt');eq(r.hp,20);eq(r.maxHp,before.maxHp)
 rejected(r,function(s)return Run.obtainRelic(s,'darkstone_periapt')end,'relic_already_owned')
 eq(H.localId('Darkstone Periapt'),'darkstone_periapt')
end)

test('Writhe permanent obtain grows maximum first and heals six, once per actual obtain',function()
 local r=fresh();r.hp=r.maxHp;local hp,max,uid=r.hp,r.maxHp,r.nextDeckUid
 local ok,obtained=Run.obtainCard(r,'Writhe');assert(ok);eq(obtained,uid)
 eq(r.maxHp,max+6);eq(r.hp,hp+6);eq(r.nextDeckUid,uid+1);eq(r.deck[#r.deck].cardId,'writhe')
 assert(Run.obtainCard(r,'Regret'));eq(r.maxHp,max+12);eq(r.hp,hp+12)
end)

test('non-curse permanent status and ordinary cards do not grow maxHP',function()
 local r=fresh();r.hp=3;local before=snap(r)
 assert(Run.obtainCard(r,'Dazed'));assert(Run.obtainCard(r,'strike'))
 eq(r.maxHp,before.maxHp);eq(r.hp,3);eq(#r.deck,#before.deck+2)
end)

test('every available curse definition triggers, while status definitions never do',function()
 local r=fresh();r.hp=1;local maximum=r.maxHp;local curses,statuses=0,0
 for _,d in ipairs(Data.cards.cards)do
  if d.type=='curse' or d.type=='status' then
   local ok=Run.obtainCard(r,d.id);assert(ok,d.id)
   if d.type=='curse' then curses=curses+1 else statuses=statuses+1 end
   eq(r.maxHp,maximum+6*curses)
  end
 end
 assert(curses>1 and statuses>1);eq(r.hp,1+6*curses)
end)

test('Omamori prevents UID/deck insertion and both Darkstone and Ceramic Fish hooks',function()
 local r=fresh();assert(Run.obtainRelic(r,'Omamori'));assert(Run.obtainRelic(r,'CeramicFish'))
 r.hp=1;local before=snap(r)
 for i=1,2 do local ok,why=Run.obtainCard(r,'Writhe');assert(ok);eq(why,'curse_blocked')
  eq(r.hp,1);eq(r.maxHp,before.maxHp);eq(#r.deck,#before.deck);eq(r.nextDeckUid,before.nextDeckUid);eq(r.gold,before.gold)
  eq(r.relicCounters.omamori,2-i)
 end
 assert(Run.obtainCard(r,'Writhe'));eq(r.maxHp,before.maxHp+6);eq(r.hp,7);eq(r.gold,before.gold+9)
end)

test('prepared before equip curse sees new Darkstone, but its old Omamori decision stays frozen',function()
 local r=Run.new(Data,'42');r.hp=1;local offer=assert(Run.prepareCard(r,'Writhe'));local max=r.maxHp
 assert(Run.obtainRelic(r,'Darkstone Periapt'));assert(Run.obtainRelic(r,'Omamori'))
 assert(Run.commitCard(r,offer));eq(r.maxHp,max+6);eq(r.hp,7);eq(r.relicCounters.omamori,2)
 local blocked=assert(Run.prepareCard(r,'Writhe'));assert(blocked.blocked);local uid=r.nextDeckUid
 assert(Run.commitCard(r,blocked));eq(r.maxHp,max+6);eq(r.hp,7);eq(r.nextDeckUid,uid)
end)

test('canonical maximum arithmetic has no invented 999 cap and canonical Mark-of-Bloom prevents only healing',function()
 for _,id in ipairs({'mark_of_bloom','Mark of the Bloom'})do
  local r=fresh();r.relics[#r.relics+1]=id;r.maxHp=1000;r.hp=2
  assert(Run.obtainCard(r,'Writhe'));eq(r.maxHp,1006);eq(r.hp,2)
 end
 local r=fresh();r.maxHp=1000;r.hp=999;assert(Run.obtainCard(r,'Writhe'));eq(r.maxHp,1006);eq(r.hp,1005)
end)

test('invalid maximum rolls back a prior Ceramic Fish hook and all permanent state',function()
 for _,maximum in ipairs({2147483642,-1,1.5})do
  local r=Run.new(Data,'42');assert(Run.obtainRelic(r,'CeramicFish'));assert(Run.obtainRelic(r,'Darkstone Periapt'))
  r.maxHp=maximum;r.hp=1;rejected(r,function(s)return Run.obtainCard(s,'Writhe')end,'invalid_max_hp')
 end
end)

test('missing permanent health API and exceptions commit no partial card or health',function()
 local r=fresh();local before=snap(r)
 local called=pcall(H.onObtainCard,r,{cardId='writhe'},{type='curse'})
 eq(called,false);same(r,before)
 local old=Run.increaseMaxHp;Run.increaseMaxHp=function(s,v)local ok=old(s,v);assert(ok);error('bounded after-health failure')end
 rejected(r,function(s)return Run.obtainCard(s,'Writhe')end,'transaction_failed');Run.increaseMaxHp=old
 assert(Run.obtainCard(r,'Writhe'));eq(r.maxHp,before.maxHp+6)
end)

test('active combat rejects permanent curse only and temporary combat generation never calls permanent hooks',function()
 local r=fresh();assert(Run.startRoomCombat(r,'normal'));local before=snap(r)
 rejected(r,function(s)return Run.obtainCard(s,'Writhe')end,'darkstone_health_context_unavailable')
 local state=r.combat;local original=H.onObtainCard;local discardCount=#state.discard
 H.onObtainCard=function()error('combat temporary generation must not obtain permanently')end
 local ok,err=pcall(function()C.applyEffects(state,{{op='makeTempCardInDiscard',card='writhe',value=1},{op='makeTempCardInDiscard',card='dazed',value=1}},state.player)end)
 H.onObtainCard=original;assert(ok,tostring(err));eq(#state.discard,discardCount+2)
 eq(state.discard[discardCount+1].cardId,'writhe');eq(state.discard[discardCount+2].cardId,'dazed')
 eq(r.maxHp,before.maxHp);eq(r.hp,before.hp)
 eq(#r.deck,#before.deck);eq(r.nextDeckUid,before.nextDeckUid)
 assert(Run.obtainCard(r,'Dazed'));eq(r.maxHp,before.maxHp)
end)

test('retained inactive combat and pending rewards reject without corrupting graph aliases',function()
 for _,pending in ipairs({false,true})do
  local r=fresh();r.nodeFlow={type='combat',complete=true};r.phase='reward';r.rewards={manualContinue=true}
  r.combat={phase='victory',player={hp=r.hp,maxHp=r.maxHp}}
  if pending then assert(Run.leaveCombatRewards(r));eq(r.pendingCombatRewards.flow,r.nodeFlow)end
  rejected(r,function(s)return Run.obtainCard(s,'Writhe')end,'darkstone_health_context_unavailable')
  if pending then eq(r.pendingCombatRewards.flow,r.nodeFlow);assert(Run.reopenCombatRewards(r))end
  eq(r.combat.player.maxHp,r.maxHp);eq(r.combat.player.hp,r.hp)
 end
end)

test('nested ignored refusal aborts enclosing command even after earlier resource edits',function()
 local r=fresh();r.combat={phase='player'}
 rejected(r,function(s)return Run.transaction(s,function(staged)
  staged.gold=1;Run.obtainCard(staged,'Writhe');return true
 end)end,'darkstone_health_context_unavailable')
end)

test('source queue admission uses existing floor gate and never rerolls missing source definitions',function()
 local r=fresh();r.relics={};r.relicPool.queues.uncommon={'Darkstone Periapt','Blue Candle'}
 -- All Ironclad pool effects now exist. Explicitly stage a missing definition
 -- to retain the original no-reroll/readonly failure-path regression.
 r.data=C.copy(r.data)
 local removed=false
 for i,entry in ipairs(r.data.relics.relics)do if entry.sourceId=='Blue Candle'then table.remove(r.data.relics.relics,i);removed=true;break end end
 assert(removed,'missing-definition adversary must remove the implemented Blue Candle')
 local before=snap(r);r.floor=48;local offer,pool=Run.prepareRelic(r,{tier='uncommon',room='event',screenless=true})
 assert(offer);eq(offer.id,'darkstone_periapt');eq(offer.sourceId,'Darkstone Periapt');eq(#offer.trace,1)
 eq(#pool.queues.uncommon,1);eq(r.relicPool.queues.uncommon[1],'Darkstone Periapt')
 r.floor=49;local missing,why=Run.prepareRelic(r,{tier='uncommon',room='event',screenless=true})
 eq(missing,nil);eq(why,'relic_content_unavailable');same(r.relicPool,before.relicPool)
 local p=Pool.restore(Pool.snapshot(r.relicPool),r.relicPool.catalog)
 local id=Pool.draw(p,'uncommon',{floor=49,endless=true});eq(id,'Darkstone Periapt')
end)
print('DARKSTONE_PERIAPT '..count..' passed')
