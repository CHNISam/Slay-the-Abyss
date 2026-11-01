local H = dofile("tests/lua/support/battle_action_fixture.lua")
local test, finish = H.suite("LUA_ACTION_OWNERSHIP")
test("Down alone cannot authorize an action before its matching Up", function()
    local h,u,p,e,t,d=H.setup();e("endTurn","down",7);e("endTurn","click",7)
    assert(h.run.combat.turn==1);e("endTurn","up",7);e("endTurn","click",7);d()
    assert(h.run.combat.turn==2)
end)
test("foreign or missing Click cannot consume the matching released action", function()
    local h,u,p,e,t,d=H.setup();e("endTurn","down",7);e("endTurn","up",7)
    e("endTurn","click",8);p:GetChild("endTurn").click();assert(h.run.combat.turn==1)
    e("endTurn","click",7);d();assert(h.run.combat.turn==2)
end)
test("consumed action cannot replay in a later turn", function()
    local h,u,p,e,t,d=H.setup();t("endTurn",7);d()
    e("endTurn","up",7);e("endTurn","click",7);assert(h.run.combat.turn==2)
    t("endTurn",7);d();assert(h.run.combat.turn==3)
end)
test("old pointer cannot release or cancel a newer action pointer", function()
    local h,u,p,e,t,d,deck=H.setup();e("endTurn","down",7);deck();e("endTurn","down",8)
    e("endTurn","up",7);e("endTurn","endDrag",7);e("endTurn","click",7)
    e("endTurn","up",8);e("endTurn","click",7);assert(h.run.combat.turn==1)
    e("endTurn","click",8);d();assert(h.run.combat.turn==2)
end)
test("EndDrag cancels both held and released actions", function()
    for _,released in ipairs({false,true}) do
        local h,u,p,e=H.setup();e("endTurn","down",7)
        if released then e("endTurn","up",7) end
        e("endTurn","endDrag",7);e("endTurn","up",7);e("endTurn","click",7)
        assert(h.run.combat.turn==1)
    end
end)
test("modal and resize between Up and Click invalidate permission", function()
    for _,resize in ipairs({false,true}) do
        local h,u,p,e,t,d,deck=H.setup();e("endTurn","down",7);e("endTurn","up",7)
        if resize then h:resize(1600,900) else deck() end
        e("enemy1","down",8);e("endTurn","click",7);assert(h.run.combat.turn==1)
    end
end)
test("disabled Down does not become valid after the deck closes", function()
    local h,u,p,e=H.setup();assert(h:openDeck());e("endTurn","down",7);assert(h:closeDeck())
    e("endTurn","up",7);e("endTurn","click",7);assert(h.run.combat.turn==1)
end)
test("old reward skip cannot consume a replacement reward object", function()
    local h,u,p,e,t,d=H.reward();local old=h.run.rewards;e("skip","down",7)
    t("card1",8);t('continue',9);assert(h.run.phase=="map");assert(H.Run.startCombat(h.run,"cultist_solo"));h:refresh()
    -- Drive the actual new starter-deck battle through public Run commands.
    for _=1,40 do
        if h.run.phase~="combat" then break end
        local b=h.run.combat
        for _=1,10 do
            if h.run.phase~="combat" then break end
            local uid
            for _,c in ipairs(b.hand) do if H.F.Combat.canPlay(b,c.uid,1) then uid=c.uid;break end end
            if not uid then break end
            assert(H.Run.play(h.run,uid,1))
        end
        if h.run.phase=="combat" then assert(H.Run.endTurn(h.run)) end
    end
    h:refresh();assert(h.run.phase=="reward" and h.run.rewards~=old);t('cardReward',10)
    e("skip","up",7);e("skip","click",7);assert(h.run.phase=="reward" and p:GetChild('rewardStage').visible)
end)
finish()
