local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
dofile('tests/lua/common_relic_equipment.lua')
local R,B,Shop=F.R,F.boss,F.shop
do
 local r=R.new(F.D,42);local root=F.root(r)
 assert(R.obtainRelic(r,'empty_cage'));local uid=r.deck[1].uid
 F.call(root,'boss default adapter first selection',B.select,r,uid)
 F.call(root,'boss duplicate selection rejected',B.select,r,uid)
 F.call(root,'boss default adapter final selection',B.select,r,r.deck[2].uid)
 F.eq(r.pendingBossRelic,nil,'two selected cards removed')
end
do
 local r=R.new(F.D,42);assert(R.obtainRelic(r,'calling_bell'));local root=F.root(r)
 F.call(root,'boss reward default Run adapter',B.claim,r,'relic',1)
 F.call(root,'boss already claimed refuses',B.claimRelic,r,1)
 F.call(root,'boss finishes pending rewards',B.claim,r,'done')
end
do
 local r=R.new(F.D,42);local original=r.deck[1];original.upgraded=true;original.upgrades=1
 assert(R.obtainRelic(r,'dollys_mirror'));local root=F.root(r)
 F.call(root,'mirror ordinary public no-adapter selection',Shop.chooseMirror,r,original.uid)
 F.eq(r.deck[#r.deck].cardId,original.cardId,'mirror identity');assert(r.deck[#r.deck].uid~=original.uid)
end
do
 local r=R.new(F.D,42);local root=F.root(r);local check=F.unchanged(r)
 local original=F.hooks.onEquip;local sentinel={kind='post-equipment-error'};root.sentinel=sentinel
 F.hooks.onEquip=function(owner,id,...)
  local ok,why=original(owner,id,...);if id=='whetstone'then error(sentinel,0)end;return ok,why
 end
 local called,accepted=F.call(root,'real obtain rollback after equipment RNG and upgrades',R.obtainRelic,r,'whetstone')
 F.hooks.onEquip=original;F.eq(called,true,'Run catches callback');F.eq(accepted,false,'outer command rejected');check()
 assert(R.obtainRelic(r,'whetstone'));F.snapshot('real equipment retry',root)
end
F.finish('session')
