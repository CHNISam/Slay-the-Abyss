-- Shared only by the two phase-four presentation fixtures; no test selection.
local Profiles=require('abyss_character_profiles')
local Data=require('abyss_data')
local Triggers=require('abyss_card_triggers')
local function has(d,id)for _,c in ipairs(d.cards.cards)do if c.id==id then return true end end end
local function prepared(id,source)
 local d=Profiles.prepare(source or Data,id)
 if id=='silent' and not has(d,'bane') then d=require('abyss_silent_attack_cards').withCardDefinitions(d) end
 if id~='watcher' and not has(d,({ironclad='rage',silent='after_image',defect='heat_sinks'})[id]) then d=Triggers.withCards(d,id) end
 local add=({ironclad={'wild_strike','abyss_warrior_status_cards','withCards'},silent={'piercing_wail','abyss_silent_tactics_cards','withCardDefinitions'},defect={'claw','abyss_defect_engine_cards','withCards'},watcher={'battle_hymn','abyss_watcher_flow_cards','withCards'}})[id]
 if not has(d,add[1])then d=require(add[2])[add[3]](d)end
 return d
end
return prepared
