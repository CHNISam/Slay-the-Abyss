-- TASK-10.7 / TASK-10.8 diagnostic fixture ONLY. Never a production manifest entry.
-- State injection sets up stock content; all preview/help/input follows production handlers.
-- Synthetic callback input is explicit evidence preparation, NOT physical device input.
local M = {fixtureOnly=true}
local Combat, Run = require("abyss_combat"), require("abyss_run")
local Theme = require("abyss_theme")
local L = Theme.layout
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
-- Call once BEFORE GameUI.new. Every recorded callback is also registered on the
-- original control, so actual mouse/touch input continues using the same handler.
-- No property is invented on native userdata; all proxy writes forward unchanged.
function M.capture(stage,events)
    events=events or (Enum and Enum.CursorEventType) or {CursorDown="down",CursorDrag="drag",CursorUp="up",CursorEndDrag="endDrag",CursorEnter="enter",CursorExit="exit",CursorClick="click"}
    local controls, callbacks={},{}
    local function wrap(real,path)
        if controls[path] then return controls[path] end
        local proxy={}
        controls[path]=proxy
        setmetatable(proxy,{
            __index=function(_,key)
                if key=="GetChild" then return function(_,name)
                    local child=real:GetChild(name)
                    if child==nil then return nil end
                    return wrap(child,path.."/"..name)
                end end
                if key=="AddCursorEventListener" then return function(_,event,fn)
                    callbacks[path]=callbacks[path] or {};callbacks[path][event]=fn
                    return real:AddCursorEventListener(event,fn)
                end end
                local value=real[key]
                if type(value)=="function" then return function(_,...) return value(real,...) end end
                return value
            end,
            __newindex=function(_,key,value) real[key]=value end
        })
        return proxy
    end
    local driver={events=events,callbacks=callbacks,controls=controls}
    function driver:emit(path,event,touch,x,y,width,height)
        local fn=assert(self.callbacks["stage/"..path] and self.callbacks["stage/"..path][self.events[event]],"preview missing production listener "..path.."/"..event)
        local k=math.min(width/1280,height/720)
        return fn({touchId=touch,GetUIPos=function() return width/2+(x or 0)*k,height/2+(y or 0)*k end})
    end
    M.driver=driver
    return wrap(stage,"stage"),driver
