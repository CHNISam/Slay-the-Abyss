-- Actual read-only Host controls; no native/desktop/UI acceptance claim.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local N=dofile('tests/lua/support/nemesis_fixture.lua')
local F=H.F
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local host=F.GameUI.new(root,N.D,F.Presentation,'click',{seed=1,campaign=true,prologue=false,
 imageSource='static',color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end})
assert(host:start())
local r=host.run;r.act,r.floor,r.encounters=3,35,N.Q.new('1',3)
assert(N.Run.startRoomCombat(r,'elite'));N.force(r.combat,'burn');host:refresh()
local panel=root:GetChild('battlePanel');local box=panel:GetChild('enemy1');local _,tap=H.controls(panel)
eq(box:GetChild('name').text,'天罚');eq(box:GetChild('hp').text,'185/185')
tap('enemy1',91)
local text=panel:GetChild('notice').text
assert(text:find('3',1,true)and text:find(r.combat.catalog.cards.burn.name,1,true)and text:find('弃牌堆',1,true),text)
assert(not text:find('未知',1,true),text)
assert(N.Run.endTurn(r));N.force(r.combat,'fire');host:refresh()
eq(box:GetChild('intent').text,'6×3')
box:GetChild('statusRow'):GetChild('hit').click({touchId=92})
local info=panel:GetChild('statusInfo');assert(info.visible)
local shown=false
for i=1,F.Theme.layout.statusInfo.rows do
 local name=info:GetChild('name'..i)
 if name.visible and name.text:find('无实体',1,true)then shown=true end
end
assert(shown,'monster Intangible must be named in the existing status panel')
print('NEMESIS_UI 1 groups; 0 failed')
