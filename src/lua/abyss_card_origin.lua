-- Bounded, same-run provenance. Observe committed permanent entities only;
-- previews, combat copies and rejected transactions never publish a receipt.
local M={}
function M.state(card)
 return {upgraded=card.upgraded==true,upgrades=card.upgrades or (card.upgraded and 1 or 0)}
end
function M.context(run)
 local flow=run.nodeFlow
 return {kind=flow and flow.type or run.phase or 'unknown',eventId=flow and flow.event and flow.event.id,
  floor=run.floor,act=run.act or 1}
end
function M.record(run,card,before,kind,source)
 card.lastUpgradeOrigin={uid=card.uid,cardId=card.cardId,kind=kind,source=source or M.context(run),
  before=before,after=M.state(card)}
end
function M.observe(run,before)
 local old={};for _,card in ipairs(before.deck or {})do old[card.uid]=card end
 local acquired={}
 local receipt=run.lastRelicObtain
 if receipt and (not before.lastRelicObtain or receipt.sequence~=before.lastRelicObtain.sequence)then
  for _,change in ipairs(receipt.upgrades or {})do acquired[change.uid]=change end
 end
 for _,card in ipairs(run.deck or {})do
  local previous=old[card.uid]
  local a,b=M.state(previous or {}),M.state(card)
  local explicit=card.lastUpgradeOrigin
  local recorded=explicit and explicit.uid==card.uid and explicit.after.upgrades==b.upgrades
   and (not previous or not previous.lastUpgradeOrigin or explicit.after.upgrades~=previous.lastUpgradeOrigin.after.upgrades)
  if (not previous or previous.cardId~=card.cardId) and b.upgraded and not recorded then
   M.record(run,card,M.state({}),'obtained_upgraded')
  elseif previous and previous.cardId==card.cardId and not recorded and (a.upgraded~=b.upgraded or a.upgrades~=b.upgrades) then
   local source=M.context(before)
   local relic=acquired[card.uid]
   if relic and relic.after.upgrades==b.upgrades then
    source={kind='relic',relicId=relic.relicId}
   end
   M.record(run,card,a,'permanent_upgrade',source)
  end
 end
end
return M
