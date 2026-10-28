-- Generated controls and explicit source room setup, not native/live evidence.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local F,Run,C,Q,R=H.F,require('abyss_run'),require('abyss_combat'),require('abyss_encounter_queue'),require('abyss_reptomancer')
local View,Slots,A=require('abyss_battle_intent_view'),require('abyss_battle_enemy_view'),require('abyss_actor')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function has(text,part)assert(text:find(part,1,true),text..' missing '..part)end
local seed
for i=1,50 do local raw=tostring(i);if Q.peek(Q.new(raw,3),'elite')=='Reptomancer'then seed=raw;break end end
local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=seed,campaign=true,prologue=false,
 imageSource='static',color=function(red,green,blue,alpha)return{r=red,g=green,b=blue,a=alpha}end})
assert(host:start());local run=host.run
run.act,run.floor,run.encounters=3,37,Q.new(seed,3)
assert(Run.startRoomCombat(run,'elite'));host:refresh()
local panel,ui=root:GetChild('battlePanel'),host.battleUI
local _,tap=H.controls(panel)
local function drain()for _=1,400 do if not ui.busy then return end;host:update(.05)end;assert(not ui.busy)end
local s,leader=run.combat,run.combat.enemies[2]
local function visible()
 local rows=Slots.slots(s)
 for slot,row in ipairs(rows)do local box=panel:GetChild('enemy'..slot)
  assert(box.visible);eq(box:GetChild('name').text,row.actor.name)
  eq(box:GetChild('hp').text,string.format('%d/%d',row.actor.hp,row.actor.maxHp))
 end
 for slot=#rows+1,5 do assert(not panel:GetChild('enemy'..slot).visible)end
 return rows
end
visible();local before=C.copy(s)
local view=View.intentView(s,2);eq(view.kind,'unknown');has(view.text,'1');has(view.text,'4');has(view.text,'浮游蛇刃')
eq(panel:GetChild('enemy2'):GetChild('intentIcon').imageId,F.Theme.icon.intent.unknown)
local stab=View.intentView(s,1);eq(stab.value,'9');eq(stab.badge,'debuff');has(stab.text,s.catalog.cards.wound.name);has(stab.text,'弃牌堆')
-- Read-only preview may never advance streams, mutate history or fill slots.
local Snapshot=require('abyss_snapshot');local restore=Snapshot.capture(s)
for _=1,3 do View.intentView(s,1);View.intentView(s,2)end
local after=C.copy(s);restore()
local function same(a,b)eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
same(after,before)
-- Real End Turn control performs the source Summon. The newly created Dagger
-- gets a fresh stable ID and occupies its source-smart position immediately.
tap('endTurn',201);drain();eq(#s.enemies,4);eq(s.enemies[3].id,'snake_dagger_4');eq(s.enemies[4].id,'snake_dagger_3')
local rows=visible();eq(#rows,4);eq(s.enemies[3].intents[s.enemies[3].intentIndex].id,'stab')
local explosion=View.intentView(s,1);eq(explosion.value,'25');has(explosion.text,'自毁');has(explosion.text,'无视格挡')
local infoHit=panel:GetChild('enemy1'):GetChild('intentHit');infoHit.click({touchId=202})
local info=panel:GetChild('statusInfo');assert(info.visible);has(info:GetChild('text2').text,'生命')
info:GetChild('hit').click({touchId=203});assert(not info.visible)
-- Component refill stresses all five slots while retaining corpses. Never
-- rebuild actor IDs from visible positions or remove an old table from core.
R.summon(C,s,leader);host:refresh();rows=visible();eq(#rows,5)
local corpse=s.enemies[1];local id=corpse.id;C.damage(s,s.player,corpse,999,true);R.summon(C,s,leader)
host:refresh();rows=visible();eq(#rows,5);assert(#s.enemies>5);eq(corpse.id,id)
for slot,row in ipairs(rows)do eq(row.actor,s.enemies[row.index]);eq(row.id,s.enemies[row.index].id)
 local box=panel:GetChild('enemy'..slot)
 box:GetChild('statusRow'):GetChild('hit').click({touchId=210+slot});eq(ui.info.id,row.id);eq(ui.info.index,row.index)
 info:GetChild('hit').click({touchId=220+slot})
end
-- Source SnakeStrike retains two-hit face plus Weak text through approved icons.
for i,move in ipairs(leader.intents)do if move.id=='snake_strike'then leader.intentIndex=i end end
local index;for i,e in ipairs(s.enemies)do if e==leader then index=i end end
view=View.intentView(s,index);eq(view.value,'13×2');eq(view.badge,'debuff');has(view.text,'虚弱')
local old=s.enemies[1].id;A.applyPower(s,s.player,'strength',999,s.player)
leader.hp=1;host:refresh()
-- Target the source leader through its current *screen* mapping, not index2.
local slot;for i,row in ipairs(Slots.slots(s))do if row.actor==leader then slot=i end end
local attack
for i,c in ipairs(s.hand)do local d=C.cardDefinition(s,c);if d.type=='attack'and d.cost>=0 and d.cost<=s.energy then attack=i;break end end
assert(attack,'real source starter hand needs an attack')
tap('card'..attack,240);tap('enemy'..slot,241);drain()
eq(run.phase,'reward');eq(run.victories,1);eq(s.enemies[1].id,old)
for _,e in ipairs(s.enemies)do eq(e.hp,0)end
print('REPTOMANCER_UI real-controls/Unknown/9-Wound/25-self-loss/twin-Weak/5-slots/corpses/stable-target/reward-once PASS')
