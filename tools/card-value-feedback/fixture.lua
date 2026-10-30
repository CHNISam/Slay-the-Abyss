-- Diagnostic candidate only. Real production renderer/core; controlled states,
-- not a natural acquisition path, mobile interaction or a normal gameplay pass.
local Combat = require('abyss_combat')
local CardInput = require('abyss_card_input')
local Surfaces = require('abyss_monster_surfaces')
local Data, Theme = require('abyss_data'), require('abyss_theme')
local M = {}
function M.start(view)
    local time, last = 0, 0
    assert(view:start())
    assert(view:selectCharacter('traveler'))
    assert(view:selectElement('ironclad'))
    assert(view:confirmCharacter())
    local scenes = {
        {'neutral',{}}, {'frail',{frail=1}}, {'dexterity',{dexterity=3}},
        {'weak',{weak=1}}, {'aim',{}}, {'cancel',{}},
        {'mixed',{strength=-1,dexterity=2}}, {'ten',{strength=-1,dexterity=2}},
    }
    local function render(index)
        local scene=scenes[index]
        if not scene then return end
        local deck={'strike','defend','iron_wave','twin_strike','body_slam'}
        local s=Combat.new(Data,{deck=deck,enemies={'jaw_worm','cultist'}})
        -- This controlled pair is not a source encounter formation; keep its hitboxes separate.
        s.enemies[1].sourcePosition={x=-300,y=25}
        s.enemies[2].sourcePosition={x=100,y=-10}
        view.run.phase,view.run.combat='combat',s
        local ui=view.battleUI
        ui.gesture,ui.selected=nil,nil
        for id,n in pairs(scene[2]) do Combat.addStatus(s.player,id,n) end
        Combat.addStatus(s.enemies[2],'vulnerable',1)
        if scene[1]=='ten' then
            for i=1,10 do s.hand[i]={cardId='iron_wave',uid='value_fixture_'..i} end
        end
        view:refresh()
        if scene[1]=='aim' then
            local slot
            for i,c in ipairs(s.hand) do if c.cardId=='strike' then slot=i break end end
            local pose=ui.cardPositions[s.hand[slot].uid]
            local surfaces=assert(Surfaces.get(view.root:GetChild('battlePanel')),'missing native actor manager')
            local target=assert(surfaces:find(s.enemies[2].id),'missing diagnostic aim actor')
            local hit=assert(target:GetChild('hit'),'missing diagnostic aim hitbox')
            -- Controlled aim context for renderer QA, not native pointer evidence.
            ui.gesture={run=view.run,battle=s,turn=s.turn,uid=s.hand[slot].uid,slot=slot,
                phase='combat',origin=pose,sx=pose[1],sy=pose[2],
                x=target.x+hit.x,y=target.y+hit.y,moving=true}
            CardInput.begin(ui.gesture,Theme.canvas.base[2],false,Theme.canvas.base[1])
            ui:render()
        end
        -- Fixture labels identify the controlled stage in logs and screenshots.
        print('CARD_VALUE_FIXTURE stage='..scene[1]..' hand='..#s.hand)
    end
    return function(dt)
        time=time+dt
        -- The official runner may spend time recognising the native loading UI.
        -- Repeat controlled scenes so every requested snapshot still has a stage.
        local index=math.floor(time/7)%#scenes+1
        if index~=last then render(index) last=index end
    end
end
return M
