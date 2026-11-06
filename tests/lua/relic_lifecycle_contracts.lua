local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
do
 local s=F.C.new(F.D,{seed=42,deck={'defend'},enemies={'cultist'}})
 F.hooks.bindBattle(s,{'orichalcum'});local root=F.root(s)
 F.call(root,'public owner-end hook exact fixed block',F.hooks.onPlayerEndTurn,s)
 F.eq(s.player.block,6,'Orichalcum public hook')
 s.player.block=1;F.call(root,'public owner-end hook observes existing block',F.hooks.onPlayerEndTurn,s)
 F.eq(s.player.block,1,'existing block suppresses')
end
do
 local r=F.R.new(F.D,42);local root=F.root(r)
 assert(F.R.obtainRelic(r,'molten_egg'))
 F.call(root,'actual Tiny House private card reward preview',F.R.obtainRelic,r,'tiny_house')
 local offer=assert(r.pendingBossRelic);assert(offer.cards and #offer.cards>0)
 root.offer=offer;local uid,count,gold=r.nextDeckUid,#r.deck,r.gold
 F.call(root,'private existing reward preview preserves permanent owner',F.hooks.previewCardReward,r,offer,true)
 F.eq(r.nextDeckUid,uid,'preview no UID allocation');F.eq(#r.deck,count,'preview no permanent insertion');F.eq(r.gold,gold,'preview no gold')
end
F.finish('contracts')
