-- Fixed319009d5 event helpers, not reward rolls or capability-filtered pools.
-- Callers own the Nodes/Run transaction and their room shuffle RNG.
local R=require('abyss_sts_random')
local Capability=require('abyss_card_capability')
local M={}
local sizes={ironclad={common=20,uncommon=36,rare=16},silent={common=19,uncommon=33,rare=19},
 defect={common=18,uncommon=36,rare=17},watcher={common=19,uncommon=35,rare=17}}
local starts={ironclad='Bash',silent='Neutralize',defect='Zap',watcher='Eruption'}
-- CardLibrary.curses HashMap traversal after the four source exclusions.
local curses={'Regret','Injury','Shame','Parasite','Normality','Doubt','Writhe','Pain','Decay','Clumsy'}
function M.definition(run,id)
 for _,d in ipairs(run.data.cards.cards)do if d.id==id then return d end end
end
local function sourceId(d)return d.sourceId or d.sts_name or d.id end
local function offer(run,id)
 local d=M.definition(run,id)
 assert(Capability.isImplemented(d),'event card definition unavailable')
 return {cardId=id,sourceCardId=sourceId(d),upgraded=false}
end
function M.colored(run,tier)
 local character=run.data.runCardCharacter or 'ironclad'
 assert(not run.data.originalV4Role and sizes[character],'event source class unavailable')
 local source=assert(run.data.cards.sourcePools,'event source pools unavailable')
 local bucket=assert(source.reward and source.reward[tier],'event rarity pool unavailable')
 assert(#bucket==sizes[character][tier],'incomplete event source pool')
 for _,id in ipairs(bucket)do
  local d=M.definition(run,id);local fact=source.cardSourceMetadata and source.cardSourceMetadata[id]
  assert(d and fact and d.rarity==tier and sourceId(d)==fact.sourceId,'event source identity unavailable')
 end
 return offer(run,bucket[R.randomInt(run.cardRng,#bucket-1)+1])
end
function M.reset(run)
 local raw=assert(run.data.cards.sourcePools.colorlessRaw,'event colorless pool unavailable')
 assert(#raw==35,'incomplete event colorless pool')
 local ids={};for i,id in ipairs(raw)do ids[i]=id end
 run.colorlessCardPool={act=run.act or 1,cards=ids}
 return run.colorlessCardPool
end
local function colorlessPool(run)
 local state=run.colorlessCardPool
 if not state or state.act~=(run.act or 1)then state=M.reset(run)end
 assert(type(state.cards)=='table' and #state.cards==35,'invalid event colorless pool')
 for _,id in ipairs(state.cards)do
  local d=M.definition(run,id)
  assert(d and d.color=='colorless' and (d.rarity=='uncommon' or d.rarity=='rare'),'event colorless identity unavailable')
 end
 return state.cards
end
function M.colorless(run,tier,shuffleRng)
 assert(tier=='uncommon' or tier=='rare','invalid event colorless rarity')
 local ids=colorlessPool(run)
 -- returnColorlessCard mutates the complete room's act-wide pool order.
 R.shuffle(shuffleRng,ids)
 for _,id in ipairs(ids)do if M.definition(run,id).rarity==tier then return offer(run,id) end end
 error('event colorless rarity unavailable') -- complete source pool always has both tiers
end
function M.curse(run)
 local source=curses[R.randomIntBetween(run.cardRng,0,#curses-1)+1]
 for _,d in ipairs(run.data.cards.cards)do if sourceId(d)==source then return offer(run,d.id) end end
 error('event curse definition unavailable')
end
function M.start(run)
 local source=starts[run.data.runCardCharacter or 'ironclad']
 assert(source and not run.data.originalV4Role,'event start card unavailable')
 for _,d in ipairs(run.data.cards.cards)do if sourceId(d)==source then return offer(run,d.id) end end
 error('event start card definition unavailable')
end
return M
