-- Real class profiles and the complete source metadata introduced by 39c40f8.
local Profiles=require('abyss_character_profiles')
local Pools=require('abyss_class_card_pools')
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local Data=require('abyss_data')
local rows={
 {'silent','deadly_poison','Deadly Poison','sneaky_strike','Underhanded Strike'},
 {'defect','cold_snap','Cold Snap','claw','Gash'},
 {'watcher','cut_through_fate','CutThroughFate','pressure_points','PathToVictory'},
}
local failures={}
for _,row in ipairs(rows)do
 local ok,reason=pcall(function()
 local data=Profiles.prepare(Data,row[1]);Pools.apply(data,row[1])
 local metadata=data.cards.sourcePools.cardSourceMetadata
 assert(metadata[row[2]].sourceId==row[3] and metadata[row[4]].sourceId==row[5])
 local s=C.new(data,{enemies={'bronze_orb','cultist'},deck={},seed=42,cardRandomSeed='42'})
 local first={cardId=row[2],uid=700,upgraded=false}
 local second={cardId=row[4],uid=701,upgraded=true}
 s.draw={second,first}
 local rng=R.cloneState(s.cardRandomRng)
 local expected=({first,second})[R.randomInt(rng,1)+1]
 local before=s.cardRandomRng.counter
 C.applyEffects(s,{{op='enemyStasis',value=1}},s.enemies[1],s.player)
 local held=s.act2StasisCards[s.enemies[1].id]
 assert(held==expected,row[1]..' Stasis did not sort by original cardID: '..held.cardId..' ~= '..expected.cardId)
 assert(s.cardRandomRng.counter==before+1 and #s.draw==1)
 end)
 print((ok and 'PASS' or 'FAIL')..' Stasis source cardID sort '..row[1])
 if not ok then failures[#failures+1]=reason end
end
assert(#failures==0,table.concat(failures,'\n'))
print('ACT2_STASIS_SOURCE_ORDER_PASS 3')