end
function M.new(view,data,stage,options)
    options=options or {}
    local driver=assert(options.driver or M.driver,"Call abyss_preview_probe.capture(stage) before GameUI.new")
    local self={ownsUpdates=true,fixtureOnly=true,elapsed=0,phase="boot",step=0,phaseTime=0,records={},done=false}
    local ui,panel=view.battleUI,stage:GetChild("battlePanel")
    local function emit(path,event,touch,x,y)
        return driver:emit("battlePanel/"..path,event,touch or 811,x,y,ui.canvasWidth or 1280,ui.canvasHeight or 720)
    end
    local function tap(path,touch)
        local c=driver.callbacks["stage/battlePanel/"..path]
        if c and c[driver.events.CursorDown] then emit(path,"CursorDown",touch) end
        if c and c[driver.events.CursorUp] then emit(path,"CursorUp",touch) end
        emit(path,"CursorClick",touch)
    end
    local function resetInput()
        if ui.gesture then
            local g=ui.gesture
            emit("card"..g.slot.."/hit","CursorEndDrag",g.touch,g.sx,L.cardDrag.cancelY-20)
        end
        ui.help=nil
        if ui.info then tap("statusInfo/hit",899) end
        ui.suppressClick=false
    end
    local function slot(id)
        for i,c in ipairs(view.run.combat.hand) do if c.cardId==id then return i end end
        error("preview missing card "..id)
    end
    local function label(id) return panel:GetChild("card"..slot(id)):GetChild("label").text end
    local function aim(id,index)
        resetInput()
        local i=slot(id);local pose=assert(ui.cardPositions[view.run.combat.hand[i].uid])
        emit("card"..i.."/hit","CursorDown",811,pose[1],pose[2])
        emit("card"..i.."/hit","CursorDrag",811,index==1 and L.enemyRow.xFrom or L.enemyRow.xTo,L.enemyRow.y)
        assert(ui.gesture and ui.gesture.moving,"production drag did not start")
    end
    local function checkReadonly(fn)
        local before=Combat.copy(view.run)
        fn()
        assert(same(before,view.run),"preview/help/input changed committed run or RNG")
    end
    local function record(name,expected)
        self.phase,self.phaseTime=name,0
        panel:GetChild("notice").text="数值/意图验收夹具 · fixtureOnly / 合成控件事件\n"..name
        local battle=view.run.combat
        local info=panel:GetChild("statusInfo")
        local text=""
        if ui.info then text=info:GetChild("title").text.." | "..info:GetChild("name1").text.." | "..info:GetChild("text1").text end
        self.records[#self.records+1]={phase=name,elapsed=self.elapsed,expected=expected,detail=text}
        print("M1_PREVIEW fixtureOnly=true syntheticEvents=true phase="..name.." elapsed="..string.format("%.2f",self.elapsed).." expected="..(expected or "").." detail="..text.." seed="..battle.seed.." hp="..battle.player.hp.." energy="..battle.energy.." gold="..view.run.gold)
    end
    if ui.feedback then ui.feedback:cancel() end
    local run=Run.new(data,41)
    assert(Run.startCombat(run,"cultist_solo"))
    local battle=Combat.new(data,{seed=41,hp=60,deck={"strike","twin_strike","cleave","defend","bash"},enemies={"acid_slime_m","jaw_worm"}})
    -- Fixture setup only. Canonical stock intent effect lists stay unchanged.
    battle.enemies[1].intentIndex=1
    battle.enemies[2].intentIndex=3
    Combat.addStatus(battle.player,"weak",2)
    Combat.addStatus(battle.enemies[2],"vulnerable",2)
    Combat.addStatus(battle.enemies[2],"strength",2)
    run.combat,run.hp,run.gold=battle,battle.player.hp,99
    view.run,ui.run,view.nodeUI.run=run,run,run
    ui.busy,ui.displayBattle,ui.info,ui.help,ui.selected,ui.gesture,ui.target=false,nil,nil,nil,nil,nil,1
    ui.suppressClick=false
    view:refresh();ui:render()
    assert(label("strike")=="对目标造成 4 点伤害。")
    assert(label("twin_strike"):find("每次造成 3 点",1,true))
    assert(label("cleave"):find("6 点",1,true))
    assert(label("defend"):find("5 点",1,true))
    assert(panel:GetChild("enemy2"):GetChild("intent").text=="","Bellow must not display status stacks as damage")
    record("unaimed","strike=4 twin=3x2 cleave=6 defend=5; costs=1/1/1/1/2; AcidSpit=7+Slimed, Bellow=Strength+3/Block6")
    local phases={
        function() checkReadonly(function() aim("strike",1) end);assert(label("strike")=="对目标造成 4 点伤害。");record("strike-aim-plain","4") end,
        function() checkReadonly(function() resetInput();aim("strike",2) end);assert(label("strike")=="对目标造成 6 点伤害。");record("strike-aim-vulnerable","6; other hand cards unchanged") end,
        function() checkReadonly(function() resetInput() end);assert(label("strike")=="对目标造成 4 点伤害。");record("strike-cancel","4; zero cards played, RNG unchanged") end,
        function() checkReadonly(function() aim("twin_strike",2) end);assert(label("twin_strike"):find("每次造成 5 点",1,true));record("multi-aim-vulnerable","5x2; floor(5*0.75*1.5)=5 per hit") end,
        function() checkReadonly(function() resetInput();aim("cleave",2) end);assert(label("cleave"):find("6 点",1,true));record("aoe-aim","label6; per targets6/9, never6~9 range") end,
        function() checkReadonly(function() resetInput();tap("enemy1/intentHit",821) end);assert(ui.info and ui.info.kind=="intent");record("acid-intent-tap","upcoming damage7 and 1 Slimed; not applied player Weak") end,
        function() checkReadonly(function() resetInput();tap("enemy2/intentHit",822) end);assert(ui.info and ui.info.kind=="intent");record("jaw-bellow-tap","upcoming Strength+3 and Block6; existing Strength2 remains on Jaw") end,
        function()
            checkReadonly(function() resetInput();emit("enemy2/statusRow/hit1","CursorDown",823) end)
            record("status-held","actual Jaw status name/layers/detail; pending Bellow not yet applied")
        end,
        function()
            assert(ui.info and ui.info.index==2 and ui.info.statusId,"status long press missing")
            checkReadonly(function() emit("enemy2/statusRow/hit1","CursorUp",823);emit("enemy2/statusRow/hit1","CursorClick",823) end)
            assert(ui.info and not ui.info.transient,"long-press release must preserve modal help")
            record("status-release","no extra play/target/RNG change")
        end,
        function()
            checkReadonly(function() resetInput();emit("card"..slot("bash").."/hit","CursorEnter",824) end)
            record("bash-keyword-hover","Vulnerable keyword; not an applied state")
        end,
        function()
            assert(ui.info and ui.info.kind=="card","Bash keyword hover missing")
            checkReadonly(function() emit("card"..slot("bash").."/hit","CursorExit",824);resetInput();tap("hero/statusRow/hit1",825) end)
            assert(ui.info and ui.info.index==0,"player actual Weak help missing")
            record("player-weak-tap","Weak2 belongs to player; never enemy upcoming action")
        end,
        function()
            resetInput()
            local before=Combat.copy(view.run.combat)
            local id=slot("strike")
            aim("strike",2)
            emit("card"..id.."/hit","CursorUp",811,L.enemyRow.xTo,L.enemyRow.y)
            assert(view.run.combat.enemies[2].hp==before.enemies[2].hp-6,"actual released damage does not match aimed 6")
            assert(view.run.combat.energy==before.energy-1 and #view.run.combat.hand==#before.hand-1,"genuine release played wrong count/cost")
            self.played=true
            record("normal-strike-resolution","actual enemy HP-6 energy3->2 hand5->4; production feedback")
        end,
        function()
            if ui.busy then return false end
            resetInput()
            assert(view.run.combat.energy==2 and #view.run.combat.hand==4)
            record("complete","read-only previews/help plus exactly one normal Strike; no natural-acquisition or full-run claim")
            self.done=true
        end
    }
    function self:update(dt)
        if self.done then return end
        self.elapsed,self.phaseTime=self.elapsed+dt,self.phaseTime+dt
        -- Exactly one production update per driver tick. Fixture hold windows are
        -- wall-clock waits; no view:update call belongs in the external dispatcher.
        view:update(dt)
        if self.phaseTime<4 then return end
        local nextStep=self.step+1
        if phases[nextStep]()~=false then self.step=nextStep end
    end
    return self
end
return M
