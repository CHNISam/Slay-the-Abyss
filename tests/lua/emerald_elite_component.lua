local E=require('abyss_emerald_elite')
local R=require('abyss_sts_random')
local Copy=require('abyss_copy').copy
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b,tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil)end
end
local function map()
 return {act=2,firstFloor=18,nodes={
  {id='late',floor=25,lane=1,type='elite'},
  {id='early_right',floor=23,lane=6,type='elite'},
  {id='normal',floor=22,lane=1,type='combat'},
  {id='early_left',floor=23,lane=2,type='elite'},
  {id='middle',floor=24,lane=4,type='elite'}}}
end
local eligible={endingUnlocked=true,emeraldOwned=false}
local ordered={'early_left','early_right','middle','late'}
local function context()
 return {endingUnlocked=true,emeraldOwned=false,marked=true,roomClass='elite',outcome='victory',smoked=false,
  runSeed='42',act=2,floor=23,nodeId='early_left',sourceEncounter='Slavers',combatGeneration=3,phase='reward'}
end
do
 for _,v in ipairs(EMERALD_VECTORS.cases)do
  local m=map();if v.eliteCount==1 then m.nodes={m.nodes[1]}end
  local before=Copy(m);local rng=R.restore(v.before)
  local selected,nextRng=E.select(m,rng,eligible)
  assert(selected.nodeId==(v.eliteCount==1 and 'late'or ordered[v.selectionIndex+1]))
  same(R.snapshot(nextRng),v.afterSelection);same(R.snapshot(rng),v.before);same(m,before)
  local boost,after=E.prepare(selected,nextRng)
  assert(boost.roll==v.roll);same(R.snapshot(after),v.afterBoost)
  assert(R.randomInt(after,99)==v.next99);same(R.snapshot(after),v.continuation)
 end
end
do
 for _,c in ipairs({{endingUnlocked=false,emeraldOwned=false},{endingUnlocked=true,emeraldOwned=true}})do
  local rng=R.fromSeed('42');local before=R.snapshot(rng)
  local selected,after=E.select(map(),rng,c);assert(selected==nil)
  same(R.snapshot(after),before);same(R.snapshot(rng),before)
 end
 local m=map();m.act=4
 local selected,after=E.select(m,R.fromSeed('42'),eligible);assert(not selected and after)
end
do
 local m=map();m.nodes={m.nodes[3]};local rng=R.fromSeed('42');local before=R.snapshot(rng)
 local selected,after,why=E.select(m,rng,eligible)
 assert(not selected and not after and why=='no_elite_nodes');same(R.snapshot(rng),before)
 m=map();m.nodes[2].floor,m.nodes[2].lane=m.nodes[1].floor,m.nodes[1].lane
 assert(not E.select(m,rng,eligible));same(R.snapshot(rng),before)
 m={act=false,nodes={{id='false_act',x=0,y=5,type='elite'}}}
 assert(not E.select(m,rng,eligible),'false act must not default to Act1')
end
do
 local m={act=1,nodes={{id='right',x=5,y=8,type='elite'},{id='left',x=1,y=8,type='elite'}}}
 local selected=E.select(m,R.fromSeed('1'),eligible)
 assert(selected and selected.x>=0 and selected.y==8)
 local bad=Copy(selected);bad.roll=0;assert(not E.prepare(bad,R.fromSeed('1')))
end
do
 for act=1,3 do for roll=0,3 do
  local boost={version=1,act=act,nodeId='n',x=1,y=5,roll=roll}
  local actors={{id='a',hp=61,maxHp=61},{id='b',hp=62,maxHp=62}};local calls={}
  local ok=E.apply(actors,boost,{
   applyPower=function(actor,id,n)calls[#calls+1]={actor.id,id,n};return true end,
   increaseMaxHp=function(actor,n)calls[#calls+1]={actor.id,'maxHp',n};return true end})
  assert(ok and #calls==2)
  local id=({'strength','maxHp','metallicize','regenerate_monster'})[roll+1]
  assert(calls[1][2]==id)
  local n=roll==0 and act+1 or roll==1 and 15 or roll==2 and act*2+2 or act*2+1
  assert(calls[1][3]==n);if roll==1 then assert(calls[2][3]==16)end
  assert(actors[1].hp==61,'callbacks own all actual battle mutation')
 end end
 for _,v in ipairs(EMERALD_VECTORS.health)do
  local amount
  assert(E.apply({{id='a',hp=v.maxHp,maxHp=v.maxHp}},
   {version=1,act=1,nodeId='n',x=0,y=5,roll=1},
   {increaseMaxHp=function(_,n)amount=n;return true end}))
  assert(amount==v.increase)
 end
end
do
 local actors={{id='a',hp=10,maxHp=10},{id='b',hp=20,maxHp=20}};local calls=0
 local boost={version=1,act=1,nodeId='n',x=0,y=5,roll=0}
 actors[2].hp=-1
 assert(not E.apply(actors,boost,{applyPower=function()calls=calls+1;return true end}));assert(calls==0)
 actors[2].hp=20
 local ok,why=E.apply(actors,boost,{applyPower=function()return false,'callback_rejected'end})
 assert(not ok and why=='callback_rejected')
 assert(not E.apply(actors,boost,{}))
 boost.roll=1
 assert(not E.apply(actors,boost,{applyPower=function()calls=calls+1;return true end}),
  'max HP action must not fall back to the power callback')
 assert(calls==0)
end
do
 local c=context();local offer=assert(E.rewardOwner(c,2));local relics={{id='base'},{id='black_star'}}
 assert(offer.type=='EMERALD_KEY'and not offer.relicLink and E.canClaim(offer,c))
 local obtains=0
 assert(E.claim(offer,c,function()obtains=obtains+1;return true end))
 assert(offer.claimed and obtains==1 and #relics==2)
 assert(not E.claim(offer,c,function()obtains=obtains+1;return true end));assert(obtains==1)
end
do
 local c=context();local offer=assert(E.rewardOwner(c,1))
 for _,pair in ipairs({{'endingUnlocked',false},{'emeraldOwned',true},{'marked',false},
  {'roomClass','event'},{'outcome','defeat'},{'smoked',true},{'runSeed','43'},{'act',3},
  {'floor',24},{'nodeId','other'},{'sourceEncounter','Book of Stabbing'},{'combatGeneration',4},{'phase','map'}})do
  local bad=Copy(c);bad[pair[1]]=pair[2];assert(not E.canClaim(offer,bad),pair[1])
 end
 assert(not E.rewardOwner(c,0));c.smoked=true;assert(not E.rewardOwner(c,1));c.smoked=false
 local ok,why=E.claim(offer,c,function()return false,'obtain_failed'end)
 assert(not ok and why=='obtain_failed'and not offer.claimed)
 local changed=Copy(offer);changed.relicLink={};assert(not E.canClaim(changed,c))
 assert(not E.claim(offer,c,function()return 'truthy'end));assert(not offer.claimed)
end
print('EMERALD_COMPONENT 8 groups; 0 failed; integration NOT_RUN')
