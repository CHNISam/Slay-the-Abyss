-- AbstractPlayer.loseRelic at STS319009d5. Caller owns the Run transaction.
-- Removal is not the inverse of onEquip: PotionBelt/HP/gold gains remain.
local M={}
local bottles={bottled_flame='inBottleFlame',bottled_lightning='inBottleLightning',bottled_tornado='inBottleTornado'}
-- These exact source classes implement onUnequip: --energyMaster. The
-- trigger category is NOT an inverse-equip contract (notably SlaversCollar).
local energyUnequip={sozu=true,coffee_dripper=true,fusion_hammer=true}
local combatObjectFields={horn_cleat='hornCleatGrayscale',necronomicon='necronomiconActivated'}
function M.unbottle(run,id)
 local field=bottles[id];if not field then return true end
 local selected
 for _,card in ipairs(run.deck)do
  if card[field]then
   if selected then return false,'bottled_card_identity_unavailable'end
   selected=card
  end
 end
 -- The source checks that relic.card is still a specific master-deck object.
 -- A removed card (or a relic never assigned a card) has no flag to clear.
 if selected then selected[field]=false end
 return true
end
function M.onUnequip(run,id)
 local ok,why=M.unbottle(run,id);if not ok then return false,why end
 local battle=run.phase=='combat'and run.combat
 -- The source effect belongs INSIDE onUnequip, while both permanent and
 -- active-battle ownership still exist, not after the callback has returned.
 if battle and energyUnequip[id]then
  local value=battle.rules.player.energyPerTurn-1
  if value<0 then return false,'invalid_relic_energy'end
  battle.rules.player.energyPerTurn=value
 end
 return true
end
local function clearCounter(owner,id,source,held)
 local counters=owner.relicCounters
 if counters then counters[id],counters[source],counters[held]=nil,nil,nil end
end
local function retireCounter(run,definition,held)
 clearCounter(run,definition.id,definition.sourceId or definition.id,held)
 -- TinyChest's object counter is represented in the validated unknown-room
 -- aggregate. No object remains; retain its schema's neutral default, not
 -- the removed object's progress (the aggregate cannot represent nil).
 if definition.id=='tiny_chest'and run.unknown and run.unknown.chances then run.unknown.chances.tinyChestCount=0 end
end
local function retireCombatObject(battle,id)
 local field=combatObjectFields[id]
 if field and battle.relicCombat then battle.relicCombat[field]=nil end
end
local function activeBattle(run,definition,api)
 local battle=run.phase=='combat'and run.combat
 if not battle then return true end
 if definition.trigger=='turn_start'and not energyUnequip[definition.id]then
  return false,'active_relic_unequip_content_unavailable'
 end
 for i=#(battle.relics or {}),1,-1 do
  if api.localId(battle.relics[i])==definition.id then table.remove(battle.relics,i)end
 end
 clearCounter(battle,definition.id,definition.sourceId or definition.id,definition.id)
 retireCombatObject(battle,definition.id)
 return true
end
function M.lose(run,id,api)
 if type(id)~='string'or id==''then return false,'invalid_relic'end
 local definition=api.definition(run,id)
 if not definition then
  for _,owned in ipairs(run.relics)do if owned==id then return false,'relic_content_unavailable'end end
  return false,'relic_not_owned'
 end
 local position,held
 for i,owned in ipairs(run.relics)do
  local actual=api.definition(run,owned)
  if actual and actual.id==definition.id then
   -- Source dispatches while the object is owned and removes its last match.
   local ok,why=api.onUnequip(run,definition.id);if ok==false then return false,why end
   position,held=i,owned
  end
 end
 if not position then return false,'relic_not_owned'end
 local ok,why=activeBattle(run,definition,api);if not ok then return false,why end
 table.remove(run.relics,position)
 retireCounter(run,definition,held)
 return true,definition.id
end
return M
