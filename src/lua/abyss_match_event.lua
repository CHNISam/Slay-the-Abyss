-- Independent Match and Keep! rules; pinned GremlinMatchGame blob f86144bd.
-- Nodes owns the enclosing Run.transaction, including constructor sampling.
local Run=require('abyss_run')
local R=require('abyss_sts_random')
local Copy=require('abyss_copy').copy
local Context=require('abyss_event_transform_context')
local Capability=require('abyss_card_capability')
local Hooks=require('abyss_relic_hooks')
local M={}
local sizes={ironclad={rare=16,uncommon=36,common=20},silent={rare=19,uncommon=33,common=19},
 defect={rare=17,uncommon=36,common=18},watcher={rare=17,uncommon=35,common=19}}
local starters={ironclad='Bash',silent='Neutralize',defect='Zap',watcher='Eruption'}
local colors={ironclad='red',silent='green',defect='blue',watcher='purple'}
local function definition(run,id)
 for _,d in ipairs(run.data.cards.cards)do if d.id==id then return d end end
end
local function row(choice,title,description)
 return {choice=choice,title=title,description=description,enabled=true}
end
local function sourcePools(run)
 local character=run.data.runCardCharacter;local expected=sizes[character]
 if run.data.runCardCatalog~=true or not expected then return nil,'match_source_catalog_unavailable'end
 local source=run.data.cards.sourcePools;local reward=source and source.reward
 local context=Context.new(run)
 if not reward or not context then return nil,'match_source_catalog_unavailable'end
 for rarity,size in pairs(expected)do
  if type(reward[rarity])~='table'or #reward[rarity]~=size then return nil,'match_source_pool_unavailable'end
 end
 if type(source.colorlessRaw)~='table'or #source.colorlessRaw~=35 then return nil,'match_source_pool_unavailable'end
 return {character=character,reward=reward,context=context,source=source}
end
local function baseCard(run,id,sourceId,rarity,color)
 local d=definition(run,id)
 if not Capability.isImplemented(d)or(d.sourceId or d.sts_name or d.id)~=sourceId or rarity and d.rarity~=rarity
  or color and d.color~=color then return nil,'card_content_unavailable'end
 return {cardId=id,sourceCardId=sourceId,upgraded=false}
