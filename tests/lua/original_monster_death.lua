package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Feedback = require("abyss_feedback")
local Combat = require("abyss_combat")
local Events = require("abyss_events")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")
local T, S = Theme.motion, Theme.space
local F=dofile("tests/lua/support/game_ui_fixture.lua")
local Surfaces=require("abyss_monster_surfaces")
local EnemyView=require("abyss_battle_enemy_view")

-- Drives the production adapter against the generated native tree with a recording audio spy.
local images = 0
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "", x = 0, y = 0,
        localScaleX = 1, localScaleY = 1 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(source, id) assert(source == "static" and type(id) == "number") images = images + 1 self.imageId = id end
    function c:SetAsLastSibling() end
    return c
end
local function find(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then return entry end
        local found = find(entry.children or {}, name)
        if found then return found end
    end
end
local function harness(deck, enemies, prepare)
    local stage = F.control(assert(find(require("abyss_ui_layout"), "battlePanel")))
    local h = {stage = stage, sounds = {}, completed = {}, boxes={}}
    local platform={monsterActors=F.monsterActors(),imageSource="static",color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end,
        sound=function(cue)h.sounds[#h.sounds+1]=cue end}
    local surfaces=Surfaces.new(stage,platform)
    local function present(frame)
        local rows=EnemyView.slots(frame,h.feedback)
        surfaces:select(rows,h.battle)
        for _,entry in ipairs(rows)do
            local box=surfaces:find(entry.id);h.boxes[entry.id]=box
            h.feedback.bindEnemySlot(entry.controlSlot,entry.id);box:SetVisible(true)
        end
    end
    h.feedback=Feedback.new(stage,platform,present,function(failure)h.completed[#h.completed+1]=failure or "ok"end)
    h.battle = Combat.new(Data, {deck = deck, enemies = enemies, seed = 11})
    if prepare then
        local original = {}
        for i, enemy in ipairs(h.battle.enemies) do original[i] = enemy.intents end
        prepare(h.battle)
        -- Custom feedback-only intents must not retain an unrelated production policy.
        for i, enemy in ipairs(h.battle.enemies) do
            if enemy.intents ~= original[i] then enemy.ai, enemy.intentIndex = nil, 1 end
        end
    end
    present(h.battle)
    function h.run(command)
        local before, first = Events.frame(h.battle), #h.battle.events + 1
        assert(command(h.battle))
        h.feedback:begin(before, h.battle, first, Presentation, {0, -200})
    end
    function h.play(target) h.run(function(s) return Combat.play(s, s.hand[1].uid, target or 1) end) end
    -- Advance in small frames until a step matches; returns frames spent and their total time.
    function h.until_(match, allowEnd)
        local dt = 0.01
        local frames, time = 0, 0
        for _ = 1, 2000 do
            local entry = h.feedback.current
            if entry and match(entry) then return frames, time end
            if not h.feedback.busy then
                if allowEnd then return frames, time end
                error("queue ended before match")
            end
            h.feedback:update(dt) frames, time = frames + 1, time + dt
        end
        error("never matched")
    end
    function h.drain(each)
        for _ = 1, 4000 do
            if not h.feedback.busy and next(h.feedback.effects) == nil and next(h.feedback.poses) == nil and next(h.feedback.dying) == nil then return end
            h.feedback:update(0.01) if each then each() end
        end
        error("feedback never settled")
    end
    function h.part(name,part)
        local index=tonumber(name:match("^enemy(%d+)$"))
        local box=index and surfaces:find(h.battle.enemies[index].id) or stage:GetChild(name)
        return assert(box):GetChild(part)
    end
    function h.portrait(name)return h.part(name,'portrait')end
    return h
end
local function kind(k) return function(entry) return entry.kind == k end end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function count(list, value) local c = 0 for _, v in ipairs(list) do if v == value then c = c + 1 end end return c end

local Painter=require('abyss_feedback_actor_painter')
local function close(a,b,label)assert(math.abs(a-b)<1e-8,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
-- Exact independent creature clock / Color.lerp recurrence, including strict terminal threshold.
for _,life in ipairs({1.8,1.0})do
 local box=control({name='creature',children={{name='portrait'},{name='impact',visible=false},{name='shield'},{name='floating'},{name='hpGhost'}}})
 local state={dying={enemy={age=0,alpha=1,lifetime=life}},effects={},poses={},escaping={}}
 local unit={hp=0,id='enemy',definitionId='cultist'}
 local ctx={state=state,actor=function()return unit,box end,platform={color=function(r,g,b,a)return{r=r,g=g,b=b,a=a}end}}
 Painter.paint(ctx,'enemy',0,{})
 local portrait=box:GetChild('portrait')
 local rgb={portrait.imageColor.r,portrait.imageColor.g,portrait.imageColor.b}
 Painter.advanceDeaths(ctx,0.1);Painter.paint(ctx,'enemy',0.1,{})
 close(state.dying.enemy.alpha,.7,'source lerp after .1')
 assert(portrait.imageColor.a==math.floor(255*.7))
 assert(portrait.imageColor.r==rgb[1]and portrait.imageColor.g==rgb[2]and portrait.imageColor.b==rgb[3])
 assert(portrait.y==0 and portrait.localScaleX==1 and portrait.localScaleY==1,'death must not sink, grow or squash')
 assert(not box:GetChild('impact').visible,'source death does not invent a shard burst')
 Painter.advanceDeaths(ctx,0.1);Painter.paint(ctx,'enemy',.1,{})
 close(state.dying.enemy.alpha,.49,'source lerp composes per frame, not quadratic age')
 Painter.advanceDeaths(ctx,life-.2)
 assert(state.dying.enemy and box.visible,'timer exactly zero remains drawable')
 Painter.advanceDeaths(ctx,.001)
 assert(not state.dying.enemy and not box.visible,'only timer strictly below zero is terminal')
end
-- Unbound actor still advances; scarce display controls must never own the clock.
do
 local state={dying={enemy={age=0,alpha=1,lifetime=1.8}},effects={},poses={}}
 local ctx={state=state,actor=function()return nil,nil end}
 Painter.advanceDeaths(ctx,.5);Painter.paint(ctx,'enemy',.5,{})
 assert(state.dying.enemy and state.dying.enemy.age==.5)
 Painter.advanceDeaths(ctx,1.31);assert(not state.dying.enemy)
end
local function deathHarness(fast,allDead)
 local h=harness({'strike'},allDead and {'cultist'}or{'cultist','cultist','cultist'},function(s)s.enemies[allDead and 1 or 2].hp=1 end)
 h.feedback:setFastMode(fast)
 local target=allDead and 1 or 2
 h.play(target);h.until_(kind('death'))
 local id=h.battle.enemies[target].id
 assert(h.feedback.dying[id]and h.feedback.dying[id].lifetime==(fast and 1 or 1.8))
 return h,id
end
for _,fast in ipairs({false,true})do
 local h,id=deathHarness(fast,false)
 local age=h.feedback.dying[id].age
 h.feedback:update(.01)
 assert(not h.feedback.current or h.feedback.current.kind~='death','death is not an action wait')
 assert(h.feedback.dying[id]and h.feedback.dying[id].age>age,'independent fade outlives action gate')
 local life=fast and 1 or 1.8
 while h.feedback.dying[id]and h.feedback.dying[id].age<life-.1 do h.feedback:update(.01)end
 assert(h.feedback.dying[id],'normal/fast death not shortened to old theme .35s')
 for _=1,30 do h.feedback:update(.01)end
 assert(not h.feedback.dying[id])
 local terminal,deadId=deathHarness(fast,true)
 for _=1,30 do terminal.feedback:update(.01)end
 assert(terminal.feedback.dying[deadId]and terminal.feedback.current.kind~='victory','all-dead result waits for source creature timer')
 terminal.drain()
 assert(not terminal.feedback.dying[deadId]and #terminal.completed==1 and terminal.completed[1]=='ok')
end

-- The timer begins at the lethal contact, while DamageAction is still waiting.
for _,fast in ipairs({false,true})do
 local h=harness({'strike'},{'cultist','cultist'},function(s)s.enemies[1].hp=1 end)
 h.feedback:setFastMode(fast);h.play(1);h.until_(kind('damage'))
 local id=h.battle.enemies[1].id
 local dying=assert(h.feedback.dying[id],'lethal damage contact starts death before the queued death cue')
 assert(dying.age==0 and dying.alpha==1)
 h.feedback:update(.05)
 assert(h.feedback.current.kind=='damage','test must observe the original damage action wait')
 assert(h.feedback.dying[id]==dying);close(dying.age,.05);close(dying.alpha,.85)
 h.until_(kind('death'))
 assert(h.feedback.dying[id]==dying and dying.age>=.1,'later death cue keeps the original clock')
 local second=h.feedback.index+1
 table.insert(h.feedback.queue,second,h.feedback.current)
 table.insert(h.feedback.styles,second,h.feedback.style)
 local age,alpha=dying.age,dying.alpha
 h.feedback:update(.01)
 assert(h.feedback.dying[id]==dying and dying.age>age and dying.alpha<alpha,'duplicate death cue is idempotent')
end
-- Area victims enter independently at their own contact, not the later grouped cue.
do
 local h=harness({'cleave'},{'cultist','cultist','cultist'},function(s)for _,a in ipairs(s.enemies)do a.hp=1 end end)
 h.play();h.until_(kind('damage'))
 local first=assert(h.feedback.dying[h.battle.enemies[1].id])
 assert(not h.feedback.dying[h.battle.enemies[2].id],'future committed victim is not yet presented')
 h.feedback:update(.01)
 local second=assert(h.feedback.dying[h.battle.enemies[2].id])
 assert(first.age>0 and second.age==0 and first~=second)
 h.feedback:update(.01)
 local third=assert(h.feedback.dying[h.battle.enemies[3].id])
 assert(second.age>0 and third.age==0)
 h.feedback:update(.05)
 assert(h.feedback.current.kind=='damage'and third.age>.04,'last area victim fades during its action wait')
end
-- A real previous hit supplies a non-white current tint; lethal contact snapshots it.
do
 local h=harness({'twin_strike'},{'cultist','cultist'},function(s)s.enemies[1].hp=7 end)
 h.feedback:setFastMode(true);h.play(1);h.until_(kind('damage'))
 local id=h.battle.enemies[1].id
 assert(not h.feedback.dying[id])
 h.feedback:update(.05)
 local before=h.feedback.tints[id]
 assert(before and (before.r~=Theme.color.text.r or before.g~=Theme.color.text.g),'previous real damage must visibly tint victim')
 h.feedback:update(.05)
 local dying=assert(h.feedback.dying[id],'second real hit kills')
 assert(dying.tone.r==before.r and dying.tone.g==before.g and dying.tone.b==before.b,'lethal contact captures already rendered RGB')
 for _=1,4 do h.feedback:update(.01)end
 local colour=h.portrait('enemy1').imageColor
 assert(colour.r==before.r and colour.g==before.g and colour.b==before.b,'fade retains exact contact RGB rather than recapturing later damage flash')
end

-- A delayed duplicate cue after disposal must never resurrect a previously dying actor.
do
 local h=harness({'strike'},{'cultist','cultist'},function(s)s.enemies[1].hp=1 end)
 h.play(1);h.until_(kind('damage'))
 local id=h.battle.enemies[1].id
 local pos=h.feedback.index+1
 table.insert(h.feedback.queue,pos,{kind='action_wait',detail={seconds=2.0},frame=h.feedback.current.frame})
 table.insert(h.feedback.styles,pos,{})
 h.until_(kind('death'))
 assert(not h.feedback.dying[id]and h.feedback.deaths[id],'expired death cue cannot restart clock')
 assert(h.boxes[id].alive==false,'expired death cue cannot reshow the disposed actor')
 h.feedback:cancel();assert(next(h.feedback.tints)==nil,'battle reset clears per-actor tint state')
end
print('ORIGINAL_MONSTER_DEATH_PASS source-clock/alpha/no-collapse/action-independent/result-gate/fast')
