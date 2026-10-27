-- Public room/command boundaries and focused arithmetic fixtures, not a natural
-- Act3 playthrough. Chapter placement below does not simulate earlier victories.
local C=require('abyss_combat')
local A=require('abyss_actor')
local AI=require('abyss_enemy_ai')
local Run=require('abyss_run')
local Q=require('abyss_encounter_queue')
local R=require('abyss_sts_random')
local Data=require('abyss_data')
local passed,failed=0,0
local function eq(a,b)if a~=b then error(debug.traceback(tostring(a)..' ~= '..tostring(b),2),0)end end
local function same(a,b,path)
 path=path or 'state';eq(type(a),type(b))
 if type(a)~='table'then assert(a==b,path);return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' missing '..tostring(k))end
end
local function test(name,fn)
 local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))
end
local function room(seed)
 local r=Run.new(Data,seed,{experimental=true,campaign=true})
 r.act,r.floor,r.encounters=3,35,Q.new(seed,3)
 return r
end
local function battle(seed,deck,enemies,data)
 seed=seed or '1'
 local streams={seed=seed}
 for _,id in ipairs({'monsterHpRng','aiRng','shuffleRng','cardRandomRng'})do streams[id]=R.fromSeed(seed)end
 return C.new(data or Data,{deck=deck or {},enemies=enemies or {'orb_walker'},seed=42,
  roomSeed=streams.seed,roomStreams=streams})
end
local function intent(e)return e.intents[e.intentIndex].id end
local function roll(n)return function(_,max)eq(max,100);return n+1 end end
local function laser(s)
 local e=s.enemies[1];AI.initialize(s,e,roll(40));eq(intent(e),'laser')
 return e,e.intents[e.intentIndex].effects
end

test('public Act3 room uses the unchanged source queue and real A0 opening',function()
 local r=room('4');eq(Q.peek(r.encounters,'normal'),'Orb Walker')
 local queue=r.encounters;local before=#queue.normal
 local dataBefore=C.copy(r.data);local hp=r.hp
 local ok,why=Run.startRoomCombat(r,'normal');assert(ok,why)
 local s,e=r.combat,r.combat.enemies[1]
 eq(r.encounterSource,'Orb Walker');eq(r.encounterTier,'normal');eq(s.roomSeed,'39')
 eq(e.definitionId,'orb_walker');assert(e.hp>=90 and e.hp<=96);eq(e.maxHp,e.hp)
 eq(e.statuses.generic_strength_up,3);eq(e.statuses.strength,nil);eq(s.player.hp,hp)
 eq(s.monsterHpRng.counter,2);eq(s.aiRng.counter,1);eq(s.cardRandomRng.counter,0)
 eq(#r.encounters.normal,before-1);eq(#queue.normal,before);eq(r.roomGeneration,1)
 same(r.data,dataBefore)
 local damage=intent(e)=='claw' and 15 or 10
 assert(Run.endTurn(r));eq(s.player.hp,hp-damage);eq(e.statuses.strength,3)
 eq(e.statuses.generic_strength_up,3);eq(s.aiRng.counter,2)
end)

test('every unimplemented Act3 category rejects without queue RNG or resource changes',function()
 for _,spec in ipairs({{'1','normal'},{'34','normal',2},{'4','elite'},{'4','boss'}})do
  local r=room(spec[1]);local tier=spec[2]
  -- Shapes/Transient/Horde are implemented. Fixed TheBeyond/independent queue
  -- seed34 keeps Writhing Mass unavailable after the same two real prefixes.
  for _=1,spec[3]or 0 do local _,nextQueue=Q.consume(r.encounters,'normal');r.encounters=nextQueue;r.floor=r.floor+1 end
  if spec[3]then eq(Q.peek(r.encounters,'normal'),'Writhing Mass')end
  if tier=='boss'then r.floor=50;r.bossInitialization={profile='source-history',bossList={'Time Eater','Time Eater'}}end
  assert(tier~='normal' or Q.peek(r.encounters,'normal')~='Orb Walker')
  local before=C.copy(r);local queue,cardRng=r.encounters,r.cardRng
  local ok,why=Run.startRoomCombat(r,tier);eq(ok,false);eq(why,'act_content_unavailable')
  same(r,before);eq(r.encounters,queue);eq(r.cardRng,cardRng)
 end
 local r=room('4');r.act,r.floor=4,54
 local before=C.copy(r);local ok,why=Run.startRoomCombat(r,'elite')
 eq(ok,false);eq(why,'act_content_unavailable');same(r,before)
end)

test('failed room setup publishes neither constructor draws nor consumed source queue',function()
 local r=room('4');local before=C.copy(r);local queue,misc=r.encounters,r.miscRng
 local original=C.new
 C.new=function(data,options)original(data,options);error('INJECTED_LATE_ORB_SETUP')end
 local called,ok,why=pcall(Run.startRoomCombat,r,'normal');C.new=original
 assert(called);eq(ok,false);eq(why,'combat_unavailable');same(r,before)
 eq(r.encounters,queue);eq(r.miscRng,misc)
end)

test('independent fixed-source HP and primary AI vectors preserve both streams',function()
 for _,v in ipairs({{'1',95,{'laser','claw','laser','claw','claw'}},
  {'42',95,{'claw','laser','laser','claw','laser'}},{'77',96,{'laser','laser','claw','laser','laser'}}})do
  local s=battle(v[1]);local e=s.enemies[1]
  eq(e.hp,v[2]);eq(s.monsterHpRng.counter,2)
  for i,id in ipairs(v[3])do
   eq(intent(e),id);eq(s.aiRng.counter,i)
   if i<#v[3]then AI.advance(s,e,function(state,max)return require('abyss_enemy_random').integer(state,max,C.random)end)end
  end
  eq(s.monsterHpRng.counter,2);eq(s.cardRandomRng.counter,0)
 end
end)

test('39 and 40 boundaries forbid three consecutive copies of either move',function()
 local s=battle();local e=s.enemies[1]
 AI.initialize(s,e,roll(39));eq(intent(e),'claw')
 AI.advance(s,e,roll(39));eq(intent(e),'claw')
 AI.advance(s,e,roll(39));eq(intent(e),'laser')
 AI.initialize(s,e,roll(40));eq(intent(e),'laser')
 AI.advance(s,e,roll(99));eq(intent(e),'laser')
 AI.advance(s,e,roll(40));eq(intent(e),'claw')
end)

test('round-end growth applies on the first round and attack amounts use prior Strength',function()
 local s=battle('1');local e=s.enemies[1];local hp=s.player.hp
 eq(intent(e),'laser');assert(C.endTurn(s));eq(s.player.hp,hp-10);eq(e.statuses.strength,3)
 eq(intent(e),'claw');hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-4-18)
 eq(e.statuses.strength,6);eq(e.statuses.generic_strength_up,3)
 eq(s.aiRng.counter,3);eq(s.monsterHpRng.counter,2)
 A.applyPower(s,e,'weak',2,s.player)
 local first=#s.events+1;A.endRound(s,e)
 eq(s.events[first].detail.status,'strength');eq(s.events[first+1].detail.status,'weak')
 eq(e.statuses.strength,9);eq(e.statuses.weak,1)
end)

