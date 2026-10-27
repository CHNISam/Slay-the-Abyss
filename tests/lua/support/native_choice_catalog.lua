-- Controlled legacy command fixture. Ordinary Run now owns the complete
-- adapted catalog; the native driver/DeckUI ABI still uses native definitions.
return function(state)
 local C=require('abyss_combat')
 local native=C.new(require('abyss_data'),{seed=1,deck={}})
 state.catalog.cards=native.catalog.cards
 state.experimentalMechanics=nil
end
