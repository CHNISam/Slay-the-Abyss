local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Skin=require('abyss_card_skin')
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local faces={root:GetChild('battlePanel'):GetChild('card1'),
 root:GetChild('nodePanel'):GetChild('shopView'):GetChild('card1'),
 F.control(F.Templates.AbyssDeckCard):GetChild('face')}
local platform={color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
local function same(actual,expected,message)
 assert(actual.r==expected.r and actual.g==expected.g and actual.b==expected.b,message)
end
for _,mode in ipairs({'legacy','premium'})do
 Skin.configure(mode)
 for _,face in ipairs(faces)do
  for _,rarity in ipairs({'basic','common','uncommon','rare','curse'})do
   for _,kind in ipairs({'attack','skill','power'})do
   local definition={type=kind,rarity=rarity,cost=1}
   for _,selected in ipairs({false,true})do
    Skin.apply(face,definition,platform,{cost=1,baseCost=1,selected=selected})
    local well=face:GetChild('skin'):GetChild(kind):GetChild('well'):GetChild(({attack='upper',skill='vertical',power='base'})[kind]).imageColor
    assert(well.r<100 and well.g<100 and well.b<100,mode..' erased official fallback contrast')
    local palette=F.Theme.cardSkin.rarities[rarity]
    same(face:GetChild('nameRule').imageColor,palette[4],mode..' erased '..rarity..' name rarity')
    same(face:GetChild('skin'):GetChild('band1').imageColor,palette[2],mode..' erased '..rarity..' banner rarity')
    if not selected then same(face:GetChild('roundFrame'):GetChild('vertical').imageColor,palette[1],mode..' erased '..rarity..' frame rarity')end
   end
   end
  end
 end
end
Skin.configure(nil)
print('LUA_CARD_RARITY_SEMANTICS_PASS')
