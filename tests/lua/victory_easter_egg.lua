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
print('VICTORY_EASTER_EGG_PASS')
