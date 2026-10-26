-- One presentation source for the new potion effects across battle, inventory
-- and shop. Values are computed from the same held Bark/slot context as use.
local H=require('abyss_relic_hooks')
local N=require('abyss_numbers').integer
local M={}
local kinds={attack='攻击',skill='技能',power='能力',colorless='无色'}
function M.special(item,owner,expanded)
 owner=owner or {}
 local bark=H.owns(owner,'sacred_bark') or H.owns(owner,'SacredBark')
 local parts={}
 for _,e in ipairs(item.effects or {})do
  local value=N((e.value or 0)*(bark and 2 or 1))
  if e.op=='discover'then
   parts[#parts+1]=expanded and '从3张不同的随机'..(kinds[e.kind] or '')..'牌中选择1张，加入手牌'..value..'份；本回合费用为0，手牌满时放入弃牌堆，仅本场战斗有效'
    or '3选1·'..(kinds[e.kind] or '')..'牌×'..value..'·本回合0费'
  elseif e.op=='generatePotions'then
   local slots=owner.potionCapacity or owner.potionSlots or owner.rules and owner.rules.player.potionSlots or 3
   parts[#parts+1]=expanded and '按总药水槽数（'..N(slots)..'槽）生成随机药水，依次填入空槽；战斗中不生成果汁，满槽的多余结果丢失。可在战斗外使用'
    or '按总槽数生成·战内无果汁'
  elseif e.op=='fatalRevive'then
   parts[#parts+1]=expanded and '受到致命伤害时自动消耗，回复最大生命'..value..'%的生命（至少1点）；无法主动使用；禁止治疗的遗物会阻止触发'
    or '致命时自动·回复'..value..'%'
  end
 end
 return #parts>0 and table.concat(parts,'，')or nil
end
function M.note(item)
 for _,e in ipairs(item.effects or {})do if e.op=='fatalRevive'then return '无法主动使用；在受到致命伤害时自动触发'end end
 return nil
end
function M.shop(item,owner)
 local bark=H.owns(owner,'sacred_bark') or H.owns(owner,'SacredBark')
 for _,e in ipairs(item.effects or {})do
  local value=N((e.value or 0)*(bark and 2 or 1))
  if e.op=='discover'then return '3选1'..(kinds[e.kind]or '')..'牌×'..value..'·仅本战\n本回合0费·满手进弃牌'
  elseif e.op=='generatePotions'then
   local slots=owner.potionSlots or owner.rules and owner.rules.player.potionSlots or owner.data and owner.data.rules.player.potionSlots or 3
   return '按'..N(slots)..'槽生成，填空槽\n溢出丢失·战内无果汁'
  elseif e.op=='fatalRevive'then return '致命自动回复'..value..'%（至少1）\n无法主动·禁止治疗时失效'end
 end
 return nil
end
return M
