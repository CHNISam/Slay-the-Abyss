package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,D=require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local base=C.new(D,{deck={'defend'},enemies={'cultist'},seed=42})
for _,advanced in ipairs({false,true})do
 for _,stat in ipairs({'strength','dexterity'})do
  for _,artifact in ipairs({false,true})do
   local ok,why=pcall(function()
    local s=C.copy(base);s.experimentalMechanics=advanced
    local field=stat=='strength'and 'temporaryStrength'or 'temporaryDexterity'
    local add=stat=='strength'and A.addTemporaryStrength or A.addTemporaryDexterity
    add(s.player,4,s);local gain=s.events[#s.events];eq(gain.frame.player[field],4)
    if artifact then A.applyPower(s,s.player,'artifact',1,s.player)end
    local start=#s.events;assert(C.endTurn(s));local removed
    for i=start+1,#s.events do local e=s.events[i]
     if e.kind=='status'and e.detail.target==s.player.id and
      (artifact and e.detail.blockedStatus==stat or not artifact and e.detail.status==stat and e.detail.amount==-4)then removed=e end
    end
    assert(removed);eq(s.player.statuses[stat],artifact and 4 or 0);eq(s.player[field],0)
    eq(removed.frame.player.statuses[stat],artifact and 4 or 0);eq(removed.frame.player[field],0)
    if artifact then eq(removed.frame.player.statuses.artifact,0)end
    for _,id in ipairs(removed.frame.player.powerOrder or {})do assert(id~='lose_'..stat)end
    eq(gain.frame.player.statuses[stat],4);eq(gain.frame.player[field],4)
    s.player[field]=99;eq(removed.frame.player[field],0)
   end)
   count=count+1;if not ok then failed=failed+1 end
   print((ok and 'PASS 'or 'FAIL ')..'temporary removal frame '..stat..' experimental='..tostring(advanced)..' artifact='..tostring(artifact)..(ok and ''or ': '..tostring(why)))
  end
 end
end
print('TEMPORARY_STAT_REMOVAL_FRAMES '..count..' groups; '..failed..' failed');assert(failed==0)
