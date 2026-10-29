local H = dofile('tests/lua/support/committed_defeat_fixture.lua')
local count = 0
for _, controller in ipairs({false, true}) do
    for _, phase in ipairs({'damage', 'player_death', 'defeat'}) do
        local ui, root, calls, api = H.setup({controller=controller})
        root:GetChild('battlePanel'):GetChild('endTurn').click()
        H.until_(ui, function() return H.phase(ui, phase) end)
        assert(ui.run.phase == 'defeat' and ui.mode == 'battle' and ui.battleUI.busy)
        assert(not ui.motion.deathReveal, 'guard must cover the earlier playback interval')
        if phase == 'damage' then assert(not ui.battleUI.feedback.deaths.player) end
        local run, battle = ui.run, ui.run.combat
        local hp, gold, rng = battle.player.hp, run.gold, battle.rng
        local restart, settle = H.hit(root, 'menuPanel', 'start'), H.hit(root, 'menuPanel', 'settle')
        -- Engine-delayed releases from the still-hidden result cannot acquire ownership.
        H.gesture(restart, 71); H.gesture(settle, 72)
        H.open(ui, root, api)
        local confirm, cancel = H.hit(root, 'exitPanel', 'confirm'), H.hit(root, 'exitPanel', 'cancel')
        local ok, reason
        if controller then ok, reason=H.event(ui, api, confirm)
        else ok, reason=H.tap(confirm, 33) end
        assert(not ok and reason == 'result_revealing' and calls() == 0,
            'committed ' .. phase .. ' must not request platform settlement')
        if controller then
            assert(not confirm.navigationListeners.confirm())
            assert(not H.event(ui, api, confirm))
        else
            assert(not H.fire(confirm, 'click', 33))
            assert(not H.tap(confirm, 34))
            H.gesture(confirm, 35)
        end
        local elapsed, index = ui.battleUI.feedback.elapsed, ui.battleUI.feedback.index
        ui:update(1)
        assert(ui.battleUI.feedback.elapsed == elapsed and ui.battleUI.feedback.index == index,
            'exit overlay pauses rather than consumes the death presentation')
        assert(ui.run == run and run.combat == battle and battle.player.hp == hp and run.gold == gold and battle.rng == rng)
        if controller then assert(H.event(ui, api, cancel, 'cancel'))
        else assert(H.tap(cancel, 36)) end
        assert(not ui.exitOpen and ui.run == run and calls() == 0)
        H.finish(ui)
        assert(ui.run == run and not ui.battleUI.busy)
        assert(not H.fire(confirm, 'click', 35), 'cancelled exit must expire a released confirm')
        assert(not H.fire(restart, 'click', 71) and not H.fire(settle, 'click', 72))
        assert(not ui.characterOpen and calls() == 0, 'blocked result gesture must not revive after unlock')
        if controller then
            assert(H.event(ui, api, settle))
            assert(not settle.navigationListeners.confirm())
        else
            assert(H.tap(settle, 41))
            assert(not H.fire(settle, 'click', 41))
        end
        assert(calls() == 1 and ui.settlementRequested and ui.run == run)
        count = count + 1
        print('ok committed death exit ' .. count .. ' - ' .. (controller and 'controller ' or 'native touch ') .. phase)
    end
end
assert(count == 6)
print('LUA_PLAYER_DEATH_EXIT_GUARD_PASS ' .. count)
