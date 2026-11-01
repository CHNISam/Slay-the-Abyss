-- Offline player policy. Only view-returned public tokens may be dispatched.
local Pending,Run=require('abyss_relic_pending'),require('abyss_run')
local M={}
function M.choose(run,scoreCard)
 local view=Pending.view(run);if not view then return nil end
 local selected,best
 local room=Run.potionCount(run)<Run.potionCapacity(run)
 for _,id in ipairs(run.relics)do for _,definition in ipairs(run.data.relics.relics)do
  if definition.id==id and definition.blocksPotions then room=false end
 end end
 for _,row in ipairs(view.rows)do
  local token=row.token
  local score
  if token.kind=='select'then
   score=scoreCard(run,row.card.cardId)
   if token.key=='pendingBossRelic'then score=-score end
  elseif token.kind=='card'then
   score=row.card and scoreCard(run,row.card.cardId) or token.choice=='bowl'and 28 or token.choice==0 and 28
  elseif token.kind=='relic'then score=25
  elseif token.kind=='gold'then score=20
  elseif token.kind=='potion'then
   if token.choice==0 then score=room and 0 or 15
   elseif room then score=20 end
  elseif token.kind=='done'or token.kind=='close'then score=-1000 end
  if score and (not best or score>best)then selected,best=row,score end
 end
 assert(selected,'mandatory relic view has no legal visible choice')
 return selected.token,{key=view.key,kind=selected.token.kind,uid=selected.token.uid,
  choice=selected.token.choice,index=selected.token.index,cardId=selected.card and selected.card.cardId,
  relic=selected.relic,potion=selected.potion}
end
return M
