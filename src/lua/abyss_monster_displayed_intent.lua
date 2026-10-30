-- AbstractMonster.createIntent/applyPowers/getIntentImg state, separate from selected move.
-- No gameplay mutation, random consumption or implicit per-frame recalculation.
local Source=require('abyss_monster_source_intents')
local number=require('abyss_numbers').integer
local M={}
local function copy(value)
 if type(value)~='table'then return value end
 local result={};for key,item in pairs(value)do result[key]=copy(item)end;return result
end
function M.new()
 return {intent='NONE',nextMove=-1,intentBaseDmg=-1,intentDmg=-1,intentMultiAmt=0,isMultiDmg=false}
end
function M.createIntent(state,move,calculate)
 assert(move and move.intent,'source selected move required')
 state.intent,state.nextMove,state.intentBaseDmg=move.intent,move.id,move.baseDamage
 state.descriptor=copy(move)
 if move.baseDamage>-1 then
  state.intentDmg=calculate(move.baseDamage)
  if move.isMultiDamage then state.intentMultiAmt,state.isMultiDmg=move.multiplier,true
  else state.intentMultiAmt,state.isMultiDmg=-1,false end
 end
end
function M.applyPowers(state,selected,calculate)
 -- Source uses the CURRENT selected move's base, not copied intentBaseDmg.
 -- It deliberately does not copy selected enum/multiplier until createIntent.
 if selected and selected.baseDamage>-1 then state.intentDmg=calculate(selected.baseDamage)end
end
function M.face(state)
 local face=state.descriptor and copy(state.descriptor.face)or {value='',kind='unknown',rows={}}
 face.sourceEnum=state.intent
 face.worldDamage=state.intentDmg
 face.worldTimes=state.isMultiDmg and state.intentMultiAmt or 1
 face.sourceTexture,face.worldKind,face.worldVisible=Source.visual(state.intent,state.intentDmg,face.worldTimes)
 if state.intent:sub(1,6)=='ATTACK'then
  face.value=number(state.intentDmg)..(state.isMultiDmg and 'x'..number(state.intentMultiAmt)or '')
 else face.value=''end
 return face
end
return M
