package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Random=require('abyss_sts_random')
local Pool=require('abyss_relic_pool')
local cursor={CursorDown='down',CursorUp='up',CursorDrag='drag',CursorExit='exit',CursorEndDrag='endDrag'}
local count=0
local function same(a,b,path)
    path=path or 'state'
    assert(type(a)==type(b),path..' type differs')
    if type(a)~='table'then assert(a==b,path..' value differs');return end
    for k,v in pairs(b)do same(a[k],v,path..'.'..tostring(k))end
    for k in pairs(a)do assert(b[k]~=nil,path..' unexpected '..tostring(k))end
end
local function test(name,fn)fn();count=count+1;print('ok elite relic reward '..count..' - '..name)end
local function setup(pointer)
    local host,root=F.fixture(nil,nil,nil,pointer and cursor or nil)
    assert(host:start());assert(Run.startCombat(host.run,'cultist_solo'))
    -- These are explicitly staged reward offers for API/UI ownership tests.
    -- They are not a natural elite win or an oracle for elite drop probabilities.
    host.run.phase='reward'
    host.run.rewards={manualContinue=true,gold=17,goldClaimed=false,cards={'defend','strike'},
        cardUpgrades={false,false},cardResolved=false,potion={id='block_potion',resolved=false,unavailable=false},
        relics={{id='anchor',sourceId='Anchor',claimed=false,unavailable=false},
            {id='bronze_scales',sourceId='Bronze Scales',claimed=false,unavailable=false}}}
    host:refresh()
    local panel=root:GetChild('battlePanel')
    local function control(name)
        return name:match('^relicReward') and panel:GetChild('potionHelp'):GetChild(name)or panel:GetChild(name)
    end
    local function fire(name,kind,id)
        local box=control(name);local target=box.listeners and box or box:GetChild('hit')
        return assert(target.listeners[kind],name..'/'..kind)(id and {touchId=id}or nil)
    end
    local function tap(name,id)
        if pointer then fire(name,'down',id);fire(name,'up',id)end
        return fire(name,'click',id)
    end
    return host,root,panel,control,fire,tap
end
local function owners(run)
    return {run.rewards,run.rewards.relics,run.rewards.relics[1],run.deck,run.relics,run.potions,run.combat,run.nodeFlow}
end
local function unchanged(run,before,original)
    same(run,before)
    local current=owners(run)
    for i,v in pairs(original)do assert(current[i]==v,'failed claim replaced owner '..i)end
end
local function streams(run)
    return {pool=Pool.snapshot(run.relicPool),card=Random.snapshot(run.cardRng),
        misc=Random.snapshot(run.miscRng),treasure=Random.snapshot(run.treasureRng)}
end

