-- Production-only, detached catalogue. No Run, inventory, RNG or UI is created.
local Copy=require('abyss_copy').copy
local Catalog=require('abyss_run_card_catalog')
local Combat=require('abyss_combat')
local Display=require('abyss_card_display')
local M={}
-- First/two-act events and the starter/fallback, outside the normal relic queues.
local specialRelics={'burning_blood','circlet','neows_lament','warped_tongs','spirit_poop',
 'red_mask','golden_idol','odd_mushroom','cultist_mask','face_of_cleric','gremlin_mask',
 'nloths_mask','ssserpent_head','nloths_gift','bloody_idol','mutagenic_strength',
 'necronomicon','enchiridion','nilrys_codex'}
-- Event specials (Acts 1/2), then dependencies created by obtainable cards.
local specialCards={apparition=true,bite=true,jax=true,ritual_dagger=true,necronomicurse=true,
 shiv=true,beta=true,omega=true,expunger=true,insight=true,miracle=true,safety=true,smite=true,
 through_violence=true,become_almighty=true,fame_and_fortune=true,live_forever=true}
local sharedCards={dazed=true,slimed=true,wound=true,burn=true,void=true,
 clumsy=true,curse_of_the_bell=true,decay=true,doubt=true,injury=true,normality=true,
 pain=true,parasite=true,regret=true,shame=true,writhe=true}
local regularRarities={common=true,uncommon=true,rare=true}
local colors={red=true,green=true,blue=true,purple=true,colorless=true}
local function admitted(card)
 if card.originalV4 then return false end
 if specialCards[card.id]or sharedCards[card.id]then return true end
 if card.type=='status'or card.type=='curse'then return false end
 return card.rarity=='basic'and card.color=='red'
  or regularRarities[card.rarity]and colors[card.color]==true
end
function M.new(source,presentation)
 local options={character='ironclad',campaignProfile='competition-two-act'}
 assert(require('abyss_run_admission').accepts(source,options),'compendium requires Production source')
 local data=Catalog.prepare(source,source,'ironclad')
 data=require('abyss_colorless_cards').withCards(data,true)
 Catalog.finishMetadata(data)
 local display=require('abyss_character_presentation').prepare(presentation,data)
 local index,rows={},{cards={},relics={},potions={}}
 -- Prismatic Shard admits regular foreign-color cards, not foreign starters.
 -- Generated specials, events, curses and statuses are inspected too.
 for _,card in ipairs(data.cards.cards)do
  if admitted(card)then index[card.id]=card end
 end
 -- This is the static definition lookup already used by deck previews, not a Run.
 local lookup={catalog={cards=index}}
 local function cardDetail(id,upgraded)
  if not index[id]then return nil end
  local instance={cardId=id,upgraded=false}
  if upgraded then
   if not Combat.canUpgrade(lookup,instance)then return nil end
   -- Inspect the printed first upgrade, not an in-combat upgrade operation
   -- (Blood for Blood's runtime upgrade rewrites persistent combat costs).
   instance.upgraded=true;instance.upgrades=1
  end
  local definition=Combat.cardDefinition(lookup,instance)
  return {id=id,name=display[id].name,text=Display.permanentText(display[id],definition,instance),
   type=definition.type,rarity=definition.rarity,color=definition.color,
   upgraded=instance.upgraded,definition=definition}
 end
 for id in pairs(index)do rows.cards[#rows.cards+1]=cardDetail(id,false)end
 -- Description/identity adapters read data only; no owned relic modifiers apply.
 local context={data=data}
 local seen={}
 local function relic(id)
  local def=assert(require('abyss_relic_rewards').definition(context,id),'missing compendium relic '..id)
  if seen[def.id]then return end;seen[def.id]=true
  rows.relics[#rows.relics+1]={id=def.id,name=require('abyss_relic_names').get(data,def.id),
   text=require('abyss_relic_text').describe(data,def.id),rarity=def.rarity,definition=Copy(def)}
 end
 for _,queue in pairs(data.relicSource.queues)do for _,id in ipairs(queue)do relic(id)end end
 for _,id in ipairs(specialRelics)do relic(id)end
 local potions={};for _,def in ipairs(data.potions.potions)do potions[def.id]=def end
 for _,entry in ipairs(require('abyss_potion_random').pool('ironclad'))do
  local def=assert(potions[entry.id],'missing compendium potion')
  rows.potions[#rows.potions+1]={id=def.id,name=def.name,rarity=entry.rarity,
   text=require('abyss_potion_text').describe(context,def.id),definition=Copy(def)}
 end
 for _,list in pairs(rows)do table.sort(list,function(a,b)return a.id<b.id end)end
 local result={character=options.character,campaignProfile=options.campaignProfile}
 function result.list(_,kind)return Copy(assert(rows[kind],'unknown compendium kind'))end
 function result.card(_,id,upgraded)return cardDetail(id,upgraded==true)end
 function result.detail(_,kind,id)
  for _,row in ipairs(assert(rows[kind],'unknown compendium kind'))do if row.id==id then return Copy(row)end end
 end
 return result
end
return M
