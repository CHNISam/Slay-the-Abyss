-- STS 319009d5 rare relic hooks. Action/transaction ownership stays in Combat.
local A=require('abyss_actor')
local S=require('abyss_sts_random')
local E=require('abyss_events')
local M={}
local aliases={Ginger='ginger',['Bird Faced Urn']='bird_faced_urn',['Unceasing Top']='unceasing_top',Torii='torii',
 StoneCalendar='stone_calendar',Shovel='shovel',WingedGreaves='winged_greaves',['Thread and Needle']='thread_and_needle',
 Turnip='turnip',['Ice Cream']='ice_cream',Calipers='calipers',['Prayer Wheel']='prayer_wheel',Girya='girya',
 ['Dead Branch']='dead_branch',['Du-Vu Doll']='du_vu_doll',Pocketwatch='pocketwatch',['Incense Burner']='incense_burner',
 ['Gambling Chip']='gambling_chip',['Peace Pipe']='peace_pipe',CaptainsWheel='captains_wheel',['Magic Flower']='magic_flower',
 ["Charon's Ashes"]='charons_ashes',['Champion Belt']='champion_belt'}
function M.localId(id)return aliases[id]or id end
local function owns(s,id)
 for _,held in ipairs(s.relics or {})do if M.localId(held)==id then return true end end
 return false
end
M.owns=owns
local function counters(s)s.relicCounters=s.relicCounters or {};return s.relicCounters end
local function flags(s)s.rareRelicCombat=s.rareRelicCombat or {};return s.rareRelicCombat end
local function enqueue(s,e,top)require('abyss_card_actions').enqueueReaction(s,e,top)end
local function living(s)
 for _,enemy in ipairs(s.enemies or {})do if A.isPresent(enemy)then return true end end
 return false
end
function M.onMasterDeckChange(run)
 if not owns(run,'du_vu_doll')then return end
 local catalog={};for _,d in ipairs(run.data.cards.cards)do catalog[d.id]=d end
 local n=0;for _,card in ipairs(run.deck)do if assert(catalog[card.cardId],'unknown master card').type=='curse'then n=n+1 end end
 counters(run).du_vu_doll=n
end
function M.onEquip(run,id)
 id=M.localId(id)
 if id=='girya'or id=='incense_burner'then counters(run)[id]=0
 elseif id=='winged_greaves'then counters(run)[id]=3
 elseif id=='du_vu_doll'then M.onMasterDeckChange(run)end
end
function M.bindBattle(s)
 s.rareRelicCombat={firstPocketTurn=true,gamblingActivated=false,topCanDraw=false,topDisabled=false}
 for _,id in ipairs({'stone_calendar','captains_wheel','pocketwatch'})do if owns(s,id)then counters(s)[id]=0 end end
end
function M.battleStart(s,id,execute)
 id=M.localId(id)
 local power,n
 if id=='thread_and_needle'then power,n='plated_armor',4
 elseif id=='girya'or id=='du_vu_doll'then power,n='strength',counters(s)[id]or 0 end
 if power and n>0 then
  if execute then A.applyPower(s,s.player,power,n,s.player)
  else enqueue(s,{op='gainStatus',status=power,value=n},true)end
 end
end
function M.atTurnStart(s,singleId,emit)
 local push=emit or enqueue
 local c=counters(s);local f=flags(s)
 f.topCanDraw=true;f.topDisabled=false
 for _,held in ipairs(singleId and {singleId}or s.relics or {})do
  local id=M.localId(held)
  if id=='stone_calendar'then c[id]=(c[id]or 0)+1
  elseif id=='captains_wheel'and (c[id]or 0)>=0 then
   c[id]=(c[id]or 0)+1
   if c[id]==3 then c[id]=-1;push(s,{op='block',value=18,fixed=true})end
  elseif id=='incense_burner'then
   c[id]=(c[id]==-1 and 1 or (c[id]or 0)+1)
   if c[id]==6 then c[id]=0;push(s,{op='gainStatus',status='intangible',value=1,nullSource=true})end
  end
 end
