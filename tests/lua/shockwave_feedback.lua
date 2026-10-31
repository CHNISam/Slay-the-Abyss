-- Real controller + generated native tree; no game-client/visual acceptance claim.
local H = dofile('tests/lua/support/battle_gesture_fixture.lua')
local Theme, C = require('abyss_theme'), H.F.Combat
local monsterControl=dofile('tests/lua/support/monster_control_fixture.lua')
local sourceGeometry=dofile('tests/lua/support/source_intent_geometry.lua')
local count, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function test(name, fn)
    count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
    print((ok and 'ok ' or 'not ok ')..count..' - '..name..(ok and '' or ': '..tostring(err)))
end
for _,upgraded in ipairs({false,true}) do
    test('Shockwave text, detail and area flight '..tostring(upgraded),function()
        local h,u,p,event,tap,drain=H.setup({{cardId='shockwave',upgraded=upgraded}},{'cultist','cultist'})
        local s=h.run.combat;local amount=upgraded and 5 or 3
        local card=p:GetChild('card1')
        assert(card:GetChild('label').text:find('每个敌人',1,true))
        assert(card:GetChild('label').text:find(tostring(amount)..' 回合虚弱',1,true))
        assert(card:GetChild('label').text:find(tostring(amount)..' 回合易伤',1,true))
        assert(card:GetChild('label').text:find('消耗',1,true))
        event('card1','enter',7);h:update(0.4)
        local info=p:GetChild('statusInfo');assert(info.visible)
        assert(info:GetChild('name1').text:find('虚弱',1,true))
        assert(info:GetChild('name2').text:find('易伤',1,true))
        assert(info:GetChild('name3').text:find('消耗',1,true))
        event('card1','exit',7)
        local first=s.enemies[1]
        eq(first.definitionId,'cultist','controlled front actor')
        sourceGeometry(assert(monsterControl(p,'enemy1')),first)
        tap('card1',8);tap('playArea',8);assert(u.busy)
        -- Area x remains the source zone center; y follows its first front-row actor.
        local sourceX=(1010+1850)/2/1.5-640
        -- Independent sts@319009d5 Cultist constructor facts, also checked on
        -- the real native box above: drawY=-10, hitbox230x240, source anchor340.
        local sourceY=(400-10+math.max(230,240)/2)*(720/1080)-720/2
        eq(math.abs(u.feedback.flight.tx-sourceX)<1e-8,true,'area flight center')
        eq(math.abs(u.feedback.flight.ty-sourceY)<1e-8,true,'enemy row')
        eq(s.energy,1);eq(#s.exhaust,1);eq(#s.discard,0)
        -- Captured UI playback must see each target's complete pair before the next target.
        local observed={}
        local seen={}
        for _=1,400 do
            local current=u.feedback.current
            if current and current.kind=='status' and not seen[current] then
                seen[current]=true
                observed[#observed+1]=current.detail.target..':'..current.detail.status
                local display=u.displayBattle
                if #observed==1 then eq(display.enemies[1].statuses.weak,amount);eq(display.enemies[2].statuses.weak,nil) end
                if #observed==2 then eq(display.enemies[1].statuses.vulnerable,amount);eq(display.enemies[2].statuses.weak,nil) end
            end
            if not u.busy then break end
            h:update(0.01)
        end
        assert(not u.busy);eq(table.concat(observed,','),'cultist_1:weak,cultist_1:vulnerable,cultist_2:weak,cultist_2:vulnerable')
        eq(#s.events,0,'playback releases events once')
    end)
end
print('SHOCKWAVE_FEEDBACK '..(count-failed)..' passed; '..failed..' failed')
assert(failed==0,'Shockwave feedback regression')
