local I=require('abyss_monster_source_intents')
local actor={id='jaw_1',definitionId='jaw_worm'}
assert(I.enum(actor,{id='jaw_worm_2'})=='ATTACK_DEFEND')
assert(I.enum(actor,{id='jaw_worm_3'})=='DEFEND_BUFF')
local nob={definitionId='gremlin_nob'}
assert(I.enum(nob,{id='gremlin_nob_2'})=='ATTACK_DEBUFF')
nob.canVuln=false;assert(I.enum(nob,{id='gremlin_nob_2'})=='ATTACK')
for _,enum in ipairs({'ATTACK','ATTACK_BUFF','ATTACK_DEBUFF','ATTACK_DEFEND'})do
 local key,kind,draw=I.visual(enum,8,2)
 assert(key=='INTENT_ATK_4'and kind=='attack'and draw,'world attacks never use tooltip composites')
 for tier,amount in ipairs({4,9,14,19,24,29,30})do assert(I.visual(enum,amount,1)=='INTENT_ATK_'..tier)end
end
assert(I.visual('STUN')==nil)
local key,_,visible=I.visual('UNKNOWN');assert(key=='INTENT_UNKNOWN_L'and visible==false)
assert(I.visual('DEFEND_DEBUFF')=='INTENT_DEFEND_L')
assert(I.visual('STRONG_DEBUFF')=='INTENT_DEBUFF2_L')
assert(not pcall(I.enum,actor,{id='foreign-move'}),'foreign current-species move must not silently infer an enum')
assert(I.enum({definitionId='external-fixture'},{id='test'})==nil)
assert(actor.id=='jaw_1'and actor.definitionId=='jaw_worm'and actor.intent==nil,'render metadata mutated actor')
print('SOURCE_MONSTER_INTENTS_PASS world/tooltip distinction, exact thresholds and explicit provenance boundary')
