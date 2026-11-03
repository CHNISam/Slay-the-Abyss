-- Shared node queries must not initialize Combat just to copy candidates.
assert(package.loaded.abyss_combat==nil,'fixture must start without Combat')
local previous=package.preload.abyss_combat
package.preload.abyss_combat=function()error('COPY_ONLY_NODES_LOADED_COMBAT')end
local ok,Common=pcall(require,'abyss_nodes_common')
package.preload.abyss_combat=previous
assert(ok,Common)
assert(package.loaded.abyss_combat==nil,'node queries unexpectedly initialized Combat')

local shared={value=7};shared.self=shared
local ordinary={id='ordinary',type='skill',cost=1,effects={{op='block',amount=5}},
 upgrade={effects={{op='block',amount=8}}},first=shared,second=shared}
ordinary.self=ordinary
local repeated={id='repeated',type='skill',cost=1,effects={{op='block',amount=1}},
 upgrade={effects={{op='block',amount=2}}},repeatable=true}
local noUpgrade={id='none',type='skill',cost=1,effects={{op='block',amount=1}}}
local emptyUpgrade={id='empty',type='skill',cost=1,effects={{op='block',amount=1}},upgrade={}}
local unsupported={id='unsupported',type='skill',cost=1,effects={{op='block',amount=1}},
 upgrade={effects={{op='not_implemented',amount=1}}}}
local unplayable={id='status',type='status',cost=-2,effects={},upgrade={cost=-2}}
local first={uid=17,cardId='ordinary',upgraded=false,first=shared,second=shared};first.self=first
local repeatInstance={uid=23,cardId='repeated',upgraded=true,upgrades=4}
local run={data={cards={cards={ordinary,repeated,noUpgrade,emptyUpgrade,unsupported,unplayable}}},
 deck={first,{uid=18,cardId='ordinary',upgraded=true},repeatInstance,{uid=24,cardId='missing'},
 {uid=25,cardId='none'},{uid=26,cardId='empty'},{uid=27,cardId='unsupported'},{uid=28,cardId='status'}}}
assert(Common.upgradeable(run,first))
assert(not Common.upgradeable(run,run.deck[2]))
assert(Common.upgradeable(run,repeatInstance))
for i=4,#run.deck do assert(not Common.upgradeable(run,run.deck[i]),'invalid upgrade accepted: '..i)end
local rows=Common.upgradeCards(run)
assert(#rows==2 and rows[1].uid==17 and rows[2].uid==23,'eligible order/UID changed')
assert(rows[1]~=first and rows[2]~=repeatInstance)
assert(rows[1].first~=shared and rows[1].first==rows[1].second and rows[1].first.self==rows[1].first)
assert(rows[1].self==rows[1],'candidate graph cycle was lost')
assert(rows[2].upgraded==true and rows[2].upgrades==4,'repeatable upgrade state changed')
rows[1].first.value=99;rows[2].upgrades=100
assert(shared.value==7 and repeatInstance.upgrades==4,'candidate mutation leaked into Run')
local again=Common.upgradeCards(run)
assert(again[1]~=rows[1] and again[1].first~=rows[1].first and again[1].first.value==7)
assert(ordinary.effects[1].amount==5 and ordinary.upgrade.effects[1].amount==8,
 'capability preview applied upgrade to the source definition')
assert(ordinary.self==ordinary and ordinary.first==ordinary.second and ordinary.first==shared)
assert(run.deck[1]==first and first.self==first and first.upgraded==false)

-- The pure query preserves the existing exception object and live input graph.
local failure={}
local bad=setmetatable({id='bad',type='skill',cost=1,effects={},upgrade={cost=0}},
 {__pairs=function()error(failure)end})
run.data.cards.cards[#run.data.cards.cards+1]=bad
local badInstance={uid=29,cardId='bad'};run.deck[#run.deck+1]=badInstance
local success,err=pcall(Common.upgradeCards,run)
assert(not success and err==failure,'query must preserve original copy error')
assert(run.deck[#run.deck]==badInstance and bad.upgrade.cost==0 and first.first==shared and shared.value==7)
assert(package.loaded.abyss_combat==nil,'upgrade query reintroduced Combat')
print('NODES_COMMON_COPY_PASS isolation/eligibility/order/UID/graphs/source/error')
