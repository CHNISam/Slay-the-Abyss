local O=require('abyss_card_origin');local V=require('abyss_card_origin_view')
local C=require('abyss_combat')
local function fresh()
 local r={phase='map',deck={{uid=1,cardId='strike',upgraded=true,upgrades=1}}}
 O.record(r,r.deck[1],{upgraded=false,upgrades=0},'permanent_upgrade',{kind='relic',relicId='whetstone'})
 return r
end
local n,failed=0,0
local function check(name,fn)local ok,why=pcall(fn);n=n+1;if not ok then failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))end
check('same UID new unupgraded identity cannot borrow old source',function()
 local before=fresh();local r=C.copy(before);r.deck[1].cardId='defend';r.deck[1].upgraded=false;r.deck[1].upgrades=0
 O.observe(r,before)
 assert(not r.deck[1].lastUpgradeOrigin,'identity change must clear obsolete receipt')
 assert(V.describe(r,r.deck[1],false)=='')
end)
check('view independently rejects another card identity receipt',function()
 local r=fresh();r.deck[1].cardId='defend'
 assert(not V.describe(r,r.deck[1],false):find('来源：',1,true))
end)
check('downgrade is not permanent upgrade',function()
 local before=fresh();local r=C.copy(before);r.deck[1].upgraded=false;r.deck[1].upgrades=0
 O.observe(r,before);assert(not r.deck[1].lastUpgradeOrigin)
 assert(V.describe(r,r.deck[1],false)=='')
end)
check('view independently rejects mismatched after flag',function()
 local r=fresh();r.deck[1].upgraded=false
 assert(V.describe(r,r.deck[1],false)=='')
end)
check('historic downgrade receipt is neither shown nor retained',function()
 local r=fresh();r.deck[1].upgraded=false;r.deck[1].upgrades=0
 r.deck[1].lastUpgradeOrigin.after={upgraded=false,upgrades=0}
 assert(V.describe(r,r.deck[1],false)=='')
 O.observe(r,C.copy(r));assert(not r.deck[1].lastUpgradeOrigin)
end)
check('same count fresh explicit record survives rollback and reupgrade',function()
 local before=fresh();local r=C.copy(before)
 r.deck[1].upgraded=false;r.deck[1].upgrades=0
 local a=O.state(r.deck[1]);r.deck[1].upgraded=true;r.deck[1].upgrades=1
 O.record(r,r.deck[1],a,'permanent_upgrade',{kind='event',eventId='upgrade_shrine'})
 O.observe(r,before)
 assert(r.deck[1].lastUpgradeOrigin.source.eventId=='upgrade_shrine')
end)
check('same-count replacement explicit origin stays authoritative',function()
 local before=fresh();local r=C.copy(before);r.deck[1].cardId='defend'
 O.record(r,r.deck[1],{upgraded=false,upgrades=0},'obtained_upgraded',{kind='relic',relicId='astrolabe'})
 O.observe(r,before)
 assert(r.deck[1].lastUpgradeOrigin.source.relicId=='astrolabe')
end)
check('same UID upgraded replacement receives new actual context',function()
 local before=fresh();local r=C.copy(before);r.deck[1].cardId='defend'
 O.observe(r,before)
 assert(r.deck[1].lastUpgradeOrigin.cardId=='defend')
 assert(r.deck[1].lastUpgradeOrigin.kind=='obtained_upgraded')
 assert(not r.deck[1].lastUpgradeOrigin.source.relicId)
end)
assert(failed==0,tostring(failed)..' origin identity failures')
print('CARD_ORIGIN_IDENTITY_PASS '..n)
