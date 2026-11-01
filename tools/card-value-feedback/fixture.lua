-- Diagnostic candidate only. Real production renderer/core; controlled states,
-- not a natural acquisition path, mobile interaction or a normal gameplay pass.
local Combat = require('abyss_combat')
local CardInput = require('abyss_card_input')
local Data, Theme = require('abyss_data'), require('abyss_theme')
local EnemyView=require('abyss_battle_enemy_view')
local Surfaces=require('abyss_monster_surfaces')
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
            local actor=s.enemies[2]
            local manager=assert(Surfaces.get(view.root:GetChild('battlePanel')),'missing controlled native actor manager')
            assert(manager:find(actor.id),'controlled vulnerable actor must own a live native surface')
            local target=EnemyView.geometry(actor)
            local peer=EnemyView.geometry(s.enemies[1])
            -- Explicit diagnostic encounters use constructor positions. Their
            -- hitboxes overlap, so the target's centre also hits the first actor.
            -- Aim inside Cultist's exclusive upper band instead of moving actors.
            local bottom,top=target.hitY-target.hitHeight/2,target.hitY+target.hitHeight/2
            local peerTop=peer.hitY+peer.hitHeight/2
            local aimX,aimY=target.hitX,(math.max(bottom,peerTop)+top)/2
            assert(aimY>peerTop and aimY>bottom and aimY<top,'controlled target needs an exclusive real hitbox point')
            assert(math.abs(aimX-target.hitX)<=target.hitWidth/2 and math.abs(aimY-target.hitY)<=target.hitHeight/2,
                'diagnostic point left the intended actor hitbox')
            assert(not(math.abs(aimX-peer.hitX)<=peer.hitWidth/2 and math.abs(aimY-peer.hitY)<=peer.hitHeight/2),
                'diagnostic point still hits the earlier actor')
            -- Controlled aim context for renderer QA, not native pointer evidence.
            ui.gesture={run=view.run,battle=s,turn=s.turn,uid=s.hand[slot].uid,slot=slot,
                phase='combat',origin=pose,sx=pose[1],sy=pose[2],
                x=aimX,y=aimY,moving=true}
            CardInput.begin(ui.gesture,Theme.canvas.base[2],false,Theme.canvas.base[1])
            ui:render()
            print('CARD_VALUE_FIXTURE aim targetUID='..actor.id..' intendedIndex=2 x='..aimX..' y='..aimY
                ..' label='..view.root:GetChild('battlePanel'):GetChild('card'..slot):GetChild('label').text)
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