test('public relic claim resolves only that offer; gold cards potion and random owners stay independent',function()
    local host=setup();local r=host.run
    local deck,potions=F.Combat.copy(r.deck),F.Combat.copy(r.potions)
    local gold,relics,rng=r.gold,#r.relics,streams(r)
    local ok,id=Run.claimRelicReward(r,1);assert(ok and id=='anchor')
    assert(#r.relics==relics+1 and r.relics[#r.relics]=='anchor')
    assert(r.rewards.relics[1].claimed and not r.rewards.relics[2].claimed)
    assert(r.gold==gold and not r.rewards.goldClaimed and not r.rewards.cardResolved and not r.rewards.potion.resolved)
    same(r.deck,deck);same(r.potions,potions);same(streams(r),rng)
    local before,original=F.Combat.copy(r),owners(r)
    ok,id=Run.claimRelicReward(r,1);assert(not ok and id=='no_pending_relic_reward')
    unchanged(r,before,original)
    local reward,battle=r.rewards,r.combat
    assert(Run.leaveCombatRewards(r)and r.pendingCombatRewards.rewards==reward and r.pendingCombatRewards.combat==battle)
    assert(Run.reopenCombatRewards(r)and r.rewards==reward and r.combat==battle)
    assert(r.rewards.relics[1].claimed and not r.rewards.relics[2].claimed)
end)
test('unavailable and malformed claims preserve the complete graph and every existing owner',function()
    local host=setup();local r=host.run
    r.rewards.relics[1].unavailable=true
    local before,original=F.Combat.copy(r),owners(r)
    local ok,why=Run.claimRelicReward(r,1);assert(not ok and why=='relic_content_unavailable')
    unchanged(r,before,original)
    for _,index in ipairs({0,-1,3,1.5,'1',false,math.huge,0/0})do
        assert(not Run.claimRelicReward(r,index));unchanged(r,before,original)
    end
    r.phase='map';before,original=F.Combat.copy(r),owners(r)
    assert(not Run.claimRelicReward(r,2));unchanged(r,before,original)
end)
test('late obtain refusal and exception cannot commit any relic hook reward flag or resource mutation',function()
    local original=Run.obtainRelic
    for _,throws in ipairs({false,true})do
        local host=setup();local r=host.run
        local before,refs=F.Combat.copy(r),owners(r)
        Run.obtainRelic=function(staged,id)
            assert(original(staged,id))
            staged.gold=staged.gold+91;Random.randomInt(staged.cardRng,99)
            if throws then error('INJECTED_RELIC_EQUIP_FAILURE')end
            return false,'test_relic_obtain_refused'
        end
        local called,ok,why=pcall(Run.claimRelicReward,r,1)
        Run.obtainRelic=original
        assert(called and not ok and why==(throws and 'transaction_failed'or'test_relic_obtain_refused'))
        unchanged(r,before,refs)
        assert(Run.claimRelicReward(r,1),'the same offer remains claimable after rollback')
    end
end)
test('generated relic rows claim independently from gold card picker and potion without duplicate grants',function()
    local host,_,panel,control,_,tap=setup();local r=host.run
    local gold,deck,relics=r.gold,#r.deck,#r.relics
    local uids={};for _,card in ipairs(r.deck)do uids[#uids+1]=card.uid end
    assert(control('relicReward1').visible and control('relicReward2').visible)
    tap('relicReward1');assert(r.rewards.relics[1].claimed and #r.relics==relics+1)
    tap('relicReward1');assert(#r.relics==relics+1)
    assert(not control('relicReward1').visible and control('relicReward2').visible)
    assert(r.gold==gold and #r.deck==deck and Run.potionCount(r)==0)
    tap('goldReward');assert(r.gold==gold+17 and r.rewards.goldClaimed)
    assert(not r.rewards.relics[2].claimed and not r.rewards.cardResolved and not r.rewards.potion.resolved)
    tap('claimPotion');assert(Run.potionCount(r)==1 and r.rewards.potion.resolved)
    tap('cardReward');assert(host.battleUI.rewardScreen=='cards'and panel:GetChild('rewardStage').visible)
    tap('card1');assert(#r.deck==deck+1 and r.rewards.cardResolved and host.battleUI.rewardScreen=='list')
    for i,uid in ipairs(uids)do assert(r.deck[i].uid==uid,'independent claims changed permanent card ownership')end
    assert(r.deck[#r.deck].uid>uids[#uids])
    tap('relicReward2');assert(#r.relics==relics+2 and r.rewards.relics[2].claimed)
    assert(r.gold==gold+17 and #r.deck==deck+1 and Run.potionCount(r)==1)
end)
test('replaced reward owners and changed source identities retire old relic pointers',function()
    local host,_,_,_,fire,tap=setup(true);local r=host.run
    fire('relicReward1','down',1)
    r.rewards=F.Combat.copy(r.rewards);host:refresh()
    local before=F.Combat.copy(r)
    fire('relicReward1','up',1);fire('relicReward1','click',1);same(r,before)
    fire('relicReward1','down',2)
    r.rewards.relics[1].sourceId='Changed source'
    before=F.Combat.copy(r)
    fire('relicReward1','up',2);fire('relicReward1','click',2);same(r,before)
    r.rewards.relics[1].sourceId='Anchor';host:refresh()
    tap('relicReward1',3);assert(r.rewards.relics[1].claimed)
end)
test('unavailable busy and modal rows reject old input then allow a fresh owned claim',function()
    local host,_,_,control,fire,tap=setup(true);local r=host.run
    r.rewards.relics[1].unavailable=true;host:refresh()
    assert(control('relicReward1').visible and not control('relicReward1').interactable)
    local before=F.Combat.copy(r);tap('relicReward1',1);same(r,before)
    r.rewards.relics[1].unavailable=false;host:refresh()
    fire('relicReward1','down',2);assert(host:openExit());assert(host:closeExit())
    before=F.Combat.copy(r)
    fire('relicReward1','up',2);fire('relicReward1','click',2);same(r,before)
    host.battleUI.busy=true
    tap('relicReward1',3);same(r,before)
    host.battleUI.busy=false;host:refresh()
    tap('relicReward1',4);assert(r.rewards.relics[1].claimed)
end)
print('LUA_ELITE_RELIC_REWARD_UI_PASS '..count)
