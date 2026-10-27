package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,R=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_sts_random')
local Foreign=require('abyss_watcher_foreign_pool')
for _,up in ipairs({false,true})do
 local r=Run.new(D,42,{character='watcher',experimental=true});r.deck={{uid=31,cardId='foreign_influence',upgraded=up}};r.relics={}
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat
 local cr,dr=R.cloneState(s.cardRandomRng),R.cloneState(s.cardRng);local expected,seen={},{}
 while #expected<3 do
  local n=R.randomInt(cr,99);local rarity=n<55 and 'common'or n<85 and'uncommon'or'rare'
  R.randomLongHex(cr);local pool=Foreign[rarity];local source=pool[R.randomInt(dr,#pool-1)+1]
  if not seen[source]then seen[source]=true;expected[#expected+1]=source end
 end
 assert(Run.play(r,s.hand[1].uid),'ordinary Run Foreign Influence must resolve the complete fixed candidate pool')
 local p=assert(s.pendingChoice);assert(p.kind=='foreign'and #p.cards==3)
 for i,c in ipairs(p.cards)do
  local def=assert(s.catalog.cards[c.cardId]);assert(def.sourceId==expected[i],def.id..' source identity')
  assert(require('abyss_card_capability').isImplemented(def),'source candidate must actually execute: '..def.id)
 end
 assert(s.cardRandomRng.counter==cr.counter and s.cardRng.counter==dr.counter,'Foreign Influence must preserve both source streams')
 assert(Run.chooseCard(r,p.token,1));local selected=s.hand[1];assert(selected and not selected.deckUid)
 s.energy=10;assert(Run.play(r,selected.uid,1),'chosen foreign attack must execute through ordinary Run')
 local totals={red=0,green=0,blue=0,purple=0}
 for _,def in ipairs(r.data.cards.cards)do if totals[def.color]and def.rarity~='special'and def.type~='status'and def.type~='curse'then totals[def.color]=totals[def.color]+1 end end
 for color,n in pairs(totals)do assert(n==75,color..' complete catalog count '..n)end
end
print('RUN_CARD_CATALOG_FOREIGN_PASS ordinary base/upgraded Foreign Influence, complete candidates, dual RNG and real selected-card use')
