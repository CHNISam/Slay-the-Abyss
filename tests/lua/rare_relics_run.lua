local Run=require('abyss_run')
local D=require('abyss_data')
local C=require('abyss_combat')
local A=require('abyss_actor')
local Cards=require('abyss_card_actions')
local Rare=require('abyss_rare_relics')
local count,failed=0,0
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then count=count+1;print('PASS rare Run '..name)else failed=failed+1;print('FAIL rare Run '..name..': '..tostring(why))end
end
local function start(ids)
 local r=Run.new(D,42)
 for _,id in ipairs(ids)do local ok,why=Run.obtainRelic(r,id);assert(ok,id..': '..tostring(why))end
 assert(Run.startCombat(r,'cultist_solo'));return r,r.combat
end
test('all 23 source identities can be obtained once through Run',function()
 local ids={'Ginger','Bird Faced Urn','Unceasing Top','Torii','StoneCalendar','Shovel','WingedGreaves','Thread and Needle','Turnip',
 'Ice Cream','Calipers','Prayer Wheel','Girya','Dead Branch','Du-Vu Doll','Pocketwatch','Incense Burner','Gambling Chip',
 'Peace Pipe','CaptainsWheel','Magic Flower',"Charon's Ashes",'Champion Belt'}
 for _,id in ipairs(ids)do
  local r=Run.new(D,42);assert(Run.obtainRelic(r,id),id)
  assert(r.relics[#r.relics]==Rare.localId(id),id);assert(not Run.obtainRelic(r,id),id..' duplicate')
 end
end)
test('Ginger and Turnip block debuffs before Artifact',function()
 local _,s=start({'Ginger','Turnip'});A.applyPower(s,s.player,'artifact',2,s.player)
 assert(not A.applyPower(s,s.player,'weak',2,s.enemies[1]));assert(not A.applyPower(s,s.player,'frail',2,s.enemies[1]))
 assert(s.player.statuses.artifact==2 and not s.player.statuses.weak and not s.player.statuses.frail)
end)
test('Torii reduces after block and before Tungsten',function()
 local _,s=start({'Torii','TungstenRod'});local hp=s.player.hp
 s.player.block=2;C.damage(s,s.enemies[1],s.player,7);assert(s.player.hp==hp)
 C.damage(s,s.enemies[1],s.player,6);assert(s.player.hp==hp-5)
end)
test('Thread applies real plated armor and Calipers preserves excess block',function()
 local _,s=start({'Thread and Needle','Calipers'});assert(s.player.statuses.plated_armor==4)
 s.player.block=31;A.resetBlock(s,s.player);assert(s.player.block==16)
end)
test('Magic Flower rounds combat healing once and Bloom still blocks',function()
 local _,s=start({'Magic Flower'});s.player.hp=20;C.applyEffects(s,{{op='heal',value=3}},s.player)
 assert(s.player.hp==25);s.relics[#s.relics+1]='mark_of_bloom';C.applyEffects(s,{{op='heal',value=3}},s.player);assert(s.player.hp==25)
end)
test('Magic Flower also modifies Blood Vial opening healing',function()
 local r=Run.new(D,42);assert(Run.obtainRelic(r,'Blood Vial'));assert(Run.obtainRelic(r,'Magic Flower'));r.hp=20
 assert(Run.startCombat(r,'cultist_solo'));assert(r.combat.player.hp==23)
end)
test('Bird Faced Urn heals after a normally played permanent power card',function()
 local r=Run.new(D,42);assert(Run.obtainRelic(r,'Bird Faced Urn'));assert(Run.obtainRelic(r,'Magic Flower'))
 assert(Run.obtainCard(r,'inflame'));r.deck={r.deck[#r.deck]};r.hp=20
 assert(Run.startCombat(r,'cultist_solo'));assert(C.play(r.combat,r.combat.hand[1].uid))
 assert(r.combat.player.hp==23 and r.combat.player.statuses.strength==2)
end)
test('Champion Belt successful Vulnerable queues actual Weak and respects Artifact',function()
 local _,s=start({'Champion Belt'});A.applyPower(s,s.enemies[1],'vulnerable',2,s.player);Cards.drain(C,s)
 assert(s.enemies[1].statuses.weak==1)
 A.applyPower(s,s.enemies[1],'artifact',1,s.enemies[1]);assert(not A.applyPower(s,s.enemies[1],'vulnerable',2,s.player))
 Cards.drain(C,s);assert(s.enemies[1].statuses.weak==1)
end)
test('Ashes damages and Dead Branch generates on actual exhaust movement',function()
 local _,s=start({"Charon's Ashes",'Dead Branch'});local card=s.hand[1];local hp=s.enemies[1].hp;local countHand=#s.hand
 assert(Cards.exhaust(C,s,card,s.hand));Cards.drain(C,s)
 assert(s.exhaust[#s.exhaust].uid==card.uid and s.enemies[1].hp==hp-3 and #s.hand==countHand)
end)
test('Native queued play drains exhaust relic effects through the shared action owner',function()
 local r=Run.new(D,42);assert(Run.obtainRelic(r,"Charon's Ashes"));assert(Run.obtainRelic(r,'Dead Branch'))
 assert(Run.obtainCard(r,'seeing_red'));local card=r.deck[#r.deck];r.deck={card}
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;local hp=s.enemies[1].hp
 assert(C.play(s,s.hand[1].uid));assert(s.enemies[1].hp==hp-3 and #s.exhaust==1 and #s.hand==1)
end)
test('Gambling Chip opens a real optional UID choice only at battle opening',function()
 local _,s=start({'Gambling Chip'});local p=assert(s.pendingChoice)
 assert(p.op=='rareGamblingChip'and p.multiple and p.allowEmpty)
 local uid=s.hand[1].uid;local n=#s.hand
 assert(C.chooseDiscard(s,{uid},p.token));assert(not s.pendingChoice and #s.hand==n)
 local found=false;for _,card in ipairs(s.discard)do if card.uid==uid then found=true end end
 assert(found);assert(not C.chooseDiscard(s,{},p.token))
 assert(C.endTurn(s));assert(not s.pendingChoice)
end)
test('Wheel Calendar and Incense use actual turn progression',function()
 local r,s=start({'CaptainsWheel','StoneCalendar','Incense Burner'})
 s.player.hp=1000;s.player.maxHp=1000;s.enemies[1].hp=10000;s.enemies[1].maxHp=10000
 assert(s.relicCounters.stone_calendar==1 and s.relicCounters.incense_burner==1)
 assert(C.endTurn(s));assert(s.turn==2)
 assert(C.endTurn(s));assert(s.turn==3 and s.player.block==18)
 for _=4,6 do assert(C.endTurn(s))end
 assert(s.relicCounters.incense_burner==0 and s.player.statuses.intangible==1)
 assert(C.endTurn(s));assert(s.turn==7);local hp=s.enemies[1].hp
 assert(C.endTurn(s));assert(s.enemies[1].hp==hp-52)
 r.phase='map';r.relicCounters.incense_burner=s.relicCounters.incense_burner
 assert(Run.startCombat(r,'cultist_solo'));assert(r.combat.relicCounters.incense_burner==3)
end)
test('Ice Cream preserves actual unused energy at the next recharge',function()
 local _,s=start({'Ice Cream'});assert(s.energy==3)
 assert(C.endTurn(s));assert(s.energy==6)
end)
assert(failed==0,tostring(failed)..' rare Run failures')
print('RARE_RELICS_RUN_PASS '..count)
