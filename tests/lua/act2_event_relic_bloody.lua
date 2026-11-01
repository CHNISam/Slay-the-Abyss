local H=dofile('tests/helpers/act2_event_relics.lua')
local eq,same,test=H.eq,H.same,H.test
local function idolBattle(extra)
 local ids={'Golden Idol','Bloody Idol'};for _,id in ipairs(extra or {})do ids[#ids+1]=id end
 local r=H.run(ids,nil,function(staged)staged.hp=30 end)
 local originals={};for _,card in ipairs(r.deck)do originals[#originals+1]=card.uid end
 for _,uid in ipairs(originals)do assert(H.Run.removeCard(r,uid))end
 assert(H.Run.obtainCard(r,'bludgeon',{upgraded=true}));assert(H.Run.obtainCard(r,'hand_of_greed'))
 assert(H.Run.startCombat(r,'cultist_solo'));return r,r.combat
end
test('real HandOfGreed kill gains gold and BloodyIdol heals5 through actual combat heal action',function()
 local r,s=idolBattle();assert(H.play(r,'bludgeon'));assert(H.Run.endTurn(r));local hp=s.player.hp;local gold=s.player.gold
 assert(H.play(r,'hand_of_greed'));eq(s.player.hp,hp+5);eq(s.player.gold,gold+20)
 local found=false;for _,e in ipairs(s.events)do if e.kind=='heal'and e.detail.amount==5 then found=true end end;assert(found)
end)
test('controlled Ectoplasm owned-flag interaction prevents combat gold and BloodyIdol heal, not acquisition evidence',function()
 local r,s=idolBattle();r.relics[#r.relics+1]='ectoplasm';s.relics[#s.relics+1]='ectoplasm';assert(H.play(r,'bludgeon'));assert(H.Run.endTurn(r));local hp,gold=s.player.hp,s.player.gold
 assert(H.play(r,'hand_of_greed'));eq(s.player.hp,hp);eq(s.player.gold,gold)
end)
test('real MarkOfTheBloom preserves gold but blocks BloodyIdol healing',function()
 local r,s=idolBattle({'Mark of the Bloom'});assert(H.play(r,'bludgeon'));assert(H.Run.endTurn(r));local hp,gold=s.player.hp,s.player.gold
 assert(H.play(r,'hand_of_greed'));eq(s.player.hp,hp);eq(s.player.gold,gold+20)
end)
test('gold outside combat heals exactly5 and does not refund HP when no gold is gained',function()
 local r=H.run({'Golden Idol','Bloody Idol'},nil,function(staged)staged.hp=30 end)
 eq(H.Run.gainGold(r,1),1);eq(r.hp,35);eq(H.Run.gainGold(r,0),0);eq(r.hp,35)
 -- Existing Ectoplasm hook-only owned-state fixture; no fake definition or supported-acquisition claim.
 r.relics[#r.relics+1]='ectoplasm';local gold=r.gold;eq(H.Run.gainGold(r,1),0);eq(r.gold,gold);eq(r.hp,35)
end)
test('late combat gold-heal failure rolls back attack damage/gold/HP/piles/RNG for exact retry',function()
 local r,s=idolBattle();assert(H.play(r,'bludgeon'));assert(H.Run.endTurn(r));local before=H.C.copy(r,{[r.data]=r.data});local old=H.E.emit
 H.E.emit=function(state,kind,detail)local result=old(state,kind,detail);if kind=='heal'and detail.amount==5 then error('late BloodyIdol')end;return result end
 local called=pcall(H.play,r,'hand_of_greed');H.E.emit=old;eq(called,false);same(r,before)
 assert(H.play(r,'hand_of_greed'))
end)
test('MagicFlower joint actual combat gainGold heals5 to8 exactly once, not twice-modified12',function()
 local r,s=idolBattle({'Magic Flower'});assert(H.play(r,'bludgeon'));assert(H.Run.endTurn(r));local hp=s.player.hp
 assert(H.play(r,'hand_of_greed'));eq(s.player.hp,hp+8)
end)
test('active actual GoldenIdol replacement publishes BloodyIdol in the same battle slot and heals on real gold',function()
 local r,s=H.battle({'Golden Idol'},{{cardId='bludgeon',upgraded=true},'hand_of_greed'},function(staged)staged.hp=30 end)
 local slot;for i,id in ipairs(s.relics)do if id=='golden_idol'then slot=i end end;assert(slot)
 assert(H.Run.obtainRelic(r,'Bloody Idol'));s=r.combat;eq(s.relics[slot],'bloody_idol')
 assert(H.play(r,'bludgeon'));assert(H.Run.endTurn(r));local hp=s.player.hp;assert(H.play(r,'hand_of_greed'));eq(s.player.hp,hp+5)
end)
H.finish('ACT2_EVENT_RELIC_BLOODY')
