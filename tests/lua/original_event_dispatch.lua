-- Source-directory/dispatcher coverage only. This explicitly does NOT certify
-- every effect dependency, mandatory source grid or natural/device execution.
local Pool=require('abyss_event_pool')
local Act1,Act2=require('abyss_act1_events'),require('abyss_act2_events')
local legacy={match_game=true,cleric=true,purifier=true,goop=true,upgrade_shrine=true,golden_wing=true,shining_light=true,golden_shrine=true,living_wall=true,fountain=true}
local seen,count={},0
for act=1,2 do
 local pool=Pool.new('full',false,act)
 local eligible=Pool.eligible(pool,{act=act,floor=act==1 and 7 or 24,gold=1000,hp=80,relicCount=3,cursed=true,elapsedSeconds=900})
 for _,group in ipairs({eligible.act,eligible.rare})do for _,original in ipairs(group)do
  local id=assert(Pool.contentId[original],'missing original event mapping: '..original)
  assert(legacy[id]or Act1.ids[id]or Act2.ids[id],'missing original event dispatcher: '..id)
  if not seen[original]then seen[original]=true;count=count+1 end
 end end
end
assert(count==42,'complete first-two-act source event identity set')
assert(not seen.SecretPortal and not seen.NoteForYourself,'unavailable history/later-act predicate bypassed')
local legacySeven=Pool.new('restricted-seven',false,1)
assert(#legacySeven.act==4 and #legacySeven.shrine==3 and #legacySeven.once==0)
assert(not pcall(Pool.new,'restricted-seven',false,2),'legacy Act1 mode broadened')
print('ORIGINAL_EVENT_DISPATCH_PASS 42 identities; real effect dependencies NOT_CERTIFIED')
