local NativeActors=dofile('tests/lua/support/current_monster_controls.lua')
local actorControl=dofile('tests/lua/support/game_ui_fixture.lua').actorControl
local H = dofile("tests/lua/support/battle_gesture_fixture.lua")
local Combat = H.F.Combat
local count=0
local function test(name,fn) fn(); count=count+1; print("ok status help "..count.." - "..name) end
local function setup()
    local host, ui, panel = H.setup({"bash","strike","defend"},{"spike_slime_m"})
    -- Native cursorArea has no interactable property (observed on CN 7.1).
    local hit=panel:GetChild("statusInfo"):GetChild("hit")
    assert(hit.kind=='cursorArea' and hit.raycastTarget~=false)
    local ok=pcall(function()return hit.interactable end)
    assert(not ok,'shared native CursorArea fixture must reject unsupported field reads')
    local s=Combat.copy(host.run.combat);host.run.combat=s
    s.enemies[1].ai=nil; s.enemies[1].intentIndex=2
    assert(s.enemies[1].intents[2].id=="spike_slime_m_2")
    ui:render()
    local function emit(box,event,touch)
        assert(box.listeners and box.listeners[event],box.name.." missing "..event)
        return box.listeners[event]({touchId=touch or 7})
    end
    return host,ui,panel,s,emit
end
test("debuff intent is an upcoming action, not an existing status or a stack count",function()
    local h,u,p,s,emit=setup()
    assert(actorControl(p,"enemy1"):GetChild("intent").text=="", "non-attack intent must not display a status stack")
    local icon=actorControl(p,"enemy1"):GetChild('intentIcon')
    assert(icon.visible and icon.imageId==H.F.Theme.icon.intent.debuff,'non-attack debuff has its visible approved glyph')
    assert(not actorControl(p,"enemy1"):GetChild('intentLabel').visible)
    assert(require('abyss_battle_intent_view').intentView(s,1).label=='削弱')
    assert((s.player.statuses.frail or 0)==0 and (s.enemies[1].statuses.frail or 0)==0)
    emit(actorControl(p,"enemy1"):GetChild("intentHit"),"click")
    local info=p:GetChild("statusInfo")
    assert(info.visible and info:GetChild("tag").text:find("下一步行动",1,true))
    assert(info:GetChild("summary").text:find("尚未执行",1,true))
    assert(info:GetChild("text1").text:find("使你获得 1 回合脆弱",1,true))
    -- The row names the status and stack, says how long it would last and what it would do.
    assert(info:GetChild("name1").text=="脆弱 1" and info:GetChild("tag1").text=="持续 1 回合")
    assert(info:GetChild("note1").text:find("25%",1,true))
    assert((s.player.statuses.frail or 0)==0 and (s.enemies[1].statuses.frail or 0)==0)
end)
test("actual Vulnerable names its owner, name, stack and effect in visible text frames",function()
    local h,u,p,s,emit=setup()
    Combat.addStatus(s.enemies[1],"vulnerable",1); u:render()
    emit(NativeActors.power(NativeActors.actor(p,s.enemies[1]),"vulnerable"):GetChild("hit"),"click")
    local info=p:GetChild("statusInfo")
    assert(info:GetChild("name1").text=="易伤 1")
    assert(info:GetChild("text1").text:find("50%",1,true))
    for _,name in ipairs({"title","summary","name1","text1"}) do
        assert(info:GetChild(name).sizeDeltaY>=H.F.Theme.layout.nativeText.lineHeight,name.." would clip on the native client")
    end
    local theme=H.F.Theme
    local room=theme.canvas.base[2]-theme.layout.topBar.height-theme.space.s-theme.canvas.safe.y
    assert(info:GetChild("plate").sizeDeltaY<=room,"detail panel must fit below the top bar")
end)
test("hover opens a read-only tooltip and exits without changing combat or target",function()
    local h,u,p,s,emit=setup()
    Combat.addStatus(s.player,"frail",2); u:render()
    local hit=p:GetChild("hero"):GetChild("statusRow"):GetChild("hit1")
    local before=Combat.copy(s);local target=u.target
    emit(hit,"enter");h:update(0.4)
    local info=p:GetChild("statusInfo")
    assert(info.visible and info:GetChild("name1").text=="脆弱 2")
    assert(info:GetChild("text1").text:find("25%",1,true))
    assert(not info:GetChild("hit").visible,"hover must not cover the play surface with a modal hit")
    emit(hit,"exit");assert(not info.visible)
    assert(s.player.hp==before.player.hp and s.seed==before.seed and #s.events==#before.events and u.target==target)
end)
test("long press opens status help and its release cannot play a selected card",function()
    local h,u,p,s,emit=setup()
    Combat.addStatus(s.enemies[1],"vulnerable",2);u:render()
    local card
    for _,instance in ipairs(s.hand) do if instance.cardId=="strike" then card=instance end end
    u.selected=card.uid;u:render()
    local hp,energy,hand=s.enemies[1].hp,s.energy,#s.hand
    local hit=NativeActors.power(NativeActors.actor(p,s.enemies[1]),"vulnerable"):GetChild("hit")
    emit(hit,"down",9);h:update(0.34);assert(not p:GetChild("statusInfo").visible)
    h:update(0.02);assert(p:GetChild("statusInfo").visible)
    emit(hit,"up",9);emit(hit,"click",9)
    assert(s.enemies[1].hp==hp and s.energy==energy and #s.hand==hand and u.selected==card.uid)
end)
test("card keyword hover explains the keyword without granting its status",function()
    local h,u,p,s,emit=setup()
    local slot
    for i,card in ipairs(s.hand) do if card.cardId=="bash" then slot=i end end
    emit(p:GetChild("card"..slot):GetChild("hit"),"enter");h:update(0.4)
    local info=p:GetChild("statusInfo")
    assert(info.visible and info:GetChild("tag").text:find("关键词",1,true))
    assert(info:GetChild("name1").text:find("易伤",1,true))
    assert((s.enemies[1].statuses.vulnerable or 0)==0 and #s.hand==3 and s.energy==3)
end)
test("a pending hold cannot follow a replacement enemy in the same slot",function()
    local h,u,p,s,emit=setup()
    local hit=actorControl(p,"enemy1"):GetChild("intentHit")
    emit(hit,"down",11)
    s.enemies[1]=Combat.copy(s.enemies[1])
    h:update(0.4)
    emit(hit,"up",11);emit(hit,"click",11)
    assert(not p:GetChild("statusInfo").visible)
end)

test("leaving combat for the deck cancels pending help",function()
    local h,u,p,s,emit=setup()
    emit(actorControl(p,"enemy1"):GetChild("intentHit"),"enter")
    u:setActive(false);h:update(0.4);u:setActive(true);h:update(0.4)
    assert(not p:GetChild("statusInfo").visible)
end)

test("a different finger cannot release another finger's help token",function()
    local h,u,p,s,emit=setup()
    local hit=actorControl(p,"enemy1"):GetChild("intentHit")
    emit(hit,"down",11);emit(hit,"up",12);emit(hit,"click",12)
    assert(not p:GetChild("statusInfo").visible)
end)
print("LUA_STATUS_HELP_PASS "..count)
