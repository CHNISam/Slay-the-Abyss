-- Fixed319009 Falling: original permanent objects, source typed sampling order.
-- Nodes owns the room and public command transactions; there is no combat path.
local Random=require('abyss_sts_random')
local Copy=require('abyss_copy').copy
local Run=require('abyss_run')
local Moai=require('abyss_moai_event')
local Winding=require('abyss_winding_event')
local Sensory=require('abyss_sensory_stone_event')
local Tomb=require('abyss_tomb_red_mask_event')
local MindBloom=require('abyss_mind_bloom_event')
local Sphere=require('abyss_mysterious_sphere_event')
local M={ids={falling=true,moai_head=true,winding_halls=true,sensory_stone=true,tomb_red_mask=true,mind_bloom=true,mysterious_sphere=true}}
local function definition(run,id)
 for _,card in ipairs(run.data.cards.cards)do if card.id==id then return card end end
end
local function unbottled(card)return not card.inBottleFlame and not card.inBottleLightning and not card.inBottleTornado end
local function same(a,b)
 if type(a)~='table' or type(b)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function any(event)return next(event.candidates)~=nil end
local function row(choice,title,description,card)
 return {choice=choice,title=title,description=description,enabled=card~=false,
  cardId=type(card)=='table' and card.cardId or nil,upgraded=type(card)=='table' and card.upgraded or nil,
  upgrades=type(card)=='table' and card.upgrades or nil}
end
function M.prepare(run,event,miscRng)
 if event.id=='mind_bloom'then return MindBloom.prepare(run,event)end
 if event.id=='mysterious_sphere'then return Sphere.prepare(run,event)end
 if event.id=='tomb_red_mask'then return Tomb.prepare(run,event)end
 if event.id=='sensory_stone'then return Sensory.prepare(run,event)end
 if event.id=='winding_halls'then return Winding.prepare(run,event)end
 if event.id=='moai_head'then return Moai.prepare(run,event)end
 assert(event.id=='falling' and run.act==3,'Falling requires the third act')
 local groups={attack={},skill={},power={}};local seen={}
 for _,card in ipairs(run.deck)do
  assert(type(card.uid)=='number' and card.uid%1==0 and card.uid>0 and card.uid<=9007199254740991 and not seen[card.uid],'invalid permanent card UID')
  seen[card.uid]=true
  local d=assert(definition(run,card.cardId),'missing Falling card definition')
  if groups[d.type] and unbottled(card)then groups[d.type][#groups[d.type]+1]=card end
 end
 event.candidates={}
 -- CardHelper samples each existing type, including random(0) for singleton.
 for _,kind in ipairs({'attack','skill','power'})do
  local cards=groups[kind]
  if #cards>0 then event.candidates[kind]=Copy(cards[Random.randomInt(miscRng,#cards-1)+1])end
 end
 event.stage,event.body='intro','脚下的落石打散了你的牌组。先稳住身形，再作取舍。'
end
function M.options(run,event)
 if event.id=='mind_bloom'then return MindBloom.options(run,event)end
 if event.id=='mysterious_sphere'then return Sphere.options(run,event)end
 if event.id=='tomb_red_mask'then return Tomb.options(run,event)end
 if event.id=='sensory_stone'then return Sensory.options(run,event)end
 if event.id=='winding_halls'then return Winding.options(run,event)end
 if event.id=='moai_head'then return Moai.options(run,event)end
 if event.stage=='intro'then return {row('continue','继续','查看可以舍弃的卡牌。')}end
 if event.stage=='result'then return {row('leave','离开','返回路线。')}end
 if event.stage~='choice'then return {}end
 if not any(event)then return {row('escape','稳住身形','没有可舍弃的攻击、技能或能力牌。')}end
 local rows={}
 for _,entry in ipairs({{'skill','技能'},{'power','能力'},{'attack','攻击'}})do
  local card=event.candidates[entry[1]]
  rows[#rows+1]=row(entry[1],'失去'..entry[2],card and '永久移除这张未瓶装的卡牌。' or '没有未瓶装的'..entry[2]..'牌。',card or false)
 end
 return rows
end
function M.choose(run,flow,choice,uid)
 if flow.event.id=='mind_bloom'then return MindBloom.choose(run,flow,choice,uid)end
 if flow.event.id=='mysterious_sphere'then return Sphere.choose(run,flow,choice,uid)end
 if flow.event.id=='tomb_red_mask'then return Tomb.choose(run,flow,choice,uid)end
 if flow.event.id=='sensory_stone'then return Sensory.choose(run,flow,choice,uid)end
 if flow.event.id=='winding_halls'then return Winding.choose(run,flow,choice,uid)end
 if flow.event.id=='moai_head'then return Moai.choose(run,flow,choice,uid)end
 local event=flow.event
 if event.id~='falling' or run.act~=3 then return false,'invalid_event_choice'end
 if event.stage=='intro'then
  if choice~='continue' or uid~=nil then return false,'invalid_event_choice'end
  event.stage,event.body='choice','你必须舍弃其中一张卡牌，才能继续前进。';return true,'pending'
 elseif event.stage=='result'then
  if choice~='leave' or uid~=nil then return false,'invalid_event_choice'end
  return true,'complete'
 elseif event.stage~='choice'then return false,'invalid_event_choice'end
 if choice=='escape' and not any(event) and uid==nil then
  event.stage,event.body='result','你稳住了身形，没有失去卡牌。';return true,'pending'
 end
 local selected=event.candidates[choice]
 if not selected then return false,'event_condition_unmet'end
 if uid~=nil and uid~=selected.uid then return false,'stale_event_card'end
 local current
 for _,card in ipairs(run.deck)do if card.uid==selected.uid then current=card;break end end
 local d=current and definition(run,current.cardId)
 if not current or not same(current,selected) or not unbottled(current) or not d or d.type~=choice then return false,'stale_event_card'end
 local ok,removed=Run.removeCard(run,current.uid);if not ok then return false,removed end
 event.removedCard,event.removedUid=Copy(removed),removed.uid
 event.stage,event.body='result','你舍弃了「'..d.name..(removed.upgraded and '＋' or '')..'」。'
 return true,'pending'
end
return M
