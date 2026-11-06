local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
local C,H,R=F.C,F.hooks,F.R
local P=require('abyss_character_profiles')
for _,ids in ipairs({{}, {'ectoplasm'}, {'bloody_idol'}, {'bloody_idol','mark_of_bloom'}, {'bloody_idol','magic_flower'}})do
 local s=C.new(P.prepare(F.D,'watcher'),{seed=1,cardRandomSeed='1',shuffleSeed='1',enableStances=true,deck={'wish'},enemies={'cultist'}})
 H.bindBattle(s,ids);s.energy=20;local card=s.hand[1];local root=F.root(s);root.playing=card
 assert(C.play(s,card.uid,1));local token=assert(s.pendingChoice).token;local gold=s.player.gold
 local ok=F.call(root,'real Wish temporary gainGold owner '..table.concat(ids,','),C.chooseCard,s,token,2)
 local broken=ids[1]=='bloody_idol'and ids[2]~='mark_of_bloom'
 F.eq(ok,not broken,'original missing health fields behavior preserved')
 if not broken then F.eq(s.player.gold,gold+(ids[1]=='ectoplasm'and 0 or 25),'Wish owner gold writeback')end
end
do
 local r=R.new(F.D,42);for _,id in ipairs({'omamori','ceramic_fish','molten_egg'})do assert(R.obtainRelic(r,id))end
 local root=F.root(r);local uid,count,gold=r.nextDeckUid,#r.deck,r.gold
 F.call(root,'Omamori before permanent UID allocation',R.obtainCard,r,'parasite')
 F.eq(r.nextDeckUid,uid);F.eq(#r.deck,count);F.eq(r.gold,gold);F.eq(r.relicCounters.omamori,1)
 F.call(root,'Egg and Ceramic Fish real obtain origin',R.obtainCard,r,'strike')
 local card=r.deck[#r.deck];F.eq(card.upgraded,true,'Egg upgraded actual permanent card');assert(card.lastUpgradeOrigin,'real origin record')
end
do
 local r=R.new(F.D,42);assert(R.obtainRelic(r,'darkstone_periapt'));assert(R.startCombat(r,'cultist_solo'))
 local root=F.root(r);F.call(root,'ordinary Run refuses unmatched combat health',R.obtainCard,r,'parasite')
 local card={uid=r.nextDeckUid,cardId='parasite',upgraded=false};local d=r.combat.catalog.cards.parasite
 local health=function()error('health adapter must not run',0)end
 F.call(root,'direct rule wrong combatContext refuses',H.onObtainCard,r,card,d,{combatContext={},increaseMaxHp=health})
 local marker=function()return 'original function error'end;root.marker=marker
 local api={combatContext=r.combat,increaseMaxHp=function()error(marker,0)end}
 local ok,why=F.call(root,'matched health adapter preserves function error',H.onObtainCard,r,card,d,api)
 F.eq(ok,false);F.eq(rawequal(why,marker),true,'same function error object')
end
F.finish('special')
