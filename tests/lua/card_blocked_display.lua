local Theme=require('abyss_theme')
local Combat=require('abyss_combat')
local Skin=require('abyss_card_skin')
local definitions={};for _,definition in ipairs(CARD_BLOCKED_DEFS)do definitions[definition.id]=definition end
local function control(spec)
 local c={children={},visible=spec.visible~=false,text='',size=spec.size,x=(spec.position or {})[1],y=(spec.position or {})[2]}
 function c:GetChild(name)return assert(self.children[name],name)end
 function c:SetVisible(value)self.visible=value end
 function c:SetLocalScale(x,y,z)self.localScaleX,self.localScaleY=x,y end
 function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
 function c:SetSizeDelta(w,h)self.size={w,h}end
 function c:SetAsLastSibling()end
 for _,child in ipairs(spec.children or {})do c.children[child.name]=control(child)end
 return c
end
local function face()return control({children=CARD_BLOCKED_FACE})end
local platform={color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
local function eqColor(actual,expected,label)
 for _,key in ipairs({'r','g','b'})do assert(actual[key]==expected[key],label..' '..key)end
end
local state={phase='player',energy=3,hand={{uid=1,cardId='strike'}},catalog={cards=definitions},player={statuses={entangled=1}},enemies={{hp=10}},draw={},discard={},exhaust={}}
local original=Combat.copy(state)
local ok,reason=Combat.canPlay(state,1,1);assert(not ok and reason=='entangled')
local box=face();box:GetChild('cost').text='1'
Skin.apply(box,definitions.strike,platform,{dim=true,blockReason=reason,cost=1,baseCost=1})
eqColor(box:GetChild('cost').fontColor,Theme.cardSkin.roles.traveler.accent,'non-energy refusal must preserve cost accent')
assert(box:GetChild('blockedReason').text=='本回合不能打出')
for _,name in ipairs({'blockedVeil','blockedPill','blockedLock','blockedReason'})do assert(box:GetChild(name).visible,name)end
state.hand[1].cardId='defend';state.player.statuses.entangled=nil;state.energy=0
ok,reason=Combat.canPlay(state,1,1);assert(not ok and reason=='insufficient_energy')
Skin.apply(box,definitions.defend,platform,{dim=true,blockReason=reason,cost=1,baseCost=1})
eqColor(box:GetChild('cost').fontColor,Theme.cardSkin.costTone.up,'energy refusal cost tone')
assert(box:GetChild('blockedReason').text=='能量不足')
state.phase='enemy';ok,reason=Combat.canPlay(state,1,1);assert(not ok and reason=='not_player_turn')
Skin.apply(box,definitions.defend,platform,{dim=true,blockReason=reason,cost=0,baseCost=1})
eqColor(box:GetChild('cost').fontColor,Theme.cardSkin.costTone.down,'non-energy refusal retains real discount')
-- Non-combat refusal is not an energy failure, even when the whole card dims.
Skin.apply(box,definitions.defend,platform,{dim=true,reason='金币不足',cost=1,baseCost=1})
eqColor(box:GetChild('cost').fontColor,Theme.cardSkin.roles.traveler.accent,'shop refusal is not insufficient energy')
-- Existing node stamps/veils own these states. Do not paint a second shade or
-- a capsule behind the later stampPlate; reusing the same face must restore it.
Skin.apply(box,definitions.defend,platform,{dim=true,overlayCovered=true,reason='已售出',cost=1,baseCost=1})
for _,name in ipairs({'blockedVeil','blockedPill','blockedLock','blockedReason'})do
 assert(not box:GetChild(name).visible,'existing node overlay must suppress '..name)
end
eqColor(box:GetChild('cost').fontColor,Theme.cardSkin.roles.traveler.accent,'sold state is not insufficient energy')
Skin.apply(box,definitions.defend,platform,{dim=true,overlayCovered=false,reason='金币不足',cost=1,baseCost=1})
for _,name in ipairs({'blockedVeil','blockedPill','blockedLock','blockedReason'})do
 assert(box:GetChild(name).visible,'unstamped refusal must restore '..name)
end
assert(box:GetChild('blockedReason').text=='金币不足','recycled reason must not retain the sold stamp')
eqColor(box:GetChild('cost').fontColor,Theme.cardSkin.roles.traveler.accent,'recycled shop refusal is not insufficient energy')
Skin.apply(box,definitions.defend,{}, {dim=true,blockReason='entangled',cost=1,baseCost=1})
Skin.apply(box,definitions.defend,platform,{dim=false,cost=1,baseCost=1})
for _,name in ipairs({'blockedVeil','blockedPill','blockedLock','blockedReason'})do assert(not box:GetChild(name).visible,'recycled '..name)end
assert(state.energy==0 and state.hand[1].uid==1 and original.energy==3,'presentation did not spend energy or remove cards')

-- Exercise the real battle card adapter and actual Combat.canPlay return value.
package.loaded.abyss_card_display={writeTitle=function(c,name)c.text=name end,writeBody=function(c,text)c.text=text end,
 combatText=function(_,definition)return definition.text end,writeArt=function()end,writeNativeArt=function()return false end,clearNativeArt=function()end}
Combat.cardPreview=function()return {}end
local boxes={};for i=1,10 do boxes['card'..i]=face()end
local view={target=1,cardPositions={},run={combat=state},canvasWidth=1280,canvasHeight=720}
local adapter=require('abyss_battle_card_view').new(view,{child=function(name)return boxes[name]end,show=function()end,
 ink=function(c,color)c.fontColor=color end,tint=function(c,color)c.imageColor=color end,picture=function()end,
 platform=platform,placeCard=function()return {0,0}end})
state.phase='player'
adapter.renderCards({cards={cards=CARD_BLOCKED_DEFS}},{defend={name='防御',text='获得 5 点格挡。'}},state,true,true,false,false)
assert(boxes.card1:GetChild('blockedReason').text=='能量不足','adapter must forward actual core refusal')
eqColor(boxes.card1:GetChild('cost').fontColor,Theme.cardSkin.costTone.up,'adapter energy tone')
state.energy=3
adapter.renderCards({cards={cards=CARD_BLOCKED_DEFS}},{defend={name='防御',text='获得 5 点格挡。'}},state,true,true,false,false)
assert(not boxes.card1:GetChild('blockedVeil').visible,'real adapter clears the previous blocked state')
assert(state.energy==3 and #state.hand==1,'render is read-only')
print('CARD_BLOCKED_DISPLAY_PASS real core reasons, adapter forwarding, cost tone, optional color, recycled overlays')
