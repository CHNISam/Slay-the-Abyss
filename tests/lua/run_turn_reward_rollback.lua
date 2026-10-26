-- Public-command component fixture. Cards/potion are obtained through Run;
-- the source Cultist's52 HP, energy costs and random streams are unchanged.
local Run=require('abyss_run')
local P=require('abyss_potion_rewards')
local D=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end
 for k in pairs(b)do assert(a[k]~=nil,'unexpected field '..tostring(k))end
end
local function unchanged(root)
 local objects={}
 local function remember(value)
  if type(value)~='table'or objects[value]then return end
  local fields={};objects[value]=fields
  for key,entry in pairs(value)do fields[key]=entry;remember(key);remember(entry)end
 end
 remember(root)
 return function()
  for object,fields in pairs(objects)do
   for key,value in pairs(fields)do eq(object[key],value)end
   for key in pairs(object)do assert(fields[key]~=nil,'new field survived rollback: '..tostring(key))end
  end
 end
end
local function play(run,id)
 local cost=({omega=3,well_laid_plans=1,juggernaut=2,feel_no_pain=1,bludgeon=3,hemokinesis=1,discovery=1})[id]
 while run.combat.energy<cost do
  assert(Run.obtainPotion(run,'energy_potion'));assert(Run.usePotion(run,1))
 end
 for _,card in ipairs(run.combat.hand)do if card.cardId==id then
  assert(Run.play(run,card.uid,(id=='bludgeon'or id=='hemokinesis')and 1 or nil));return
 end end
 error('missing real card '..id)
end
local function fresh(kind)
 local run=Run.new(D,'42',{character='watcher',experimental=true})
 local uids={};for _,card in ipairs(run.deck)do uids[#uids+1]=card.uid end
 for _,uid in ipairs(uids)do assert(Run.removeCard(run,uid))end
 local ids=kind=='turn'and {'omega','well_laid_plans','defend_purple'}
  or {'juggernaut','feel_no_pain','discovery','bludgeon','hemokinesis'}
 for _,id in ipairs(ids)do assert(Run.obtainCard(run,id,id=='omega'and{upgraded=true}or nil))end
 assert(Run.obtainPotion(run,'energy_potion'));assert(Run.startRoomCombat(run,'normal'))
 eq(run.combat.enemies[1].hp,52);assert(Run.usePotion(run,1))
 if kind=='turn'then
  play(run,'omega');play(run,'well_laid_plans')
  return run,function()return Run.endTurn(run)end
 end
 play(run,'juggernaut');play(run,'feel_no_pain');play(run,'bludgeon');play(run,'hemokinesis')
 eq(run.combat.enemies[1].hp,5) --52 -32 -15, through actual attacks.
 play(run,'discovery')
 local pending=assert(run.combat.pendingChoice)
 return run,function()return Run.chooseCard(run,pending.token,1)end
end
local passed,failed=0,0
for _,kind in ipairs({'turn','choice'})do
 local ok,why=pcall(function()
  local run,command=fresh(kind);local verify=unchanged(run)
  eq(Run.chooseCard(run,2147483647,0),false);verify()
  local original=P.prepare;local reached=false
  P.prepare=function(...)
   original(...);reached=true;error('INJECTED_AFTER_REAL_REWARD_PREPARE',0)
  end
  local called,reason=pcall(command);P.prepare=original
  assert(reached,'must reach real late reward preparation')
  assert(not called and tostring(reason):find('INJECTED_AFTER_REAL_REWARD_PREPARE',1,true),'preserve thrown failure')
  verify();eq(run.phase,'combat');eq(run.combat.phase,'player');eq(run.combat.enemies[1].hp,kind=='turn'and 52 or 5)
  assert(command());eq(run.phase,'reward');eq(run.combat.phase,'victory');eq(run.combat.enemies[1].hp,0)
  eq(run.combat.pendingChoice,nil);eq(run.combat.pendingPlay,nil);eq(run.combat.actionQueue,nil)
  local control,finish=fresh(kind);assert(finish());same(run,control)
 end)
 if ok then passed=passed+1 else failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..'public Run '..kind..' late reward restores complete graph and retries once'..(ok and ''or ': '..tostring(why)))
end
print('RUN_TURN_REWARD_ROLLBACK '..passed..' passed; '..failed..' failed')
assert(failed==0)
