local Run,C,D,Q,R,A,W,H=require('abyss_run'),require('abyss_combat'),require('abyss_data'),
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
