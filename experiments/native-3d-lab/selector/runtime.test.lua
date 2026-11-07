package.path='build/lua/?.lua;src/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Fixture=dofile('experiments/native-3d-lab/selector/fixture.lua')
local Runtime=dofile('experiments/native-3d-lab/selector/runtime.lua')
local Run=require('abyss_run')
local Owner=require('abyss_battle_reward_owner')
local Copy=require('abyss_copy')
local config={available=true,seed=42,cards={}}
for _,id in ipairs({'shockwave','clash','shrug_it_off'})do
    for _,upgraded in ipairs({false,true})do config.cards[#config.cards+1]={cardId=id,upgraded=upgraded,number=#config.cards+1}end
end
-- Execute the real 18-command reward path once. Lifecycle cases need independent
-- mutable ownership, not another identical combat and its transaction copies.
local baseline,baselineMeta,baselineDeckCount,baselineNextUid
local realFixtureRuns,caseRuns=0,{}
local function cloneRun(run)
    local shared={[run.data]=run.data}
    if run.combat then
        shared[run.combat.catalog]=run.combat.catalog
        shared[run.combat.rules]=run.combat.rules
    end
    return Copy.copy(run,shared)
end
local CaseFixture={make=function(data,seed)
    local run,meta
    if not baseline then
        run,meta=Fixture.make(data,seed);realFixtureRuns=realFixtureRuns+1
        assert(meta.commands==18 and run.phase=='reward' and not run.rewards.cardResolved)
        baseline=cloneRun(run);baselineMeta=Copy.copy(meta)
        baselineDeckCount,baselineNextUid=#baseline.deck,baseline.nextDeckUid
    else
        assert(seed==baselineMeta.seed,'test cases must use the same explicit reward baseline')
        run,meta=cloneRun(baseline),Copy.copy(baselineMeta)
    end
    assert(baseline.phase=='reward' and not baseline.rewards.cardResolved)
    assert(#baseline.deck==baselineDeckCount and baseline.nextDeckUid==baselineNextUid)
    assert(table.concat(baseline.rewards.cards,',')=='shockwave,clash,shrug_it_off','case mutated the baseline offer')
    assert(run~=baseline and run.deck~=baseline.deck and run.rewards~=baseline.rewards
        and run.rewards.cards~=baseline.rewards.cards and run.combat~=baseline.combat)
    assert(run.data==baseline.data and run.combat.catalog==baseline.combat.catalog,'only readonly rule sources are shared')
    for _,previous in ipairs(caseRuns)do
        assert(run~=previous and run.deck~=previous.deck and run.deck[1]~=previous.deck[1])
        assert(run.rewards~=previous.rewards and run.rewards.cards~=previous.rewards.cards)
        assert(run.combat~=previous.combat and run.combat.player~=previous.combat.player
            and run.combat.enemies~=previous.combat.enemies and run.combat.hand~=previous.combat.hand)
        if run.rewards.cardUpgrades and previous.rewards.cardUpgrades then assert(run.rewards.cardUpgrades~=previous.rewards.cardUpgrades)end
        if type(run.cardRng)=='table' and type(previous.cardRng)=='table'then assert(run.cardRng~=previous.cardRng)end
    end
    caseRuns[#caseRuns+1]=run
    return run,meta
end}
local function fixture()
    local view,stage=F.fixture();local canvas=stage.parent
    -- Layout configuration is not proof of Lua-writable fields. Trap invented APIs.
    local old=getmetatable(canvas);local mt={};for key,value in pairs(old)do mt[key]=value end
    mt.__newindex=function(self,key,value)
        assert(key~='blockCursor' and key~='blockKeys','unsupported root property write')
        return old.__newindex(self,key,value)
    end
    setmetatable(canvas,mt)
    local sent,logs,callback={},{}
    local selector=Runtime.attach(view,canvas,{config=config,fixture=CaseFixture,
        send=function(name,params)sent[#sent+1]={name=name,params=params}end,
        register=function(name,fn)assert(name=='LAB_SELECTOR_REPLY');callback=fn end,
        log=function(line)logs[#logs+1]=line end})
    selector:fixture()
    return {view=view,stage=stage,root=canvas,selector=selector,sent=sent,logs=logs,
        reply=function(token,result,reason)return callback({token,result,reason})end}
end
local function deckUIDs(run)
    local out={};for i,c in ipairs(run.deck)do out[i]=c.uid..':'..c.cardId..':'..tostring(c.upgraded==true)end
    return table.concat(out,'|')
end
local a=fixture();local s=a.selector;local run=a.view.run
assert(run.phase=='reward' and #Run.rewardOptions(run)==3 and s.fixtureMeta.commands==18)
local originalDeck,originalCount,uid=run.deck,#run.deck,run.nextDeckUid
local before=deckUIDs(run)
local oldPointer=Owner.capture({battle=run.combat},a.view.battleUI,run)
local ok,token=s:open();assert(ok and token==1)
assert(not Owner.ready(a.view.battleUI,oldPointer),'formal pointer token from before the native modal must be stale')
assert(a.stage.visible==false and a.root:GetChild('canvasBackdrop').visible==false)
assert(a.view.battleUI.active==false,'old reward inputs must be locked')
assert(a.sent[#a.sent].params[3].value==1 and a.sent[#a.sent].params[4].value==3 and a.sent[#a.sent].params[5].value==5)
assert(a.reply(token,token*16+2,'selected'))
assert(#run.deck==originalCount+1 and run.deck==originalDeck)
assert(run.deck[#run.deck].uid==uid and run.deck[#run.deck].cardId=='clash')
assert(run.rewards.cardResolved and a.stage.visible and a.view.battleUI.active)
assert(not a.reply(token,token*16+2,'selected') and #run.deck==originalCount+1,'duplicate reply cannot grant twice')

-- Current order/subset is sent at open time, and upgrade flags resolve to the correct library entry.
local b=fixture();run=b.view.run
run.rewards.cards={'shrug_it_off','shockwave'};run.rewards.cardUpgrades={true,false}
b.view:refresh();local original=#run.deck
ok,token=b.selector:open();assert(ok)
local open=b.sent[#b.sent].params
assert(open[2].value==2 and open[3].value==6 and open[4].value==1 and open[5].value==0)
assert(b.reply(token,token*16+1,'selected'))
assert(#run.deck==original+1 and run.deck[#run.deck].cardId=='shrug_it_off' and run.deck[#run.deck].upgraded==true)

for _,reason in ipairs({'timeout','cancelled:player','cancelled:node_close','busy:previous_selector','error:native_event_timeout_restore_classic'})do
    local f=fixture();run=f.view.run;before=deckUIDs(run)
    ok,token=f.selector:open();assert(ok)
    assert(f.reply(token,token*16,reason))
    assert(deckUIDs(run)==before and not run.rewards.cardResolved and f.stage.visible and f.view.battleUI.active)
end
local c=fixture();run=c.view.run;before=deckUIDs(run)
ok,token=c.selector:open();assert(ok)
c.selector:cancel('skip')
assert(not c.reply(token,token*16+1,'selected') and deckUIDs(run)==before and not run.rewards.cardResolved)
assert(c.sent[#c.sent].name=='LAB_SELECTOR_CANCEL')
assert(c.selector:open());local token2=c.selector.pending.token
assert(not c.reply(token,token*16+1,'selected') and c.selector.pending.token==token2,'old completion must not steal a newer owner')
c.selector:update(33)
assert(not c.selector.pending and deckUIDs(run)==before and c.stage.visible)

local d=fixture();run=d.view.run;before=deckUIDs(run)
ok,token=d.selector:open();assert(ok)
run.rewards.cardUpgrades={true,false,false} -- mutate candidate ownership while native window is open
d.selector:update(0)
assert(not d.selector.pending and not d.reply(token,token*16+1,'selected') and deckUIDs(run)==before)
assert(not run.rewards.cardResolved)
ok,token=d.selector:open();assert(ok)
d.view.battleUI.rewardEpoch=(d.view.battleUI.rewardEpoch or 0)+1
assert(not d.reply(token,token*16+1,'selected') and deckUIDs(run)==before)

local e=fixture();run=e.view.run;before=deckUIDs(run)
ok,token=e.selector:open();assert(ok)
assert(not e.reply(token,token*16+4,'selected') and deckUIDs(run)==before)
run.rewards.cards={'strike','shockwave','clash'}
local count=#e.sent;assert(not e.selector:open() and #e.sent==count,'unsupported catalog must fall back without changing the offer')
run.rewards.cards={'shockwave','clash','shrug_it_off'};run.rewards.cardRewardGroups={{cards=run.rewards.cards,resolved=false}}
assert(not e.selector:open(),'special reward mechanisms stay in the full formal UI')

local g=fixture();ok,token=g.selector:open();assert(ok);run=g.view.run;before=deckUIDs(run)
g.selector:fixture()
assert(g.view.run~=run and not g.reply(token,token*16+1,'selected') and deckUIDs(run)==before,'new fixture generation rejects stale replies')
g.selector:destroy();assert(not g.selector:open())
assert(realFixtureRuns==1 and #caseRuns>=12,'retain one real command path and independent per-case state')
print('native selector: real Run reward transactions, upgraded/subset offers, fresh UIDs, duplicate/stale/cancel/timeout fallback and full-tree UI ownership passed (offline bridge)')
