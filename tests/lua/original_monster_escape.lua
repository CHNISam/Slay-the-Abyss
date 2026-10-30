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

-- Production Feedback/Combat with dynamic actor templates and native-contract fake controls.
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
    h.surfaces=surfaces
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
            if not h.feedback.busy and next(h.feedback.effects) == nil and next(h.feedback.poses) == nil and next(h.feedback.dying) == nil and next(h.feedback.escaping)==nil then return end
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
local function close(a,b,label)assert(math.abs(a-b)<1e-7,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path)
 path=path or 'combat'
 assert(type(a)==type(b),path..' type')
 if type(a)~='table'then assert(a==b,path..' changed');return end
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,path..' added '..tostring(k))end
end
local function escapingIntent(s)
 for _,e in ipairs(s.enemies)do
  if e.definitionId=='looter' or e.definitionId=='mugger'then
   local found=false
   for i,v in ipairs(e.intents)do if v.id==e.ai.escapeIntent then e.intentIndex=i;found=true end end
   assert(found,'real escape intent')
  end
 end
end
local function start(fast,enemies)
 local h=harness({'strike'},enemies or {'looter','mugger','cultist'},escapingIntent)
 h.feedback:setFastMode(fast)
 h.run(Combat.endTurn)
 h.committed=Combat.copy(h.battle)
 h.until_(kind('enemy_escape'))
 return h