end
local function drawClass(run,pools,rarity)
 local bucket=pools.reward[rarity];local id=bucket[R.randomInt(run.cardRng,#bucket-1)+1]
 local fact=pools.source.cardSourceMetadata[id]
 return baseCard(run,id,fact and fact.sourceId,rarity,colors[pools.character])
end
local function colorless(run,pools,shuffle)
 local owner=run.colorlessCardPool
 if not owner or owner.act~=(run.act or 1)then
  owner={act=run.act or 1,cards=Copy(pools.source.colorlessRaw)};run.colorlessCardPool=owner
 end
 -- Preserve the canonical mutable pool's actual order, never reconstruct a
 -- filtered rarity bucket. Other current consumers use sorted/src pools.
 if type(owner.cards)~='table'or #owner.cards~=35 then return nil,'match_source_pool_unavailable'end
 local seen={}
 for _,id in ipairs(owner.cards)do
  local fact=pools.source.cardSourceMetadata[id]
  if seen[id]or not fact or(fact.rarity~='uncommon'and fact.rarity~='rare')then return nil,'match_source_pool_unavailable'end
  seen[id]=true
 end
 for _,id in ipairs(pools.source.colorlessRaw)do if not seen[id]then return nil,'match_source_pool_unavailable'end end
 R.shuffle(shuffle,owner.cards)
 for _,id in ipairs(owner.cards)do
  local fact=pools.source.cardSourceMetadata[id]
  if fact.rarity=='uncommon'then return baseCard(run,id,fact.sourceId,'uncommon','colorless')end
 end
 return nil,'match_source_pool_unavailable'
end
local function drawCurse(run,pools)
 local ids=pools.context.pools.curses
 local sourceId=ids[R.randomInt(run.cardRng,#ids-1)+1]
 local id=pools.context.sourceToLocal[sourceId]
 local card,why=baseCard(run,id,sourceId)
 if not card then return nil,why end
 if definition(run,id).type~='curse'then return nil,'card_content_unavailable'end
 return card
end
-- Called before entry publishes floor/miscRng, so both arguments are explicit.
-- A failure must abort the existing enclosing entry transaction, not reroll.
function M.prepare(run,event,miscRng,roomFloor)
 local pools,why=sourcePools(run);if not pools then return false,why end
 local streams=Run.roomStreams(run,roomFloor);R.snapshot(miscRng)
 local originals={}
 for _,rarity in ipairs({'rare','uncommon','common'})do
  local card,reason=drawClass(run,pools,rarity);if not card then return false,reason end
  originals[#originals+1]=card
 end
 local neutral,reason=colorless(run,pools,streams.shuffleRng);if not neutral then return false,reason end
 originals[#originals+1]=neutral
 local curse;curse,reason=drawCurse(run,pools);if not curse then return false,reason end
 originals[#originals+1]=curse
 local startId=starters[pools.character]
 local starter;starter,reason=baseCard(run,pools.context.sourceToLocal[startId],startId)
 if not starter then return false,reason end;originals[#originals+1]=starter
 local board={}
 for i,card in ipairs(originals)do
  Hooks.onPreviewObtainCard(run,card,definition(run,card.cardId));board[i]=card;board[i+6]=Copy(card)
 end
 R.shuffle(miscRng,board)
 event.board,event.shuffleRng,event.roomFloor=board,streams.shuffleRng,roomFloor
 event.stage,event.body='intro','一位守着石牌的旅人邀你试试记性。翻出相同的牌，便能带走一张。'
 event.attemptsLeft,event.revision,event.removed,event.awards=5,0,{},{}
 return true
end
function M.options(_,event)
 if event.stage=='intro'then return {row('continue','听听规则','看看石牌的玩法。')}end
 if event.stage=='rules'then return {row('start','开始翻牌','十二张牌，五次机会。每次翻两张；相同的牌获得一张，不同的牌重新盖回。命中也会消耗一次机会，诅咒同样会被带走。')}end
 if event.stage=='result'then return {row('leave','收好牌，继续前行','返回路线。')}end
 return {}
end
local function prefix(run,event)
 return 'match:'..tostring(run.roomGeneration)..':'..tostring(event.roomFloor)..':'..tostring(event.revision)
end
local function flip(run,event,token)
 if type(token)~='string'then return false,'stale_match_action'end
 local slot
 for i=1,12 do if token==prefix(run,event)..':slot:'..i then slot=i end end
 if not slot then return false,'stale_match_action'end
 if event.removed[slot]or event.first==slot then return false,'match_slot_unavailable'end
 local card=event.board[slot]
 if not baseCard(run,card.cardId,card.sourceCardId)then return false,'card_content_unavailable'end
 if event.first then
  event.second=slot;event.stage='resolving'
  event.waitSeconds=event.board[event.first].sourceCardId==card.sourceCardId and 1 or 1.25
 else event.first=slot end
 event.revision=event.revision+1
 return true,'pending'
end
local function resolve(run,event,token)
 if token~=prefix(run,event)..':resolve'then return false,'stale_match_action'end
 local first,second=event.board[event.first],event.board[event.second]
 if not baseCard(run,first.cardId,first.sourceCardId)or not baseCard(run,second.cardId,second.sourceCardId)then
  return false,'card_content_unavailable'
 end
 if first.sourceCardId==second.sourceCardId then
  -- Source obtains makeCopy, not the upgraded preview/stat-equivalent board.
  -- Searing Blow alone carries its constructor count through makeCopy.
  local options
  if first.cardId=='searing_blow'then
   local n=first.upgrades or(first.upgraded and 1 or 0)
   options={upgrades=n,upgraded=false,searingBlowCopyUpgrades=n}
  end
  local ok,uid=Run.obtainCard(run,first.cardId,options);if not ok then return false,uid end
  event.awards[#event.awards+1]={cardId=first.cardId,uid=type(uid)=='number'and uid or nil,blocked=uid=='curse_blocked'}
  event.removed[event.first],event.removed[event.second]=true,true
 end
 event.first,event.second,event.waitSeconds=nil,nil,nil
 event.attemptsLeft,event.revision=event.attemptsLeft-1,event.revision+1
 event.stage=event.attemptsLeft==0 and 'cleanup'or'play'
 if event.stage=='cleanup'then event.waitSeconds=1 end
 return true,'pending'
end
function M.choose(run,flow,choice,token)
 local event=flow and flow.event
 if flow~=run.nodeFlow or not event or event.id~='match_game'or flow.complete or run.phase~='node'then return false,'no_pending_node'end
 if run.floor~=event.roomFloor then return false,'stale_match_action'end
 if event.stage=='play'and choice=='flip'then return flip(run,event,token)end
 if event.stage=='resolving'and choice=='resolve'then return resolve(run,event,token)end
 if event.stage=='cleanup'and choice=='finish'then
  if token~=prefix(run,event)..':finish'then return false,'stale_match_action'end
  event.stage,event.waitSeconds='result',nil
  event.body='石牌归于寂静。你记住了这次相遇，收好赢得的卡牌。';event.revision=event.revision+1
  return true,'pending'
 end
 if token~=nil then return false,'invalid_event_choice'end
 if event.stage=='intro'and choice=='continue'then
  event.stage,event.body='rules','相同的石牌会回应彼此。五次机会用完，牌局便会结束。'
 elseif event.stage=='rules'and choice=='start'then event.stage,event.body='play','请选择两张石牌。'
 elseif event.stage=='result'and choice=='leave'then return true,'complete'
 else return false,'invalid_event_choice'end
 event.revision=event.revision+1;return true,'pending'
end
-- Called ONLY on Nodes.view's detached event copy. Private IDs/RNG never leak
-- behind concealed cards; every physical click carries the displayed revision.
function M.view(run,event)
 local slots={};local active=event.stage=='play'
 for i=1,12 do
  local up=event.first==i or event.second==i;local card=event.board[i]
  local slot={slot=i,faceUp=up,removed=event.removed[i]==true,token=prefix(run,event)..':slot:'..i}
  if up and not slot.removed then
   for _,field in ipairs({'cardId','upgraded','upgrades','searingBlowCopyUpgrades'})do slot[field]=card[field]end
  end
  slot.enabled=active and not up and not slot.removed;slots[i]=slot
 end
 event.match={slots=slots,attemptsLeft=event.attemptsLeft,phase=event.stage,revision=event.revision,
  waitSeconds=event.waitSeconds,resolveToken=event.stage=='resolving'and prefix(run,event)..':resolve'or nil,
  completionToken=event.stage=='cleanup'and prefix(run,event)..':finish'or nil}
 event.board,event.shuffleRng,event.removed,event.first,event.second=nil,nil,nil,nil,nil
end
return M
