package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,Actions=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_card_actions')
local d=P.prepare(D,'watcher');local seen={};for _,v in ipairs(d.cards.cards)do seen[v.id]=true end
for _,v in ipairs(D.cards.cards)do if not seen[v.id]then d.cards.cards[#d.cards.cards+1]=C.copy(v)end end
local s=C.new(d,{seed=1,enableStances=true,deck={'master_reality'},enemies={'cultist'}})
assert(C.play(s,s.hand[1].uid));Actions.apply(C,s,{effect={op='makeTempCardInHand',card='searing_blow',value=1},source=s.player})
local c=s.hand[1];assert(c.cardId=='searing_blow' and c.upgrades==2,'hand constructor and hand effect each upgrade repeatable card')
C.applyEffects(s,{{op='makeTempCardInDiscard',card='searing_blow',value=1}},s.player)
assert(s.discard[1].upgrades==1,'ordinary discard constructor upgrades once')
local original=Actions.fresh(C,s,'searing_blow');s.exhaust[1]=original
Actions.applyChoice(C,s,{effect={op='recoverExhaust',value=1}},original.uid)
assert(not original.upgraded,'retrieval is not generation')
print('WATCHER_MASTER_REALITY_GENERATION native hand/discard source entry counts and retrieval exclusion passed')
