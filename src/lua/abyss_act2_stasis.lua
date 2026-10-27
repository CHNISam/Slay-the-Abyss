-- ApplyStasisAction / StasisPower: identity-preserving custody, not card generation.
local Events=require('abyss_events')
local R=require('abyss_sts_random')
local copy=require('abyss_copy').copy
local M={}
function M.apply(combat,s,orb)
 assert(orb.ai and orb.ai.policy=='orb','Bronze Orb Stasis only')
 local pile=#s.draw>0 and s.draw or s.discard
 if #pile==0 then return end
 assert(not (s.act2StasisCards and s.act2StasisCards[orb.id]),'orb already holds a card')
 local candidates={}
 for _,rarity in ipairs({'rare','uncommon','common'})do
  for i,c in ipairs(pile)do
   local d=assert(s.catalog.cards[c.cardId])
   local metadata=s.sourcePools and s.sourcePools.cardSourceMetadata and s.sourcePools.cardSourceMetadata[c.cardId]
   local sourceId=metadata and metadata.sourceId or d.sourceId or d.id
   if d.rarity==rarity then candidates[#candidates+1]={card=c,index=i,sourceId=sourceId} end
  end
  if #candidates>0 then
   table.sort(candidates,function(a,b)return a.sourceId==b.sourceId and a.index<b.index or a.sourceId<b.sourceId end)
   break
  end
 end
 if #candidates==0 then for i,c in ipairs(pile)do candidates[i]={card=c,index=i}end end
 local chosen=candidates[R.randomInt(assert(s.cardRandomRng,'Stasis needs card RNG'),#candidates-1)+1]
 table.remove(pile,chosen.index)
 s.act2StasisCards=s.act2StasisCards or {};s.act2StasisCards[orb.id]=chosen.card
 orb.stasisCardId,orb.stasisCardUid,orb.stasisCardUpgraded=chosen.card.cardId,chosen.card.uid,chosen.card.upgraded
 combat.applyEffects(s,{{op='gainStatus',status='stasis',value=1}},orb,s.player)
 Events.emit(s,'card_stasis',{enemy=orb.id,uid=chosen.card.uid,cardId=chosen.card.cardId})
end
function M.death(s,orb)
 local c=s.act2StasisCards and s.act2StasisCards[orb.id]
 if not c then return end
 local discard=#s.hand==s.rules.player.maxHand
 if not discard and (s.player.statuses.master_reality or 0)>0 then
  -- MakeTempCardInHandAction performs Master Reality's upgrade in its constructor.
  local combat=require('abyss_combat')
  if combat.canUpgrade(s,c)then combat.upgrade(s,c)end
 end
 return {op='stasis_return',ownerId=orb.id,forceDiscard=discard}
end
function M.release(api,s,entry)
 local c=s.act2StasisCards and s.act2StasisCards[entry.ownerId]
 if not c then return end
 s.act2StasisCards[entry.ownerId]=nil
 local live=false;for _,e in ipairs(s.enemies)do if api.isPresent(e)then live=true end end
 if not live or s.player.hp<=0 then return end
 local pile=entry.forceDiscard or #s.hand>=s.rules.player.maxHand
 local destination=pile and s.discard or s.hand
 destination[#destination+1]=copy(c)
 Events.emit(s,'card_stasis_return',{enemy=entry.ownerId,uid=c.uid,cardId=c.cardId,pile=pile and 'discard' or 'hand'})
end
return M
