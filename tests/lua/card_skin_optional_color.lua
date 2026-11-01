-- NodeUI deliberately permits no Color constructor: visibility and text still work.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Skin=require('abyss_card_skin')
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local face=root:GetChild('battlePanel'):GetChild('card1')
local original={}
local function remember(control)
 original[control]={imageColor=control.imageColor,fontColor=control.fontColor}
 for _,child in pairs(control.children)do remember(child)end
end
remember(face)
local platform={imageSource='static'} -- Do not hide the optional-constructor regression with a fake Color.
for _,case in ipairs({
 {kind='attack',cost=1,base=2,direction='↓'},
 {kind='skill',cost=2,base=1,direction='↑',dim=true},
 {kind='power',cost=-2,base=-2,direction=''},
 {kind='attack',cost=1,base=1,direction=''},
})do
 local changed=case.cost>=0 and case.cost~=case.base
 Skin.apply(face,{type=case.kind,rarity='common',cost=case.cost},platform,
  {cost=case.cost,baseCost=case.base,dim=case.dim,reason='不能选择'})
 for _,kind in ipairs({'attack','skill','power'})do
  assert(face:GetChild('skin'):GetChild(kind).visible==(kind==case.kind),'type window must update without Color')
 end
 for _,name in ipairs({'costCore','costDisc','cost'})do
  assert(face:GetChild(name).visible==(case.cost~=-2),'absent cost must remain hidden without Color')
 end
 assert(face:GetChild('costHalo').visible==changed)
 assert(face:GetChild('costDirection').visible==changed)
 assert(face:GetChild('costDirection').text==case.direction)
 assert(face:GetChild('blockedReason').visible==(case.dim==true))
 assert(face:GetChild('blockedReason').text=='不能选择')
 Skin.tick(face,.1)
 for control,colours in pairs(original)do
  assert(control.imageColor==colours.imageColor and control.fontColor==colours.fontColor,
   'missing Color must preserve the generated appearance, not assign substitute colour values')
 end
end
print('CARD_SKIN_OPTIONAL_COLOR_PASS type windows, absent/changed costs, reasons, recycled state and no substitute colours')
