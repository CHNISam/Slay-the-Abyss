-- Read-only final-act projection. Core components own plans and arithmetic.
local Heart=require('abyss_corrupt_heart')
local Pair=require('abyss_spire_pair')
local Actors=require('abyss_actor')
local Copy=require('abyss_copy').copy
local Theme=require('abyss_theme')
local number=require('abyss_numbers').integer
local M={}
function M.project(state,enemy,intent)
 if not Heart.owns(enemy)and not Pair.owns(enemy)then return intent end
 local result=Copy(intent)
 if Heart.owns(enemy)then result.effects=Heart.previewEffects(enemy,intent)
 else result.effects=Pair.previewEffects(state,enemy,intent,function(s,e,base)return Actors.attackAmount(s,e,s.player,base)end)end
 for _,effect in ipairs(result.effects)do
  -- PainfulStabs uses -1 as a no-number BUFF sentinel, never a lost stack.
  if effect.op=='gainStatus'and effect.status=='painful_stabs'and effect.value==-1 then effect.op='heartPainfulStabs'end
 end
 return result
end
local function row(v,name,text,kind,note)
 v.result[#v.result+1]=text
 v.rows[#v.rows+1]={icon=kind,colour=kind=='buff'and Theme.color.buff or Theme.color.debuff,name=name,text=text,note=note}
end
local function statusCard(v,effect)
 local name=assert(v.state.catalog.cards[effect.card]).name
 local amount=number(effect.value)
 row(v,'塞入「'..name..'」×'..amount,'将 '..amount..' 张「'..name..'」随机放入你的抽牌堆','debuff')
end
local function bash(v,effect)
 local amount=number(math.abs(effect.value))
 local target=effect.focusPossible and '随机使你失去 '..amount..' 层力量或集中' or '使你失去 '..amount..' 层力量'
 row(v,'攻击后削弱',target,'debuff',effect.focusPossible and '空球位同样满足随机选择条件' or nil)
end
local function painful(v)
 local status=assert(v.state.catalog.statuses.painful_stabs)
 local wound=assert(v.state.catalog.cards.wound).name
 row(v,status.name,'获得'..status.name..'：普通攻击使你损失生命时，向弃牌堆加入1张「'..wound..'」','buff','持续本场战斗')
end
local handlers={heartStatusDraw=statusCard,spireBashDebuff=bash,heartPainfulStabs=painful}
function M.describe(v,effect)
 local describe=handlers[effect.op]
 if not describe then return false end
 describe(v,effect);return true
end
return M
