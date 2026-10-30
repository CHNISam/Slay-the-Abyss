local D=require('abyss_monster_displayed_intent')
local function move(id,intent,base,times,multi)
 return {id=id,intent=intent,baseDamage=base,multiplier=times,isMultiDamage=multi,face={value='selected',kind='attack',rows={{name=id}}}}
end
local calls=0
local function calculate(base)calls=calls+1;return base+1 end
local state=D.new();assert(D.face(state).sourceEnum=='NONE')
local first=move('first','ATTACK',4,2,true)
D.createIntent(state,first,calculate)
assert(state.intentBaseDmg==4 and state.nextMove=='first' and state.intentMultiAmt==2)
assert(D.face(state).value=='5x2' and D.face(state).sourceTexture=='INTENT_ATK_3')
local nextMove=move('second','ATTACK',11,3,true)
assert(D.face(state).value=='5x2' and calls==1,'selecting or rendering another attack cannot call createIntent')
D.applyPowers(state,nextMove,calculate)
assert(state.intentBaseDmg==4 and state.nextMove=='first' and state.intentMultiAmt==2,'applyPowers must not copy selected move identity/multi/base')
assert(D.face(state).value=='12x2' and D.face(state).sourceTexture=='INTENT_ATK_5','source hybrid: CURRENT selected base, PREVIOUS displayed multiplier')
D.createIntent(state,nextMove,calculate)
assert(D.face(state).value=='12x3' and state.intentBaseDmg==11 and state.nextMove=='second')
nextMove.face.rows[1].name='foreign mutation';nextMove.baseDamage=999
assert(state.descriptor.face.rows[1].name=='second' and state.intentBaseDmg==11,'display descriptor must be detached')
D.createIntent(state,move('charge','UNKNOWN',-1,1,false),calculate)
local before=calls
D.applyPowers(state,move('selected-attack','ATTACK',9,6,true),calculate)
assert(calls==before+1 and state.intentDmg==10)
assert(state.intent=='UNKNOWN' and state.intentBaseDmg==-1 and state.intentMultiAmt==3,'nonattack create retains original multi field until next attack create')
assert(D.face(state).sourceTexture=='INTENT_UNKNOWN_L' and not D.face(state).worldVisible and D.face(state).value=='')
local count=calls;D.face(state);D.face(state);assert(calls==count,'render must not recalculate damage')
print('MONSTER_DISPLAYED_INTENT_SOURCE_PASS')