end
function M.postDraw(s,singleId)
 local c,f=counters(s),flags(s)
 for _,held in ipairs(singleId and {singleId}or s.relics or {})do
  local id=M.localId(held)
  if id=='pocketwatch'then
   if not f.firstPocketTurn and (c[id]or 0)<=3 then enqueue(s,{op='draw',value=3})end
   f.firstPocketTurn=false;c[id]=0
  elseif id=='gambling_chip'and not f.gamblingActivated then
   f.gamblingActivated=true;enqueue(s,{op='rareGamblingChip'})
  end
 end
end
function M.onPlayCard(s)
 if owns(s,'pocketwatch')then local c=counters(s);c.pocketwatch=(c.pocketwatch or 0)+1 end
end
function M.onUseCard(s,d)
 if d.type=='power'and owns(s,'bird_faced_urn')then enqueue(s,{op='heal',value=2,relic='bird_faced_urn'},true)end
end
function M.onPlayerEndTurn(s)
 flags(s).topCanDraw=false
 if s.relicEndTurnResolved~=s.turn and owns(s,'stone_calendar')and counters(s).stone_calendar==7 then
  enqueue(s,{op='rareRelicDamageAll',value=52,relic='stone_calendar'})
 end
end
function M.disableTop(s)flags(s).topDisabled=true end
function M.onRefreshHand(s,canDraw)
 local f=flags(s)
 if canDraw and owns(s,'unceasing_top')and f.topCanDraw and not f.topDisabled and s.phase=='player'
  and A.isActive(s.player)and living(s)and #s.hand==0 and #s.draw+#s.discard>0
  and not s.player.noDraw and not s.pendingChoice and not s.pendingDiscard then
  enqueue(s,{op='draw',value=1});return true
 end
 return false
end
function M.blockPower(s,target,id)
 return target==s.player and (id=='weak'and owns(s,'ginger')or id=='frail'and owns(s,'turnip'))or false
end
function M.onVulnerableApplied(s,target)
 if target~=s.player and owns(s,'champion_belt')then enqueue(s,{op='rareRelicWeak',targetId=target.id,value=1})end
end
function M.onAttacked(s,owner,damageType,amount)
 if owns(s,'torii')and owner~=nil and damageType=='normal'and amount>1 and amount<=5 then return 1 end
 return amount
end
function M.blockAtTurnStart(s,amount)return owns(s,'calipers')and math.max(0,amount-15)or 0 end
function M.rechargeEnergy(s,base)return owns(s,'ice_cream')and s.energy+0.0+base or base end
function M.modifyHealing(s,amount,inCombat)
 if owns(s,'magic_flower')and inCombat then return math.floor(S.float32(S.float32(amount)*1.5)+.5)end
 return amount