end
local speed=400*Theme.canvas.base[1]/1920
for _,fast in ipairs({false,true})do
 local h=start(fast)
 local a,b,c=h.battle.enemies[1].id,h.battle.enemies[2].id,h.battle.enemies[3].id
 local first=assert(h.feedback.escaping[a]);local boxA=assert(h.surfaces:find(a))
 assert(first.timer==3 and first.x==0 and not first.flipHorizontal,'escape contact is not backdated')
 assert(not h.feedback.escaping[b],'future committed escape not yet presented')
 h.feedback:update(.5)
 assert(h.feedback.current.kind=='enemy_escape' and h.feedback.current.detail.enemy==a,'strict half-second action gate')
 close(first.timer,2.5);close(first.x,.5*speed)
 assert(boxA:GetChild('portrait').localScaleX==-1,'portrait flips horizontally')
 close(boxA:GetChild('portrait').x,.5*speed)
 h.feedback:update(.001)
 assert(h.feedback.current.kind~='enemy_escape' or h.feedback.current.detail.enemy~=a,'later ordinary action no longer blocked by three-second escape')
 assert(h.feedback.escaping[a]==first and first.timer>2,'first independent timer survives next action')
 h.until_(function(entry)return entry.kind=='enemy_escape'and entry.detail.enemy==b end)
 local second=assert(h.feedback.escaping[b]);local boxB=assert(h.surfaces:find(b));local survivor=assert(h.surfaces:find(c))
 assert(first~=second and first.timer<3 and second.timer==3 and second.x==0)
 h.feedback:update(.1)
 close(second.x,.1*speed);assert(first.x>second.x)
 assert(boxA:GetChild('portrait').localScaleX==-1 and boxB:GetChild('portrait').localScaleX==-1)
 assert(survivor.alive and not h.feedback.escaping[c],'survivor identity not confused with moving actors')
 h.drain()
 assert(h.feedback.escaped[a]and h.feedback.escaped[b]and not next(h.feedback.escaping))
 assert(not h.surfaces:find(a)and not h.surfaces:find(b))
 assert(boxA.alive==false and boxB.alive==false and survivor.alive)
 assert(#h.completed==1 and h.completed[1]=='ok')
 same(h.battle,h.committed)
end
print('ESCAPE_REAL_TURN_GATE_TWO_IDS_PASS')
-- Real single escape event at end of journal: completion releases queue, not actor clock.
for _,fast in ipairs({false,true})do
 local h=harness({'strike'},{'looter','cultist'},escapingIntent)
 h.feedback:setFastMode(fast)
 h.run(function(s)return Combat.escapeEnemy(s,s.enemies[1])end)
 local a=h.battle.enemies[1].id;local box=assert(h.surfaces:find(a))
 local core=Combat.copy(h.battle);local state=assert(h.feedback.escaping[a])
 h.feedback:update(.5);assert(h.feedback.busy)
 h.feedback:update(.5);assert(not h.feedback.busy and state.timer==2)
 assert(#h.completed==1 and h.completed[1]=='ok')
 h.feedback:update(0);assert(state.timer==2 and h.surfaces:find(a)==box)
 h.feedback:update(2)
 assert(state.timer==0 and h.feedback.escaping[a]==state and box.alive,'exact-zero frame remains')
 h.feedback:update(0);assert(state.timer==0 and box.alive,'pause at zero does not end early')
 h.feedback:update(.001)
 assert(not h.feedback.escaping[a]and h.feedback.escaped[a]and box.alive==false and not h.surfaces:find(a))
 h.feedback:update(.1);assert(#h.completed==1,'terminal cleanup never completes action twice')
 same(h.battle,core)
end
print('ESCAPE_IDLE_EXACT_ZERO_PASS')
-- A stalled frame entering the actual next committed cue does not backdate contact.
do
 local h=harness({'strike'},{'looter','cultist'},escapingIntent)
 h.run(Combat.endTurn)
 local id=h.battle.enemies[1].id
 h.until_(function(e)return e.kind=='intent'and e.detail.enemy==id end)
 assert(not h.feedback.escaping[id])
 h.feedback:update(20)
 assert(h.feedback.current.kind=='enemy_escape','real next committed action is escape')
 local state=assert(h.feedback.escaping[id]);assert(state.timer==3 and state.x==0,'new contact cannot inherit stalled frame delta')
 h.feedback:update(.5);assert(state.timer==2.5)
 h.feedback:cancel();assert(not next(h.feedback.escaping)and not next(h.feedback.escaped),'cancel clears clocks and terminal history')
end
print('ESCAPE_STALLED_CONTACT_PASS')
-- Duplicate cue while running and again after terminal disposal must not restart/rebind.
do
 local h=start(false,{'looter','cultist'});local id=h.battle.enemies[1].id
 local cue=h.feedback.current;local state=assert(h.feedback.escaping[id]);local box=assert(h.surfaces:find(id))
 local pos=h.feedback.index+1
 table.insert(h.feedback.queue,pos,cue);table.insert(h.feedback.styles,pos,{})
 table.insert(h.feedback.queue,pos+1,{kind='action_wait',detail={seconds=4},frame=cue.frame});table.insert(h.feedback.styles,pos+1,{})
 table.insert(h.feedback.queue,pos+2,cue);table.insert(h.feedback.styles,pos+2,{})
 h.feedback:update(.501)
 assert(h.feedback.current==cue and h.feedback.escaping[id]==state);close(state.timer,2.499)
 h.feedback:update(.501);assert(h.feedback.current.kind=='action_wait')
 h.feedback:update(4.1)
 assert(h.feedback.current==cue and not h.feedback.escaping[id]and h.feedback.escaped[id])
 assert(box.alive==false and not h.surfaces:find(id),'late cue cannot recreate terminated surface')
 h.drain();same(h.battle,h.committed)
end
print('ESCAPE_DUPLICATE_TERMINAL_PASS')
-- All actors escaping: victory waits for terminal animation, ordinary action does not.
do
 local h=start(false,{'looter','mugger'})
 local b=h.battle.enemies[2].id
 h.until_(function(e)return e.kind=='enemy_escape'and e.detail.enemy==b end)
 h.feedback:update(.501)
 assert(h.feedback.current.kind~='victory' and next(h.feedback.escaping),'victory waits for escape clock')
 h.drain();assert(#h.completed==1 and h.completed[1]=='ok');same(h.battle,h.committed)
end
print('ORIGINAL_MONSTER_ESCAPE_PASS real-combat/native-template-fake-host/gate/motion/idle/terminal/core-immutable')
