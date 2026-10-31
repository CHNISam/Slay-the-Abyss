local A=dofile('tests/lua/support/two_act_selection_audit.lua')
local Pending=require('abyss_relic_pending')
local count=0
for _,id in ipairs({'Bottled Flame','Bottled Lightning','Bottled Tornado','DollysMirror','Orrery','Cauldron',
 'Astrolabe','Empty Cage','Calling Bell','Tiny House',"Pandora's Box"})do
 local r,map=A.room('beggar',2)
 local ok,why=A.H.Run.obtainRelic(r,id);assert(ok,id..': '..tostring(why))
 local ui,_,_,click=A.ui(r,map)
 local clicks=A.resolvePending(r,ui,click,id)
 assert(not Pending.owner(r),id..' has no selection exit')
 if id~="Pandora's Box"then assert(clicks>0,id..' did not expose its choice UI')end
 count=count+1;print('PASS pending '..id)
end
assert(count==11)
print('TWO_ACT_SELECTION_PENDING_PASS '..count..' '..A.clicks)
