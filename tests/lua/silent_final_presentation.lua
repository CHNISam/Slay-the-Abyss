package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local A=require('abyss_actor');local Profiles=require('abyss_character_profiles')
local data=Profiles.prepare(require('abyss_data'),'silent')
local Display=require('abyss_card_display');local presentation=require('abyss_character_presentation').prepare({},data)
local s=C.new(data,{deck={},enemies={'jaw_worm'},seed=42,experimental=true,enableStances=true})
local rendered=0
for _,d in ipairs(data.cards.cards)do if d.color=='green'and d.rarity~='special'and d.type~='curse'and d.type~='status'then
 for _,up in ipairs({false,true})do
  local c={cardId=d.id,upgraded=up};local live=C.cardDefinition(s,c);local p=assert(presentation[d.id])
  assert(p.name:find('[\128-\255]'),d.id)
  local text=Display.permanentText(p,live,c);assert(text~=''and not text:find('{effects',1,true),d.id)
  local dynamic=up and p.upgradeCombatText or p.combatText
  if dynamic then local formatted=Display.format(dynamic,live,C.cardPreview(s,c,1),require('abyss_theme').color);assert(not formatted:find('{effects',1,true),d.id)end
  if d.id=='wraith_form'then assert(text:find(up and '3回合无实体'or '2回合无实体',1,true));assert(text:find('敏捷',1,true))end
  if d.id=='well_laid_plans'then assert(text:find(up and '2张'or '1张',1,true))end
  rendered=rendered+1
 end
end end
assert(rendered==150)
A.applyPower(s,s.player,'wraith_form',-2,s.player)
A.applyPower(s,s.player,'nightmare',3,s.player);s.player.nightmareCardName='精巧刺击'
for _,view in ipairs(A.statusView(s.player))do
 if view.id=='wraith_form'then assert(view.description:find('失去2点敏捷',1,true))
 elseif view.id=='nightmare'then assert(view.description:find('3张精巧刺击',1,true))end
end
local Potions=require('abyss_potion_text');local owner={data=data,relics={'SacredBark'}}
assert(Potions.describe(owner,'cunning_potion'):find('6张小刀+',1,true))
assert(Potions.describe(owner,'ghost_in_a_jar'):find('2回合无实体',1,true))
print('ok Silent 150 actual display variants, dynamic power details and Bark potion descriptions')
