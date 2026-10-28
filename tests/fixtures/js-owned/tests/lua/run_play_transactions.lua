-- Source rooms and starter decks; controlled near-lethal damage and pending
-- permanent/inventory changes isolate the public command's transaction scope.
local Run,C,D,Q,R=require('abyss_run'),require('abyss_combat'),require('abyss_data'),
 require('abyss_encounter_queue'),require('abyss_sts_random')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b));if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end;for k in pairs(b)do assert(a[k]~=nil,path..'.'..tostring(k))end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function prepared(tier)
 local r=Run.new(D,'0',{experimental=true,campaign=true});r.floor=tier=='elite'and 7 or 1
 r.encounters=Q.new('0',1);assert(Run.startRoomCombat(r,tier));local s=r.combat
 for i,e in ipairs(s.enemies)do C.damage(s,s.player,e,e.hp+e.block-(i==#s.enemies and 6 or 0),true)end
 local uid;for _,c in ipairs(s.hand)do if c.cardId=='strike'then uid=c.uid;break end end;assert(uid)
 -- Actual supported permanent-change ABI and source inventory sync, not new
 -- product operations. Failure must undo publication while retaining inputs.
 local card=r.deck[1];local changed=C.copy(card);changed.upgraded=true
 s.masterDeckChanges={[card.uid]=changed}
 s.potionInventory[1]='block_potion';s.potionRngChanged=true
 s.potionRng=R.fromSeed('9');r.originalCommands={}
 return r,s,uid,#s.enemies
end
for _,tier in ipairs({'normal','elite'})do
 for _,mode in ipairs({'throw','reject'})do
  test(tier..' public lethal play '..mode..' restores full original graph and retries once',function()
   local r,s,uid,target=prepared(tier);local before=C.copy(r)
   local deck,card,inventory,commands,events,hand,enemy=r.deck,r.deck[1],r.potions,r.originalCommands,s.events,s.hand,s.enemies[target]
   local rng,words,combatRng=r.cardRng,r.cardRng.primitive,s.cardRandomRng
   local old=Run.finishCombat;local reached=false
   Run.finishCombat=function(...)
    local ok,why=old(...);assert(ok,why);reached=true
    eq(r.phase,'reward');eq(r.deck[1].upgraded,true);eq(r.potions[1],'block_potion')
    if mode=='throw'then error('injected late source reward failure')end
    return false,'source_reward_refused'
   end
   local called,ok,why=pcall(Run.play,r,uid,target,'atomic-play');Run.finishCombat=old
   assert(reached);if mode=='throw'then assert(not called)else assert(called);eq(ok,false);eq(why,'source_reward_refused')end
   same(r,before);eq(r.combat,s);eq(r.deck,deck);eq(r.deck[1],card);eq(r.potions,inventory);eq(r.originalCommands,commands)
   eq(s.enemies[target],enemy);eq(s.events,events);eq(s.hand,hand);eq(r.cardRng,rng);eq(rng.primitive,words);eq(s.cardRandomRng,combatRng)
   assert(Run.play(r,uid,target,'atomic-play'));eq(r.phase,'reward');eq(r.victories,1);eq(r.deck[1].upgraded,true)
   eq(r.potions[1],'block_potion');local committed=C.copy(r)
   local replay,reason=Run.play(r,uid,target,'atomic-play');eq(replay,true);eq(reason,'already_committed');same(r,committed)
  end)
 end
end
test('rejected ordinary play returns the original reason without any publication',function()
 local r,s,uid=prepared('normal');local before=C.copy(r)
 local ok,why=Run.play(r,uid,99,'bad-target');eq(ok,false);eq(why,'invalid_target');same(r,before)
 eq(r.combat,s);eq(r.originalCommands['bad-target'],nil)
end)
print('RUN_PLAY_TRANSACTIONS '..count..' groups; '..failed..' failed');assert(failed==0)
