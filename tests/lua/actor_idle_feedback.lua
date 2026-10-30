local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Theme=require('abyss_theme')
local Run=require('abyss_run')
local host,root=F.fixture()
assert(F.start(host))
assert(Run.startCombat(host.run,'cultist_solo'))
host.run.combat=F.Combat.new(F.Data,{deck={'strike','defend','defend'},enemies={'cultist','jaw_worm'},seed=11})
host:refresh()
local ui,panel=host.battleUI,root:GetChild('battlePanel')
local feedback,battle=ui.feedback,host.run.combat
local tests=0
local function test(name,fn)fn();tests=tests+1;print('ok actor_idle_feedback '..tests..' - '..name)end
local function point(control,offset)return table.concat({(control.x or 0)+(offset or 0),control.y or 0,control.localScaleX or 1,control.localScaleY or 1},',')end
local function geometry()
    local result={}
    for _,name in ipairs({'hero','enemy1','enemy2'})do
        local box=name=='hero' and panel:GetChild(name) or monsterControl(panel,name)
        result[#result+1]=name..'='..point(box)
        for _,part in ipairs({'hp','intent','intentIcon','hit','name'})do
            local control=box:GetChild(part)
            -- Source renderName cancels the animated sprite X; its baseline
            -- stays fixed even though the local label coordinate compensates.
            local offset=part=='name' and name~='hero' and box:GetChild('portrait').x or 0
            if control then result[#result+1]=name..'.'..part..'='..point(control,offset)end
        end
    end
    return table.concat(result,';')
end
local function ruleState()
    local parts={battle.player.hp,battle.energy,battle.turn,#battle.events,tostring(battle.rng)}
    local function value(v)
        if type(v)~='table'then return tostring(v)end
        local keys,result={},{}
        for key in pairs(v)do keys[#keys+1]=key end
        table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
        for _,key in ipairs(keys)do result[#result+1]=tostring(key)..'='..value(v[key])end
        return '{'..table.concat(result,';')..'}'
    end
    for _,name in ipairs({'cardRandomRng','shuffleRng','aiRng','monsterHpRng'})do parts[#parts+1]=value(battle[name])end
    for _,enemy in ipairs(battle.enemies)do parts[#parts+1]=enemy.hp;parts[#parts+1]=enemy.intentIndex or 0 end
    for _,pile in ipairs({'hand','draw','discard','exhaust'})do
        parts[#parts+1]=pile
        for _,card in ipairs(battle[pile])do parts[#parts+1]=card.uid end
    end
    return table.concat(parts,',')
end
test('first idle frame animates portraits without events or moving information and hitboxes',function()
    local before,positions=ruleState(),geometry()
    local hero=panel:GetChild('hero'):GetChild('portrait')
    local start=point(hero)
    for _=1,30 do host:update(1/60)end
    assert(point(hero)~=start,'initial battle must breathe without playing a card first')
    assert(point(monsterControl(panel,'enemy1'):GetChild('portrait'))~=point(monsterControl(panel,'enemy2'):GetChild('portrait')))
    assert(ruleState()==before,'idle must not mutate cards, HP, energy, turn, events or RNG')
    assert(geometry()==positions,'only portrait transforms may move: before='..positions..' after='..geometry())
end)
test('background recovery bounds only the visual clock and consumes no events',function()
    local before,clock=ruleState(),feedback.idleClock
    host:update(120)
    local expected=(clock+Theme.motion.actorIdle.maxDelta)%Theme.motion.actorIdle.period
    assert(math.abs(feedback.idleClock-expected)<1e-9,'idle must not jump by two minutes')
    assert(ruleState()==before,'resuming an idle battle must not fabricate actions')
end)
test('real card command releases input and resumes idle instead of freezing at finish',function()
    local slot
    for i,card in ipairs(battle.hand)do if card.cardId=='strike'then slot=i end end
    assert(slot)
    panel:GetChild('card'..slot):GetChild('hit').click()
    monsterControl(panel,'enemy1'):GetChild('hit').click()
    assert(feedback.busy)
    for _=1,300 do host:update(0.01);if not feedback.busy and next(feedback.effects)==nil and next(feedback.poses)==nil then break end end
    assert(not feedback.busy and not ui.busy)
    local hero=panel:GetChild('hero'):GetChild('portrait')
    local before=point(hero)
    host:update(0.05)
    assert(point(hero)~=before,'ordinary finish must preserve the idle binding')
end)
test('hit and death composition suppress an old attack pose',function()
    feedback.poses.player={age=0,keys={{0,80,2},{1,80,2}}}
    feedback.effects.player={age=0,kind='damage',detail={source='enemy1',target='player',amount=3},
        ink=Theme.color.danger,style={weight='normal',form='single'},stop=0,dir=-1,oldHp=1,hp=0.9}
    feedback:update(0.01)
    local hero=panel:GetChild('hero'):GetChild('portrait')
    assert(hero.x<0 and hero.localScaleX==1,'old attack cannot override knockback or stretch the victim')
    feedback.dying.player={age=0}
    feedback:update(0.01)
    assert(hero.y<0 and hero.localScaleX<1.1,'death wins over both the active hit and old 2x attack scale')
    feedback:cancel();ui:render()
end)
test('cancel resets the portrait and a hidden battle stops updates including residual effects',function()
    feedback:cancel()
    local hero=panel:GetChild('hero'):GetChild('portrait')
    assert(hero.x==0 and hero.y==0 and hero.localScaleX==1 and hero.localScaleY==1)
    ui:render();host:update(0.05)
    feedback.poses.player={age=0,keys={{0,0,1},{1,80,2}}}
    ui:setActive(false)
    local before=point(hero)
    host:update(0.05)
    assert(point(hero)==before,'hidden battle must not continue an old attack or idle')
    ui:setActive(true);host:update(0.05)
    assert(feedback.idleBattle==battle,'reactivation binds the current battle')
end)
print('LUA_ACTOR_IDLE_FEEDBACK_PASS '..tests)
