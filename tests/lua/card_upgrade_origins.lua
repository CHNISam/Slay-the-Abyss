local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run');local Combat=require('abyss_combat')
local run=Run.new(F.Data,'871')
local uid=run.deck[1].uid
local function card(owner,id)for _,c in ipairs(owner.deck)do if c.uid==id then return c end end end
local function upgrade(owner,id)local c=card(owner,id);c.upgraded=true;c.upgrades=(c.upgrades or 0)+1 end
run.phase='node';run.nodeFlow={type='event',event={id='shining_light'}}
assert(Run.transaction(run,function(staged)upgrade(staged,uid);return true end))
local c=card(run,uid);local origin=c.lastUpgradeOrigin
assert(origin and origin.kind=='permanent_upgrade','successful event upgrade needs provenance')
assert(origin.uid==uid and origin.source.eventId=='shining_light' and not origin.before.upgraded and origin.after.upgraded)
local rng=run.miscRng;local saved=Combat.copy(origin)
assert(Run.transaction(run,function(staged)staged.gold=staged.gold+1;return true end))
assert(card(run,uid).lastUpgradeOrigin.source.eventId==saved.source.eventId)
local other=run.deck[2].uid
assert(not Run.transaction(run,function(staged)upgrade(staged,other);return false,'refused' end))
assert(not card(run,other).lastUpgradeOrigin)
assert(not Run.transaction(run,function(staged)upgrade(staged,other);error('failed')end))
assert(not card(run,other).lastUpgradeOrigin)
assert(not Run.transaction(run,function(staged)
 upgrade(staged,other);Run.transaction(staged,function()return false,'nested_refused'end);return true
end))
assert(not card(run,other).lastUpgradeOrigin)
assert(Run.transaction(run,function(staged)
 return Run.transaction(staged,function(nested)upgrade(nested,other);return true end)
end))
assert(card(run,other).lastUpgradeOrigin.source.eventId=='shining_light')
local ok,newUid=Run.obtainCard(run,'defend',{upgraded=true});assert(ok)
assert(card(run,newUid).lastUpgradeOrigin.kind=='obtained_upgraded')
-- Mixed effects must retain each actual relic or event source, never borrow a
-- stale lastRelicObtain, including copied transaction tables.
run.lastRelicObtain={sequence=70,relicId='war_paint',upgrades={}}
local third=run.deck[3].uid
card(run,third).lastRelicUpgrade={relicId='war_paint',after={upgrades=1}}
assert(Run.transaction(run,function(staged)upgrade(staged,third);return true end))
assert(card(run,third).lastUpgradeOrigin.source.eventId=='shining_light','stale relic must not replace event source')
-- Combat copies upgraded for this fight do not write permanent receipts.
local permanent=card(run,other).upgrades
assert(Run.transaction(run,function(staged)
 staged.combat={hand={Combat.copy(card(staged,other))}};staged.combat.hand[1].upgrades=permanent+1;return true
end))
assert(card(run,other).upgrades==permanent)
-- Camp smith is a direct owner command; rest alone never upgrades the deck.
local camp=Run.new(F.Data,'82');camp.phase='node';camp.nodeFlow={type='camp',complete=false,upgradesLeft=1}
local campUid=camp.deck[1].uid
assert(require('abyss_nodes').upgrade(camp,campUid))
assert(card(camp,campUid).lastUpgradeOrigin.source.kind=='camp')
local eggs=Run.new(F.Data,'83');assert(Run.obtainRelic(eggs,'toxic_egg'))
local eggOk,eggUid=Run.obtainCard(eggs,'defend');assert(eggOk)
assert(card(eggs,eggUid).lastUpgradeOrigin.source.relicId=='toxic_egg')
local View=require('abyss_card_origin_view')
local permanentCard=card(run,other)
local temporary=Combat.copy(permanentCard);temporary.deckUid=other;temporary.upgrades=permanentCard.upgrades+1
local text=View.describe(run,temporary,true)
assert(text:find('永久升级',1,true) and text:find('闪耀之光',1,true) and text:find('本场临时升级',1,true))
assert(View.describe(run,card(run,newUid),false):find('获得时已升级',1,true))
assert(View.keywords({strikeTag=true}):find('打击标签',1,true))
local V=require('abyss_relic_view_ui')
assert(V.status({phase='combat',relicCounters={omamori=2},combat={relicCounters={omamori=0}}},'omamori')=='已耗尽','live battle counter must win')
assert(V.status({relicCounters={lizard_tail=-1}},'lizard_tail')=='剩余 1 次')
print('CARD_UPGRADE_ORIGINS_PASS 9')
