package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run=require('abyss_run')
local data=require('abyss_data')
local presentation=require('abyss_presentation')
local Names=require('abyss_relic_names')
local function nodeContext(run)
 local self={run=run,presentation=presentation,view={node=run.nodeFlow},notice='',render=function()end}
 local ctx={self=self,options={},roomMotion={start=function()end}}
 require('abyss_node_ui_lifecycle').install(ctx)
 return ctx,self
end
local function treasure(run,id)
 run.phase='node';run.nodeFlow={id='test',type='treasure',complete=false,reward={relicId=id}}
end
local r=Run.new(data,42);r.deck={{uid=7,cardId='bash',upgraded=false}}
treasure(r,'whetstone')
local ctx,ui=nodeContext(r)
assert(ctx.commit('claimTreasure',nil,function()return '已获得遗物「磨刀石」'end))
local title=presentation.bash.name
assert(ui.notice:find(title,1,true) and ui.notice:find('升级',1,true),'current node obtain feedback must name upgraded card')
assert(not ctx.commit('claimTreasure',nil,function()error('failed claim must not describe')end))
assert(not ui.notice:find(title,1,true),'failed claim leaked old upgrade result')
treasure(r,nil);r.nodeFlow.reward.gold=5;ui.view.node=r.nodeFlow
assert(ctx.commit('claimTreasure',nil,function()return '已获得金币'end))
assert(not ui.notice:find(title,1,true),'successful unrelated command reused copied old receipt')
treasure(r,'war_paint');ui.view.node=r.nodeFlow
assert(ctx.commit('claimTreasure',nil,function()return '已获得遗物「战纹涂料」'end))
assert(not ui.notice:find(title,1,true),'zero-target receipt leaked preceding upgrade')
assert(Names.upgradeFeedback(r,0,presentation,'whetstone')=='','receipt must match acquired relic')
local seq=r.lastRelicObtain.sequence
assert(Names.upgradeFeedback(r,seq,presentation,'war_paint')=='','unchanged receipt must not be reused')
print('LUA_RELIC_UPGRADE_NODE_FEEDBACK_PASS')
-- Existing battle reward controls exercise the same committed receipt path.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'))
host.run.phase='reward';host.run.deck={{uid=99,cardId='bash',upgraded=false}}
host.run.rewards={manualContinue=true,gold=0,goldClaimed=true,cards={},cardResolved=true,
 relics={{id='whetstone',sourceId='Whetstone',claimed=false},{id='war_paint',sourceId='War Paint',claimed=false}}}
host:refresh()
local panel=root:GetChild('battlePanel')
local function tap(slot)
 local box=panel:GetChild('potionHelp'):GetChild('relicReward'..slot)
 local hit=box.listeners.click and box or box:GetChild('hit')
 return assert(hit.listeners.click)()
end
tap(1)
assert(host.run.rewards.relics[1].claimed)
assert(panel:GetChild('notice').text:find(title,1,true),'battle obtain feedback must name upgraded card')
assert(panel:GetChild('notice').text:find('磨刀石',1,true),'battle feedback must identify source relic')
tap(2)
assert(host.run.rewards.relics[2].claimed)
assert(not panel:GetChild('notice').text:find(title,1,true),'battle zero-target receipt leaked preceding upgrade')
print('LUA_RELIC_UPGRADE_BATTLE_FEEDBACK_PASS')
