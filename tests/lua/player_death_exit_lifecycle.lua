local H = dofile('tests/lua/support/committed_defeat_fixture.lua')
local count = 0
local function test(name, fn)
    fn(); count=count+1; print('ok death exit lifecycle ' .. count .. ' - ' .. name)
end
for _, controller in ipairs({false, true}) do
    test((controller and 'controller' or 'native touch') .. ' reveal pause/cancel and fresh restart preserve one run owner', function()
        local ui, root, calls, api = H.setup({controller=controller})
        root:GetChild('battlePanel'):GetChild('endTurn').click()
        H.until_(ui, function() return ui.mode == 'defeat' end)
        assert(ui.motion.deathReveal and not ui.battleUI.busy)
        local run = ui.run
        local restart, settle = H.hit(root, 'menuPanel', 'start'), H.hit(root, 'menuPanel', 'settle')
        H.gesture(restart, 51); H.gesture(settle, 52)
        assert(not H.fire(restart, 'click', 51) and not H.fire(settle, 'click', 52))
        assert(not ui:start() and not ui:settle() and calls() == 0)
        if controller then
            -- Reveal intentionally blocks result-page focus. A native pointer
            -- may still open utilities, then the controller owns that overlay.
            local entry = H.hit(root, 'exitEntry', 'open')
            assert(not entry.canControllerFocus and not entry.navigationListeners.confirm())
            assert(H.tap(entry, 50))
            assert(H.event(ui, api, H.hit(root, 'runMenu', 'abandon')))
        else H.open(ui, root) end
        local confirm, cancel = H.hit(root, 'exitPanel', 'confirm'), H.hit(root, 'exitPanel', 'cancel')
        local ok, reason
        if controller then ok, reason=H.event(ui, api, confirm)
        else ok, reason=H.tap(confirm, 53) end
        assert(not ok and reason == 'result_revealing' and calls() == 0)
        local age = ui.motion.t
        ui:update(1)
        assert(ui.motion.t == age and ui.motion.deathReveal, 'overlay must pause result reveal')
        if controller then assert(H.event(ui, api, cancel, 'cancel'))
        else assert(H.tap(cancel, 54)) end
        H.finish(ui)
        assert(not H.fire(restart, 'click', 51) and not H.fire(settle, 'click', 52))
        assert(ui.run == run and not ui.characterOpen and calls() == 0)
        if controller then assert(H.event(ui, api, restart)); assert(not restart.navigationListeners.confirm())
        else assert(H.tap(restart, 55)); assert(not H.fire(restart, 'click', 55)) end
        assert(ui.characterOpen and ui.run == run)
        local characterCancel = H.hit(root, 'characterPanel', 'cancel')
        if controller then assert(H.event(ui, api, characterCancel, 'cancel'))
        else assert(H.tap(characterCancel, 56)) end
        assert(not ui.characterOpen and ui.run == run)
        if controller then assert(H.event(ui, api, restart)) else assert(H.tap(restart, 57)) end
        assert(H.F.confirmStart(ui) and ui.run ~= run)
        local replacement = ui.run
        assert(not ui:confirmCharacter() and ui.run == replacement, 'duplicate restart cannot replace the new run')
        assert(not ui.motion.deathReveal and not ui.battleUI.feedback.deaths.player and calls() == 0)
        assert(not root:GetChild('menuPanel'):GetChild('deathShade').visible)
        assert(not root:GetChild('battlePanel'):GetChild('feedback'):GetChild('deathShade').visible)
    end)
end

test('ordinary map exit failure needs a new gesture and remains cancellable/retryable', function()
    local ui, root, calls = H.setup({map=true, normal=true, settle=function(n) return n>1 end})
    local run, hp, gold = ui.run, ui.run.hp, ui.run.gold
    H.open(ui, root)
    local confirm = H.hit(root, 'exitPanel', 'confirm')
    assert(not H.tap(confirm, 61) and calls() == 1)
    assert(not H.fire(confirm, 'click', 61) and calls() == 1)
    H.gesture(confirm, 62)
    assert(H.tap(H.hit(root, 'exitPanel', 'cancel'), 63))
    H.open(ui, root)
    assert(not H.fire(confirm, 'click', 62) and calls() == 1)
    assert(H.tap(confirm, 64) and calls() == 2)
    assert(not H.fire(confirm, 'click', 64) and calls() == 2)
    assert(ui.run == run and run.phase == 'map' and run.hp == hp and run.gold == gold)
end)

test('ordinary controller map exit still settles exactly once', function()
    local ui, root, calls, api = H.setup({map=true, normal=true, controller=true})
    H.open(ui, root, api)
    local confirm = H.hit(root, 'exitPanel', 'confirm')
    assert(H.event(ui, api, confirm) and calls() == 1)
    assert(not confirm.navigationListeners.confirm() and calls() == 1)
end)

test('ordinary non-defeat combat playback remains voluntarily exitable', function()
    local ui, root, calls = H.setup({normal=true})
    root:GetChild('battlePanel'):GetChild('endTurn').click()
    H.until_(ui, function() return H.phase(ui, 'damage') end)
    assert(ui.run.phase == 'combat' and ui.battleUI.busy)
    local run, battle, hp = ui.run, ui.run.combat, ui.run.combat.player.hp
    H.open(ui, root)
    assert(H.tap(H.hit(root, 'exitPanel', 'confirm'), 65) and calls() == 1)
    assert(ui.run == run and run.phase == 'combat' and run.combat == battle and battle.player.hp == hp)
end)

for _, revive in ipairs({'fairy', 'tail'}) do
    test(revive .. ' revival is not treated as committed defeat even during playback', function()
        local ui, root, calls = H.setup({revive=revive})
        root:GetChild('battlePanel'):GetChild('endTurn').click()
        assert(ui.run.phase == 'combat' and ui.run.combat.player.hp > 0 and ui.battleUI.busy)
        assert(not ui.battleUI.feedback.deaths.player and not ui.motion.deathReveal)
        for _, entry in ipairs(ui.battleUI.feedback.queue) do
            assert(entry.kind ~= 'player_death' and entry.kind ~= 'defeat')
        end
        H.open(ui, root)
        assert(H.tap(H.hit(root, 'exitPanel', 'confirm'), 66) and calls() == 1)
    end)
end

test('cancelled death presentation and interrupted restart clear all death ownership', function()
    local ui, root, calls = H.setup()
    root:GetChild('battlePanel'):GetChild('endTurn').click()
    H.until_(ui, function() return H.phase(ui, 'player_death') end)
    H.open(ui, root)
    assert(not H.tap(H.hit(root, 'exitPanel', 'confirm'), 67) and calls() == 0)
    assert(H.tap(H.hit(root, 'exitPanel', 'cancel'), 68))
    ui.battleUI.feedback:cancel(); ui:refresh()
    assert(not ui.battleUI.busy and not ui.motion.deathReveal)
    local run = ui.run
    assert(ui:start() and ui.characterOpen)
    assert(ui:closeCharacters() and ui.run == run)
    assert(H.F.start(ui) and ui.run ~= run and not ui.battleUI.feedback.deaths.player)
    local replacement = ui.run
    assert(not ui:confirmCharacter() and ui.run == replacement and calls() == 0)
end)

assert(count == 8)
print('LUA_PLAYER_DEATH_EXIT_LIFECYCLE_PASS ' .. count)
