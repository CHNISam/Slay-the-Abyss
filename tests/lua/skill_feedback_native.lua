-- Real committed Combat events through the production Feedback adapter/native tree.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Feedback=require('abyss_feedback')
local Combat=require('abyss_combat')
local Events=require('abyss_events')
local Data=require('abyss_data')
local Theme=require('abyss_theme')
local Presentation=require('abyss_presentation')
local function control(d)
    local c={children={},visible=d.visible~=false,x=0,y=0,sx=1,sy=1}
    for _,child in ipairs(d.children or {}) do c.children[child.name]=control(child) end
    function c:GetChild(name) return assert(self.children[name],name) end
    function c:SetVisible(v) self.visible=v end
    function c:SetAnchoredPosition(x,y) self.x,self.y=x,y end
    function c:SetLocalScale(x,y) self.sx,self.sy=x,y end
    function c:SetImage(_,id) self.image=id end
    function c:SetAsLastSibling() end
    return c
end
local function find(list,name)
    for _,d in ipairs(list) do
        if d.name==name then return d end
        local value=find(d.children or {},name); if value then return value end
    end
end
local function same(a,b)
    assert(type(a)==type(b),'state type changed')
    if type(a)~='table' then assert(a==b,'state value changed'); return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,'state key changed') end
end
local function count(list,key) local n=0;for _,v in ipairs(list) do if v==key then n=n+1 end end;return n end
local function harness(enemyId,intentId,fast)
    local stage=control(assert(find(require('abyss_ui_layout'),'battlePanel')))
    local h={stage=stage,sounds={},done=0}
    h.battle=Combat.new(Data,{deck={'strike','defend'},enemies={enemyId},seed=11})
    local enemy=h.battle.enemies[1]
    for i,intent in ipairs(enemy.intents) do if intent.id==intentId then enemy.intentIndex=i end end
    enemy.ai=nil -- Select a real published intent without running its random policy.
    h.feedback=Feedback.new(stage,{imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,
        sound=function(cue)h.sounds[#h.sounds+1]=cue end},function()end,
        function(failure)h.failure=failure;h.done=h.done+1 end)
    h.feedback:setFastMode(fast or false)
    function h.run()
        local before,first=Events.frame(h.battle),#h.battle.events+1
        assert(Combat.endTurn(h.battle));h.committed=Combat.copy(h.battle)
        h.feedback:begin(before,h.battle,first,Presentation)
    end
    function h.untilKind(kind)
        for _=1,3000 do
            if h.feedback.current and h.feedback.current.kind==kind then return h.feedback.current end
            assert(h.feedback.busy,'ended before '..kind);h.feedback:update(0.005)
        end
        error('never reached '..kind)
    end
    function h.drain()
        for _=1,3000 do
            h.feedback:update(0.01)
            if not h.feedback.busy and next(h.feedback.effects)==nil then break end
        end
        assert(not h.feedback.busy and h.done==1 and not h.failure,'queue did not complete exactly once')
        same(h.battle,h.committed)
    end
    return h
end
local tests=0
local function test(name,fn) fn();tests=tests+1;print('ok skill_feedback_native '..tests..' - '..name) end

test('Sentry cast is visible before damage and contact does not replay travel',function()
    for _,fast in ipairs({false,true}) do
        local h=harness('sentry','sentry_1',fast);h.run();h.untilKind('intent')
        assert(h.feedback.style.family=='projectile' and h.feedback.cast.family=='projectile')
        local hp=h.feedback.shadow.player.hp
        h.feedback:update(0.01)
        local sweep=h.stage:GetChild('feedback'):GetChild('sweep')
        assert(sweep.visible and h.feedback.shadow.player.hp==hp,'projectile must precede damage frame')
        assert(count(h.sounds,'hurt')==0 and count(h.sounds,'hit')==0)
        h.untilKind('damage');assert(h.feedback.style.family=='projectile' and h.feedback.cast==nil)
        assert(not sweep.visible,'travelling control must hide on contact')
        assert(h.feedback.shadow.player.hp<hp)
        h.feedback:update(0.005)
        local impact=h.stage:GetChild('hero'):GetChild('impact')
        assert(impact.visible and impact.sx>impact.sy*3,'laser contact must be long and thin')
        h.drain();assert(count(h.sounds,'hurt')==1 and count(h.sounds,'action_sentry')==1)
    end
end)
test('Red Slaver entangle travels before status and has no attack sound',function()
    local h=harness('red_slaver','red_slaver_2');h.run();h.untilKind('intent')
    assert(h.feedback.cast.family=='bind');assert(not h.feedback.shadow.player.statuses.entangled)
    h.feedback:update(0.01);assert(h.stage:GetChild('feedback'):GetChild('sweep').visible)
    local e=h.untilKind('status');assert(e.detail.status=='entangled' and h.feedback.style.family=='bind')
    assert(h.feedback.cast==nil);h.drain()
    assert(count(h.sounds,'action_red_slaver')==1 and count(h.sounds,'hurt')==0 and count(h.sounds,'hit')==0)
end)
test('Acid debuff keeps real weak status and does not create poison damage',function()
    local h=harness('acid_slime_m','acid_slime_m_2');h.run();h.untilKind('intent')
    assert(h.feedback.style.family=='poison' and h.feedback.cast.family=='poison')
    local e=h.untilKind('status');assert(e.detail.status=='weak' and h.feedback.style.family=='poison')
    h.drain();assert(not h.battle.player.statuses.poison and count(h.sounds,'hurt')==0)
    assert(count(h.sounds,'action_acid_slime_m')==1)
end)
test('Buff and block use their actual event families and existing one-shot audio',function()
    local h=harness('cultist','cultist_2');h.run();h.untilKind('intent')
    assert(h.feedback.style.family=='buff' and h.feedback.cast==nil)
    h.untilKind('status');assert(h.feedback.style.family=='buff');h.drain()
    assert(count(h.sounds,'status')==1 and count(h.sounds,'action_cultist')==1)
    h=harness('guardian','guardian_1');h.run();h.untilKind('block')
    assert(h.feedback.style.family=='defend');h.drain()
    assert(count(h.sounds,'block_gain')==1 and count(h.sounds,'action_guardian')==1)
end)
test('Poison damage remains a committed status tick with no new cast cue',function()
    local h=harness('cultist','cultist_2');Combat.addStatus(h.battle.enemies[1],'poison',3)
    h.run();local e=h.untilKind('status_damage')
    assert(e.detail.status=='poison' and h.feedback.style.family=='poison' and h.feedback.cast==nil)
    assert(h.feedback.effects[e.detail.target].style.family=='poison');h.drain()
    assert(count(h.sounds,'action_cultist')==1 and count(h.sounds,'hit')==1)
end)
test('Cancel hides the shared cast control and the next action can cast again',function()
    local h=harness('sentry','sentry_1');h.run();h.untilKind('intent');h.feedback:update(0.01)
    local sweep=h.stage:GetChild('feedback'):GetChild('sweep');assert(sweep.visible)
    h.feedback:cancel();assert(not sweep.visible and h.feedback.cast==nil and not h.feedback.busy)
    assert(h.failure=='cancelled' and h.done==1)
    same(h.battle,h.committed)
    h.done,h.failure=0,nil;h.battle.enemies[1].intentIndex=1
    h.run();h.untilKind('intent');h.feedback:update(0.01)
    assert(h.feedback.cast.family=='projectile' and sweep.visible);h.drain()
end)
test('An area attack restores the shared sweep after a rotating binding cast',function()
    local h=harness('red_slaver','red_slaver_2');h.run();h.untilKind('intent');h.feedback:update(0.15)
    local sweep=h.stage:GetChild('feedback'):GetChild('sweep')
    assert(sweep.visible and sweep.localRotationZ>0,'binding cast must exercise rotation reuse')
    h.drain()
    h.battle=Combat.new(Data,{deck={'cleave'},enemies={'cultist','cultist'},seed=11})
    local before,first=Events.frame(h.battle),#h.battle.events+1
    assert(Combat.play(h.battle,h.battle.hand[1].uid,1));h.committed=Combat.copy(h.battle);h.done=0
    h.feedback:begin(before,h.battle,first,Presentation)
    h.untilKind('damage');h.feedback:update(0.005)
    local row=Theme.layout.enemyRow
    assert(sweep.visible and sweep.x==(row.xFrom+row.xTo)/2 and sweep.y==row.y,'area sweep retained cast position')
    assert(sweep.localRotationZ==0,'area sweep retained cast rotation')
    h.drain()
end)
print('LUA_SKILL_FEEDBACK_NATIVE_PASS '..tests)
