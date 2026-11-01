package.path='src/lua/?.lua;'..package.path
local function control(children)
 local c={children=children or {},visible=true}
 function c:GetChild(name)return self.children[name]end
 function c:SetVisible(value)self.visible=value end
 function c:SetAsLastSibling()self.raised=true end
 return c
end
local panel=control({status=control(),close=control(),thanks=control(),blocker=control()})
local button=control()
local root=control({victoryEasterEgg=panel,menuPanel=control({result=control({viewEasterEgg=button})})})
local allowed,created,ticks,pauses,destroyed,changed=false,0,0,0,0,{}
local state={phase='building',nextIndex=1,total=4500}
local owner={sync=function(_,mode,_,stopped)
 if mode=='node' and stopped then pauses=pauses+1 end
end,tick=function()ticks=ticks+1 end,status=function()return state end,onEngineDestroy=function()destroyed=destroyed+1 end}
local egg=require('abyss_victory_easter_egg').new(root,{canOpen=function()return allowed end,
 createArt=function()created=created+1;return owner end,onVisibility=function(value)changed[#changed+1]=value end})
assert(not egg:open() and created==0 and not panel.visible and not button.visible)
allowed=true;egg:refresh();assert(button.visible and created==0)
assert(egg:open() and created==1 and panel.visible and not button.visible)
assert(not egg:open() and created==1)
egg:tick();assert(ticks==1 and panel:GetChild('status').text:find('0%%'))
state.phase='ready';egg:tick();assert(panel:GetChild('status').text=='')
assert(egg:close() and pauses==1 and button.visible and not panel.visible)
egg:tick();assert(ticks==2,'closed artwork kept ticking')
assert(egg:open() and created==1,'cached artwork was recreated')
allowed=false;egg:refresh();assert(not egg:isOpen() and not button.visible and pauses==2)
egg:onEngineDestroy();assert(destroyed==1 and not egg:open())
assert(changed[1]==true and changed[2]==false and changed[3]==true and changed[4]==false)
-- Permanent release is distinct from the original close-and-cache contract above.
local function fresh(art)
 local p=control({status=control()});local b=control()
 local r=control({victoryEasterEgg=p,menuPanel=control({result=control({viewEasterEgg=b})})})
 local creates=0
 local e=require('abyss_victory_easter_egg').new(r,{canOpen=function()return true end,
  createArt=function()creates=creates+1;return art end})
 return e,p,b,r,function()return creates end
end
do
 local e,_,_,_,creates=fresh({})
 assert(e:release() and e:release() and not e:open() and creates()==0,'release before opening must stay lazy and permanently ended')
end
do
 local releases,engineEnds,work=0,0,0
 local art={sync=function()end,status=function()return {phase='ready'}end,
  tick=function()work=work+1 end,release=function()releases=releases+1;return true end,
  onEngineDestroy=function()engineEnds=engineEnds+1 end}
 local e,p,b= fresh(art)
 assert(e:open());assert(e:release() and releases==1 and not e:status().created and not p.visible and not b.visible)
 assert(e:release() and releases==1 and not e:open(),'successful release must be idempotent and cannot reopen')
 e:tick();e:onEngineDestroy();assert(engineEnds==0 and work==0,'released owner must not survive into engine teardown')
end
do
 local releases=0
 local art={sync=function()end,status=function()return {phase='ready'}end,
  release=function()
   releases=releases+1
   if releases==1 then return false,'retryable native release' end
   if releases==2 then error('thrown native release')end
   return true
  end,onEngineDestroy=function()error('successfully released owner retained')end}
 local e=fresh(art);assert(e:open())
 local ok,reason=pcall(e.release,e)
 assert(not ok and tostring(reason):find('retryable native release',1,true) and e:status().created and not e:open())
 ok,reason=pcall(e.release,e)
 assert(not ok and tostring(reason):find('thrown native release',1,true) and e:status().created,'thrown release must retain retry ownership')
 assert(e:release() and releases==3 and not e:status().created)
 assert(e:release() and releases==3);e:onEngineDestroy()
end
do
 local releases,engineEnds=0,0
 local art={sync=function()end,status=function()return {phase='ready'}end,
  release=function()releases=releases+1;return false,'engine will retire retained owner'end,
  onEngineDestroy=function()engineEnds=engineEnds+1 end}
 local e,_,_,r=fresh(art);assert(e:open());assert(not pcall(e.release,e) and e:status().created)
 local function dead(c)
  c.GetChild=function()error('read after engine destruction')end
  c.SetVisible=function()error('write after engine destruction')end
  c.SetAsLastSibling=function()error('raise after engine destruction')end
  for _,child in pairs(c.children)do dead(child)end
 end
 dead(r);e:onEngineDestroy();e:onEngineDestroy();e:tick()
 assert(engineEnds==1 and releases==1 and not e:status().created and not e:open(),'engine teardown must drop retained owner without native release or revival')
end
print('VICTORY_EASTER_EGG_PASS')
