-- Read-only labels for the permanent receipt and the current combat copy.
local M={}
local events={shining_light='闪耀之光',upgrade_shrine='升级神龛',living_wall='活墙',
 accursed_blacksmith='诅咒铁匠',back_to_basics='古老文字',designer='设计师',mind_bloom='心灵绽放',neow='高塔恩赐'}
local kinds={camp='营地锻造',event='事件',shop='商店',treasure='宝箱',reward='战斗奖励',combat='战斗',map='地图'}
local function source(run,value)
 if value.relicId then return require('abyss_relic_names').get(run.data,value.relicId)end
 local name=events[value.eventId] or kinds[value.kind] or '本局效果'
 return name..(value.floor and (' · 第 '..value.floor..' 层') or '')
end
function M.describe(run,instance,combat)
 local permanent
 for _,card in ipairs(run and run.deck or {})do
  if card.uid==(combat and instance.deckUid or instance.uid) and card.cardId==instance.cardId then permanent=card;break end
 end
 local text=''
 local origin=permanent and permanent.lastUpgradeOrigin or not combat and instance.lastUpgradeOrigin
 if not require('abyss_card_origin').matches(permanent or instance,origin)then origin=nil end
 if origin then
  text=(origin.kind=='obtained_upgraded' and '获得时已升级 · 来源：' or '永久升级 · 来源：')..source(run,origin.source)
 elseif permanent and permanent.upgraded then text='永久牌组中已升级 · 来源未记录' end
 if combat and instance.upgraded and (not permanent or
  (instance.upgrades or 1)>(permanent.upgrades or (permanent.upgraded and 1 or 0)))then
  text=(text~='' and text..'\n' or '')..'本场临时升级 · 不改变永久牌组'
 end
 return text
end
function M.keywords(definition)
 return definition.strikeTag and '打击类：带有打击标签，计入剑势如虹等效果。' or ''
end
return M
