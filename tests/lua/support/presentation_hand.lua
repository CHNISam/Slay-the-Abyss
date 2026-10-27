-- Static presentation fixture only. Preserve and check Deus Ex's real draw
-- trigger before staging that same exhausted instance for the render matrix.
return function(state,id)
 if state.hand[1] and state.hand[1].cardId==id then return end
 assert(id=='deus_ex_machina','render matrix lost its requested card: '..id)
 local found,index
 for i,card in ipairs(state.exhaust)do if card.cardId==id then assert(not found);found,index=card,i end end
 assert(found,'Deus Ex must exhaust itself when drawn')
 assert(#state.hand==(found.upgraded and 3 or 2),'Deus Ex generated the wrong Miracle count')
 for _,card in ipairs(state.hand)do assert(card.cardId=='miracle' and card.uid~=found.uid)end
 assert(state.exhaust[index]==found)
 while #state.hand>0 do state.discard[#state.discard+1]=table.remove(state.hand)end
 require('abyss_card_actions').applyChoice(require('abyss_combat'),state,{effect={op='recoverExhaust',value=1}},found.uid)
 assert(state.hand[1]==found and state.hand[1].cardId==id)
end
