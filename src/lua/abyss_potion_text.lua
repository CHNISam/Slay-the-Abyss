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
  if e.op=='classPotion'and e.kind=='focus'then parts[#parts+1]='集中+'..value..'，本场战斗有效；不影响等离子充能球'
  elseif e.op=='classPotion'and e.kind=='capacity'then parts[#parts+1]='球槽+'..value..'，总数最多10；新增空槽，本场战斗有效'
  elseif e.op=='silentShivs'then parts[#parts+1]='获得'..value..'张小刀+；手牌满时进弃牌堆，仅本战有效'
  elseif e.op=='silentGhost'then parts[#parts+1]='获得'..value..'回合无实体；每次伤害最多1，回合结束衰减'
  elseif e.op=='discover'then
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
  if e.op=='classPotion'and e.kind=='focus'then return '集中+'..value..'（本场战斗）\n不影响等离子充能球'
  elseif e.op=='classPotion'and e.kind=='capacity'then return '球槽+'..value..'（最多10）\n新增空槽·本场战斗有效'
  elseif e.op=='silentShivs'then return '获得'..value..'张小刀+（仅本战）\n满手放入弃牌堆'
  elseif e.op=='silentGhost'then return '获得'..value..'回合无实体\n每次伤害最多1·回合结束衰减'
  elseif e.op=='discover'then return '3选1'..(kinds[e.kind]or '')..'牌×'..value..'·仅本战\n本回合0费·满手进弃牌'
  elseif e.op=='generatePotions'then
   local slots=owner.potionSlots or owner.rules and owner.rules.player.potionSlots or owner.data and owner.data.rules.player.potionSlots or 3
   return '按'..N(slots)..'槽生成，填空槽\n溢出丢失·战内无果汁'
  elseif e.op=='fatalRevive'then return '致命自动回复'..value..'%（至少1）\n无法主动·禁止治疗时失效'end
 end
 return nil
end
local function find(entries,id)
 for _,item in ipairs(entries or {})do if item.id==id then return item end end
end
local number=N
function M.describe(owner,id)
        local definition=find(owner.data.potions.potions,id);local special=definition and M.shop(definition,owner);if special then return special end
        local parts={}
        for _,effect in ipairs(definition and definition.effects or {}) do
            local value=number(effect.value or 0)
            if effect.op=='damage' then parts[#parts+1]='单敌固定伤害'..value
            elseif effect.op=='damageAll' then parts[#parts+1]='全体敌人伤害'..value..'（不受力量、虚弱、易伤影响）'
            elseif effect.op=='block' then parts[#parts+1]='自己固定格挡'..value
            elseif effect.op=='energy' then parts[#parts+1]='自己能量+'..value..'（本回合）'
            elseif effect.op=='draw' then parts[#parts+1]='抽'..value..'张牌'
            elseif effect.op=='upgradeHand' then parts[#parts+1]='升级全部可升级手牌（仅本场战斗）'
            elseif effect.op=='healPercent' then parts[#parts+1]='回复最大生命'..value..'%的生命'
            elseif effect.op=='increaseMaxHp' then parts[#parts+1]='最大生命+'..value..'，并回复'..value..'生命'
            elseif effect.op=='exhaustMany' then parts[#parts+1]='选择任意张手牌消耗（可不选）'
            elseif effect.op=='discardRedraw' then parts[#parts+1]='选择任意张手牌丢弃，再抽等量牌'
            elseif effect.op=='discardToHand' then parts[#parts+1]='选择'..value..'张弃牌回手，本回合费用为0'
            elseif effect.op=='randomizeHandCost' then parts[#parts+1]='手牌战斗费用随机改为0至3'
            elseif effect.op=='escape' then parts[#parts+1]='逃离战斗，不获得奖励（Boss或背袭敌人房间不可用）'
            elseif effect.op=='playTopCards' then parts[#parts+1]='免费打出牌堆顶'..value..'张牌，目标随机'
            elseif effect.op=='gainTemporaryStrength' or effect.op=='gainTemporaryDexterity' then
                local status=find(owner.data.statuses.statuses,effect.status)
                parts[#parts+1]='自己'..status.name..'+'..value..'，回合结束时失去'..value
            elseif effect.op=='gainStatus' or effect.op=='applyStatus' then
                local status=find(owner.data.statuses.statuses,effect.status)
                parts[#parts+1]=(effect.op=='applyStatus' and '单敌' or '自己')..(status and status.name or effect.status)..value
                    ..(status and status.stack=='duration' and '回合' or effect.status=='regen' and '（回合结束回复）' or '')
            end
        end
        return table.concat(parts,'，')
    end

return M
