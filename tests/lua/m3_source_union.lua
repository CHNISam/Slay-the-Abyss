-- Combined source-leaf seams, with controlled room/near-lethal inputs.
-- These are offline commands, not native or natural campaign acceptance.
local Run,C,D,Map,Nodes,Pool,Q=require('abyss_run'),require('abyss_combat'),require('abyss_data'),
 require('abyss_map'),require('abyss_nodes'),require('abyss_event_pool'),require('abyss_encounter_queue')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 if a==b then return end;path=path or 'state';eq(type(a),type(b))
 if type(a)~='table'then assert(a==b,path..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local count,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
test('accepted Ghosts uses current actual Toxic Egg and Ceramic Fish owners five times',function()
 local r=Run.new(D,'42',{experimental=true,campaign=true})
 assert(Run.obtainRelic(r,'Toxic Egg 2'));assert(Run.obtainRelic(r,'ceramic_fish'))
 r.act,r.floor=2,17;r.unknown.pools=Pool.new('full',false,2)
 local m=Map.generate(r.data,'42',2);local n=Map.available(m)[1]
 for _,v in ipairs(m.nodes)do if v.id==n.id then v.type='event';v.eventId='ghosts'end end
 assert(Nodes.enter(r,m,n.id));local uid,size,gold=r.nextDeckUid,#r.deck,r.gold
 local cardRng,eventRng=C.copy(r.cardRng),C.copy(r.eventRng)
 assert(Nodes.chooseEvent(r,'accept'));eq(r.maxHp,40);eq(r.hp,40)
 eq(#r.deck,size+5);eq(r.nextDeckUid,uid+5);eq(r.gold,gold+45)
 for i=1,5 do local card=r.deck[size+i]
  eq(card.cardId,'apparition');eq(card.uid,uid+i-1);eq(card.upgraded,true);eq(card.upgrades,1)
  eq(r.nodeFlow.event.obtainedCardUids[i],card.uid)
 end
 same(r.cardRng,cardRng);same(r.eventRng,eventRng)
 local after=C.copy(r);local ok=Nodes.chooseEvent(r,'accept');eq(ok,false);same(r,after)
 assert(Nodes.chooseEvent(r,'leave'));eq(r.phase,'map');eq(#r.deck,size+5)
end)
local function preparedMass()
 local r=Run.new(D,'34',{campaign=true,experimental=true})
 r.act,r.floor,r.encounters=3,35,Q.new('34',3)
 for _=1,2 do local _,q=Q.consume(r.encounters,'normal');r.encounters=q;r.floor=r.floor+1 end
 assert(Run.obtainRelic(r,'darkstone_periapt'));assert(Run.obtainRelic(r,'ceramic_fish'))
 assert(Run.startRoomCombat(r,'normal'));local s,e=r.combat,r.combat.enemies[1]
 eq(e.ai.policy,'writhing_mass')
 for i,intent in ipairs(e.intents)do if intent.id=='implant'then e.intentIndex=i;e.writhingLast='implant'end end
 -- Run normally publishes these immediately after endTurn. Deliberately stage
 -- the actual Combat queue result to exercise the later public play boundary.
 assert(C.endTurn(s));eq(#s.masterDeckObtains,1)
 C.damage(s,s.player,e,e.hp+e.block-6,true);eq(e.hp,6);eq(e.block,0)
 local uid;for _,card in ipairs(s.hand)do if card.cardId=='strike'then uid=card.uid;break end end;assert(uid)
 r.originalCommands={};return r,s,e,uid
end
for _,mode in ipairs({'throw','reject'})do
 test('Writhing permanent obtain survives public lethal play '..mode..' rollback and exactly-once retry',function()
  local r,s,e,uid=preparedMass();local size,nextUid=#r.deck,r.nextDeckUid
  local before=C.copy(r);local deck,master,pending,ai,words=r.deck,s.masterDeck,s.masterDeckObtains,s.aiRng,s.aiRng.primitive
  local old=Run.finishCombat;local reached=false
  Run.finishCombat=function(...)
   local ok,why=old(...);assert(ok,why);reached=true;eq(r.phase,'reward')
   eq(#r.deck,size+1);eq(r.deck[#r.deck].cardId,'parasite');eq(r.deck[#r.deck].uid,nextUid)
   eq(r.nextDeckUid,nextUid+1);eq(s.masterDeckObtains,nil)
   if mode=='throw'then error('combined late source reward failure')end
   return false,'source_reward_refused'
  end
  local called,ok,why=pcall(Run.play,r,uid,1,'mass-lethal');Run.finishCombat=old
  assert(reached);if mode=='throw'then eq(called,false)else eq(called,true);eq(ok,false);eq(why,'source_reward_refused')end
  same(r,before);eq(r.combat,s);eq(r.deck,deck);eq(s.enemies[1],e)
  eq(s.masterDeck,master);eq(s.masterDeckObtains,pending);eq(s.aiRng,ai);eq(ai.primitive,words)
  assert(Run.play(r,uid,1,'mass-lethal'));eq(r.phase,'reward');eq(#r.deck,size+1);eq(r.nextDeckUid,nextUid+1)
  eq(r.deck[#r.deck].uid,nextUid);eq(s.masterDeckObtains,nil)
  local after=C.copy(r);local replay,reason=Run.play(r,uid,1,'mass-lethal')
  eq(replay,true);eq(reason,'already_committed');same(r,after)
 end)
end
print('M3_SOURCE_UNION '..count..' groups; '..failed..' failed');assert(failed==0)
