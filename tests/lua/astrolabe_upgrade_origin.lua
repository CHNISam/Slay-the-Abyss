local Run=require('abyss_run');local Data=require('abyss_data')
local View=require('abyss_card_origin_view')
local r=Run.new(Data,'42',{experimental=true,character='ironclad'})
r.phase='reward'
assert(Run.obtainRelic(r,'astrolabe'))
local old,nextUid={},r.nextDeckUid
for i=1,3 do old[i]=r.deck[i].uid end
for _,uid in ipairs(old)do assert(require('abyss_boss_relics').select(r,uid))end
assert(not r.pendingBossRelic)
local count=0
for _,card in ipairs(r.deck)do
 for _,uid in ipairs(old)do assert(card.uid~=uid,'selected card must be removed')end
 if card.uid>=nextUid then
  count=count+1;assert(card.upgraded,'Astrolabe replacement must retain its actual upgrade')
  local origin=card.lastUpgradeOrigin
  assert(origin and origin.kind=='obtained_upgraded' and origin.source.relicId=='astrolabe','Astrolabe replacement must name its real source')
  assert(View.describe(r,card,false):find('星盘',1,true),'real card detail must name Astrolabe')
 end
end
assert(count==3)
print('ASTROLABE_UPGRADE_ORIGIN_PASS 3')