end
function M.randomCardId(s)
 local pool={}
 for _,rarity in ipairs({'common','uncommon','rare'})do
  for _,id in ipairs(assert(s.sourcePools.src[rarity]))do
   if not assert(s.catalog.cards[id],'unknown source card').healing then pool[#pool+1]=id end
  end
 end
 assert(#pool>0,'empty Dead Branch pool')
 return pool[S.randomInt(assert(s.cardRandomRng,'missing combat card RNG'),#pool-1)+1]
end
function M.onExhaust(s,emit)
 emit=emit or enqueue
 for _,held in ipairs(s.relics or {})do
  local id=M.localId(held)
  if id=='charons_ashes'then emit(s,{op='rareRelicDamageAll',value=3,relic=id},true)
  elseif id=='dead_branch'and living(s)then emit(s,{op='rareRelicGenerate',card=M.randomCardId(s)})end
 end
end
local function beginGambling(s)
 s.choiceSerial=(s.choiceSerial or 0)+1
 local uids={};for _,c in ipairs(s.hand)do uids[#uids+1]=c.uid end
 s.pendingChoice={token=s.choiceSerial,op='rareGamblingChip',uids=uids,multiple=true,selected={},allowEmpty=true}
 E.emit(s,'card_choice',{token=s.choiceSerial,op='rareGamblingChip'})
end
function M.chooseGambling(combat,s,uids,token)
 local p=s.pendingChoice
 if not p or p.op~='rareGamblingChip'or token~=p.token then return false,'stale_choice'end
 if type(uids)~='table'then return false,'invalid_choice'end
 local allowed,seen,count={},{},0
 for _,uid in ipairs(p.uids)do allowed[uid]=true end
 for k,uid in pairs(uids)do
  count=count+1
  if type(k)~='number'or k%1~=0 or k<1 or k>#uids or not allowed[uid]or seen[uid]then return false,'invalid_choice'end
  local found=false;for _,card in ipairs(s.hand)do if card.uid==uid then found=true end end
  if not found then return false,'stale_choice'end
  seen[uid]=true
 end
 if count~=#uids then return false,'invalid_choice'end
 s.pendingChoice=nil
 -- Chip increments discard before each card's manual-discard trigger.
 enqueue(s,{op='draw',value=#uids},true)
 for _,uid in ipairs(uids)do
  local ok,why=require('abyss_discard').discardSpecific(s,uid,true,combat);assert(ok,why)
 end
 return true
end
function M.applyEffect(combat,s,e)
 if e.op=='rareGamblingChip'then beginGambling(s)
 elseif e.op=='rareRelicGenerate'then
  combat.applyEffects(s,{{op='makeTempCardInHand',card=e.card,value=1}},s.player)
 elseif e.op=='rareRelicDamageAll'then
  local reactions={}
  for _,target in ipairs(s.enemies)do if A.isActive(target)then combat.damage(s,nil,target,e.value,true,reactions)end end
  A.resolveDamageReactions(s,reactions,combat.retaliate)
 elseif e.op=='rareRelicWeak'then
  for _,target in ipairs(s.enemies)do if target.id==e.targetId then A.applyPower(s,target,'weak',1,s.player,false)end end
 else return false end
 return true
end
function M.onVictory(s)
 for _,id in ipairs({'stone_calendar','pocketwatch','captains_wheel'})do if owns(s,id)then counters(s)[id]=-1 end end
end
function M.campOptions(run,removable)
 local result={}
 for _,held in ipairs(run.relics or {})do
  local id=M.localId(held)
  if id=='shovel'then result[#result+1]={id='dig',enabled=true}
  elseif id=='girya'then result[#result+1]={id='lift',enabled=(counters(run).girya or 0)<3}
  elseif id=='peace_pipe'then result[#result+1]={id='toke',enabled=removable==true}end
 end
 return result
end
function M.lift(run)
 if not owns(run,'girya')or (counters(run).girya or 0)>=3 then return false,'lift_unavailable'end
 counters(run).girya=(counters(run).girya or 0)+1;return true
end
function M.canWingedTravel(run)
 return owns(run,'winged_greaves')and (counters(run).winged_greaves or 0)>0
end
function M.useWingedTravel(run)
 if not M.canWingedTravel(run)then return false,'winged_travel_unavailable'end
 local c=counters(run);c.winged_greaves=c.winged_greaves-1
 if c.winged_greaves==0 then c.winged_greaves=-2 end
 return true
end
function M.extraCardRewards(run,normalRoom)return owns(run,'prayer_wheel')and normalRoom and 1 or 0 end
function M.canSpawn(run,id)
 id=M.localId(id)
 local floor=run.sourceFloor or run.floor or 0
 if id=='winged_greaves'then return run.endless==true or floor<=40 end
 if id=='prayer_wheel'then return run.endless==true or floor<=48 end
 if id=='girya'or id=='shovel'or id=='peace_pipe'then
  if floor>=48 and not run.endless then return false end
  local n=0
  for _,held in ipairs(run.relics or {})do
   local localId=M.localId(held)
   if localId=='girya'or localId=='shovel'or localId=='peace_pipe'then n=n+1 end
  end
  return n<2
 end
 return true
end
return M
