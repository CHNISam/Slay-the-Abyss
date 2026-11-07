package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Colorless=require('abyss_colorless_cards')
local CombatCatalog=require('abyss_combat_catalog')
local function graph(label,value)
 if COLORLESS_GRAPH_WRITE then COLORLESS_GRAPH_WRITE(value,label)end
end
local function base()
 local alias={marker='shared'}
 local card={id='existing',type='attack',alias=alias}
 return {cards={cards={card,card},sourcePools={prior=alias},extra=alias},
  statuses={statuses={{id='panache',kind='existing',alias=alias}},extra=alias},extra=alias}
end
local function valid(result)
 assert(#result.cards.cards==41,'catalog contains all 39 definitions')
 assert(#result.cards.sourcePools.srcColorless==35,'source pool has 35 ordinary cards')
 assert(result.cards.sourcePools.srcColorless[1]=='madness' and result.cards.sourcePools.srcColorless[35]=='dark_shackles','source pool order')
 assert(#result.cards.sourcePools.colorlessShop.rare==15 and #result.cards.sourcePools.colorlessShop.uncommon==20,'shop rarity pools')
 assert(result.cards.cards[1]==result.cards.cards[2],'preexisting aliases preserved')
end
for _,owned in ipairs({false,true})do
 local input=base();local oldCards,oldStatuses,oldPools=input.cards,input.statuses,input.cards.sourcePools
 local result=Colorless.withCards(input,owned);valid(result)
 assert((input==result)==owned,'owned graph publication')
 if owned then assert(result.cards==oldCards and result.statuses==oldStatuses and result.cards.sourcePools==oldPools,'owned containers remain')
 else assert(result.cards~=oldCards and result.statuses~=oldStatuses and result.cards.sourcePools~=oldPools,'unowned containers detach')end
 assert(result.cards.cards[1]==input.cards.cards[1],'preexisting definition identity')
 assert(result.statuses.statuses[1]==input.statuses.statuses[1],'preexisting status identity')
 assert(result.extra==input.extra and result.cards.extra==input.extra,'unmodified outer aliases')
 assert(Colorless.withCards(result)==result,'complete registration is idempotent')
 graph('registered '..tostring(owned),{input=input,result=result,oldCards=oldCards,oldStatuses=oldStatuses,oldPools=oldPools})
 table.remove(result.cards.cards)
 local repaired=Colorless.withCards(result,owned);valid(repaired)
 graph('repaired '..tostring(owned),{input=result,result=repaired})
end
local first=Colorless.withCards(base());local second=Colorless.withCards(base())
assert(first.cards.cards[3]~=second.cards.cards[3] and first.cards.cards[3].effects~=second.cards.cards[3].effects,'private templates copied per registration')
first.cards.cards[3].effects[1].value=999;assert(second.cards.cards[3].effects[1].value~=999,'template mutation isolated')
graph('independent registration copies',{first=first,second=second})
local saved,description,icon=Colorless.withCards,Colorless.powerDescription,Colorless.powerIcon
local calls={}
Colorless.powerDescription=function(actor,id)calls[#calls+1]={actor=actor,id=id};return 'replacement '..id end
local changed=saved(base(),true)
for _,status in ipairs(changed.statuses.statuses)do if status.id~='panache'then assert(status.description=='replacement '..status.id,'saved registrar reads dynamic description')end end
graph('dynamic description',{result=changed,calls=calls})
Colorless.powerDescription=description
local sentinel={fault='description failure'};local partial=base()
Colorless.powerDescription=function()error(sentinel,0)end
local ok,err=pcall(saved,partial,true);assert(not ok and err==sentinel,'description error identity')
assert(#partial.cards.cards==41 and partial.colorlessCards==nil,'cards are published before status error')
graph('partial registration failure',{input=partial,result=table.pack(ok,err)})
Colorless.powerDescription=description
Colorless.withCards=function(data)return data end
local original=base();local prepared,catalog=CombatCatalog.prepare(original)
assert(prepared==original and catalog.cards.existing~=original.cards.cards[1],'CombatCatalog consumes dynamic registration and copies definitions')
graph('dynamic catalog preparation',{input=original,prepared=prepared,catalog=catalog})
for _,value in ipairs({false,'sentinel'})do
 Colorless.withCards=value;assert(Colorless.withCards==value,'ordinary replacement exact')
 local works=pcall(CombatCatalog.prepare,base());assert(not works,'invalid registrar not hidden by fallback')
end
Colorless.withCards=nil;assert(Colorless.withCards==nil and not pcall(CombatCatalog.prepare,base()),'nil registration remains nil')
Colorless.withCards=saved;Colorless.powerIcon=false;assert(Colorless.powerIcon==false);Colorless.powerIcon=nil;assert(Colorless.powerIcon==nil);Colorless.powerIcon=icon
Colorless.powerDescription=false;assert(Colorless.powerDescription==false and not pcall(saved,base()),'false description preserved')
Colorless.powerDescription=nil;assert(Colorless.powerDescription==nil and not pcall(saved,base()),'nil description preserved');Colorless.powerDescription=description
local source=base();local done,definitions=CombatCatalog.prepare(source)
assert(definitions.cards.existing~=source.cards.cards[1] and definitions.cards.existing.alias~=source.extra,'private original catalog definitions')
local found;for _,d in ipairs(done.cards.cards)do if d.id=='swift_strike'then found=d end end
assert(definitions.cards.swift_strike==found,'new registration already owns definition')
graph('catalog ownership',{source=source,prepared=done,catalog=definitions})
print('ok colorless catalog registration, ownership, dynamic interfaces and failure order')
