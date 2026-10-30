-- Conservative layout budgets, not native screenshot certification.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local D,C,T=require('abyss_card_display'),require('abyss_combat'),require('abyss_theme')
local data,P=require('abyss_data'),require('abyss_presentation')
local s=C.new(data,{deck={},enemies={'cultist'},seed=1})
-- Preserve the complete acb09e467967ab41a53bc8b313769cc4a77a85e3 90-card catalog;
-- #377 adds exactly one Necronomicurse, tested at both original upgrade states.
local oldCatalogIds="anger,armaments,barricade,bash,battle_trance,berserk,blood_for_blood,bloodletting,bludgeon,body_slam,brutality,burn,burning_pact,carnage,clash,cleave,clothesline,clumsy,combust,corruption,curse_of_the_bell,dark_embrace,dazed,decay,defend,demon_form,disarm,double_tap,doubt,dropkick,dual_wield,entrench,evolve,exhume,feed,feel_no_pain,fiend_fire,fire_breathing,flame_barrier,flex,ghostly_armor,havoc,headbutt,heavy_blade,hemokinesis,immolate,impervious,infernal_blade,inflame,injury,intimidate,iron_wave,juggernaut,limit_break,metallicize,normality,offering,pain,parasite,perfected_strike,pommel_strike,power_through,pummel,rage,rampage,reaper,reckless_charge,regret,rupture,searing_blow,second_wind,seeing_red,sentinel,sever_soul,shame,shockwave,shrug_it_off,slimed,spot_weakness,strike,sword_boomerang,thunderclap,true_grit,twin_strike,uppercut,warcry,whirlwind,wild_strike,wound,writhe"
local oldIds,added={},0
for _,definition in ipairs(data.cards.cards)do
 if definition.id=='necronomicurse'then added=added+1 else oldIds[#oldIds+1]=definition.id end
end
table.sort(oldIds)
assert(#oldIds==90 and table.concat(oldIds,',')==oldCatalogIds,'old complete 90-card ID set changed')
assert(added==1,'expected exactly one new Necronomicurse')
local n,oldVariants,newVariants=0,0,0
for _,definition in ipairs(data.cards.cards)do
 for _,up in ipairs({false,true})do
  local display=P[definition.id]
  local title,font,fits=D.title(display.name,up)
  assert(fits,'title does not fit: '..definition.id)
  assert(title:gsub('\n',' ')==display.name..(up and '＋' or ''),'title lost or renamed characters')
  assert(font>=T.font.minimum and font<=T.font.cardName)
  for _,buff in ipairs({0,999})do
   local c={uid=1,cardId=definition.id,upgraded=up};s.hand={c};s.player.block=999
   s.player.statuses={strength=buff,dexterity=buff,weak=buff>0 and 1 or nil,frail=buff>0 and 1 or nil}
   local card=C.cardDefinition(s,c);local live=up and display.upgradeCombatText or display.combatText
   local text=up and display.upgradeText or display.text
   if live then text=D.format(live,card,C.cardPreview(s,c,1),T.color)end
   if definition.id=='body_slam' then text=text..'（当前 1498 点）' end
   local body={};assert(D.writeBody(body,text),'body does not fit: '..definition.id..(up and '+' or '')..' '..text)
   assert(body.text==text,'body was truncated');assert(body.fontSize>=T.font.minimum)
  end
  n=n+1
  if definition.id=='necronomicurse'then newVariants=newVariants+1 else oldVariants=oldVariants+1 end
 end
end
assert(oldVariants==180 and newVariants==2 and n==180+2)
print('Card text: 180 original + 2 Necronomicurse class/status/curse variants retain full names and text at approved font bounds; native visual verification still required.')