test('laser creates separate default Burn instances and preserves the old draw top',function()
 for size=0,2 do
  local deck={};if size>0 then for _=1,5+size do deck[#deck+1]='strike'end end
  local s=battle('1',deck);local e,effects=laser(s);eq(#s.draw,size)
  local top,uid=s.draw[#s.draw],s.nextUid
  local counter,shuffle=s.cardRandomRng.counter,s.shuffleRng.counter
  C.applyEffects(s,effects,e,s.player)
  eq(#s.draw,size+1);eq(#s.discard,1);eq(s.nextUid,uid+2)
  local position=size==2 and 2 or 1 -- independent seed1 bounded-index projection
  local drawn,discarded=s.draw[position],s.discard[1]
  eq(drawn.cardId,'burn');eq(discarded.cardId,'burn');eq(drawn.uid,uid);eq(discarded.uid,uid+1)
  assert(drawn~=discarded and drawn.deckUid==nil and discarded.deckUid==nil)
  eq(drawn.upgraded,false);eq(discarded.upgraded,false)
  if top then eq(s.draw[#s.draw],top)end
  eq(s.cardRandomRng.counter,counter+(size>0 and 1 or 0));eq(s.shuffleRng.counter,shuffle)
  local a,b=s.events[#s.events-1],s.events[#s.events]
  eq(a.kind,'cards_created');eq(a.detail.pile,'draw');eq(a.detail.amount,1);eq(a.detail.source,e.id)
  eq(b.kind,'cards_created');eq(b.detail.pile,'discard');eq(b.detail.amount,1);eq(b.detail.source,e.id)
 end
end)

test('native Burn and shuffle lifecycle remains usable after the real laser',function()
 local s=battle('1');local hp=s.player.hp;local before=s.shuffleRng.counter
 assert(C.endTurn(s));eq(#s.hand,2);eq(s.hand[1].cardId,'burn');eq(s.hand[2].cardId,'burn')
 -- DrawCardAction's five-card request splits at both one-card piles. The
 -- second split still queues EmptyDeckShuffleAction for the empty discard.
 assert(s.hand[1].uid~=s.hand[2].uid);eq(s.cardRandomRng.counter,0);eq(s.shuffleRng.counter,before+2)
 hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-4-18)
end)

test('queued Burn and roll survive attacker death only while another enemy lives',function()
 for _,allies in ipairs({false,true})do
  local s=battle('1',{},allies and {'orb_walker','cultist'}or {'orb_walker'})
  local e=laser(s);A.applyPower(s,s.player,'thorns',100,s.player)
  local rng,uid=s.aiRng.counter,s.nextUid
  assert(C.endTurn(s));eq(e.hp,0);eq(e.statuses.strength,nil)
  local created=0;for _,event in ipairs(s.events)do
   if event.kind=='cards_created'and event.detail.cardId=='burn'then created=created+event.detail.amount end
  end
  eq(created,allies and 2 or 0);eq(s.nextUid,uid+(allies and 2 or 0))
  eq(s.aiRng.counter,rng+(allies and 2 or 0))
  if allies then eq(C.outcome(s),nil)else eq(C.outcome(s),'victory')end
 end
end)

test('both end-turn dispatchers roll back damage piles identities and source RNG on Burn failure',function()
 for _,experimental in ipairs({false,true})do
  local data=experimental and require('abyss_character_profiles').prepare(Data,'ironclad')or Data
  local s=battle('1',{'strike','strike','strike','strike','strike','strike','strike'},nil,data)
  eq(s.experimentalMechanics==true,experimental)
  laser(s)
  local before=C.copy(s);local hand,draw,discard,enemy,rng=s.hand,s.draw,s.discard,s.enemies[1],s.cardRandomRng
  local original=R.randomInt;local fired=false
  R.randomInt=function(stream,max)
   local value=original(stream,max)
   if stream==rng then fired=true;error('INJECTED_BURN_PLACEMENT')end
   return value
  end
  local ok,why=pcall(C.endTurn,s);R.randomInt=original
  assert(not ok and tostring(why):find('INJECTED_BURN_PLACEMENT',1,true) and fired)
  same(s,before);eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard);eq(s.enemies[1],enemy);eq(s.cardRandomRng,rng)
 end
end)

test('invalid generated UID fails atomically without duplicate Burn instances',function()
 local s=battle('1');laser(s);s.nextUid=9007199254740992
 local before=C.copy(s);local ok=pcall(C.endTurn,s)
 assert(not ok);same(s,before)
end)

test('real Host renders laser damage Burn destinations and the Growth status',function()
 local H=dofile('tests/lua/support/battle_action_fixture.lua')
 local F=H.F
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,Data,F.Presentation,'click',{seed=4,campaign=true,prologue=false,
  imageSource='static',color=function(red,green,blue,alpha)return{r=red,g=green,b=blue,a=alpha}end})
 assert(host:start())
 local r=host.run;r.act,r.floor,r.encounters=3,35,Q.new('4',3)
 assert(Run.startRoomCombat(r,'normal'));host:refresh()
 local ui,panel=host.battleUI,root:GetChild('battlePanel')
 local _,tap=H.controls(panel)
 local e=r.combat.enemies[1];eq(intent(e),'laser');eq(ui.run,r)
 local box=panel:GetChild('enemy1')
 assert(box.visible and box:GetChild('name').text==e.name);eq(box:GetChild('hp').text,string.format('%d/%d',e.hp,e.maxHp))
 eq(box:GetChild('intent').text,'10')
 assert(box:GetChild('intentBadge').visible,'laser must carry its Burn debuff badge')
 eq(box:GetChild('intentBadge').imageId,H.F.Theme.icon.intent.debuff)
 tap('enemy1',91)
 local detail=panel:GetChild('notice').text
 assert(detail:find(r.combat.catalog.cards.burn.name,1,true)and detail:find('抽牌堆',1,true)and detail:find('弃牌堆',1,true),detail)
 assert(not detail:find('未知',1,true),'known source Burn must not be shown as unknown')
 box:GetChild('statusRow'):GetChild('hit').click({touchId=92})
 assert(panel:GetChild('statusInfo').visible and ui.info.id==e.id and ui.info.index==1)
 local names={};for i=1,H.F.Theme.layout.statusInfo.rows do
  local part=panel:GetChild('statusInfo'):GetChild('name'..i)
  if part.visible then names[#names+1]=part.text end
 end
 assert(table.concat(names,' '):find('成长 3',1,true),'Growth amount remains readable')
end)

print('ACT3_ORB_WALKER '..passed..' passed; '..failed..' failed')
assert(failed==0,'Act3 Orb Walker regressions')
