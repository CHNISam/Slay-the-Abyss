package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Actors = require("abyss_actor")
local data = require("abyss_data")
local count = 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) fn(); count=count+1; print("ok "..count.." - "..name) end
local function battle(enemies,seed)
 return Combat.new(data,{enemies=enemies or {"cultist"},deck={"defend"},seed=seed or 42})
end

test("opening intent grants Ritual rather than immediate Strength or an attack",function()
 local s=battle(); local e=s.enemies[1]
 eq(Combat.intent(s,1).kind,"buff"); eq(e.statuses.ritual,nil)
 assert(Combat.endTurn(s)); eq(s.player.hp,80); eq(e.statuses.ritual,3)
 eq(e.statuses.strength or 0,0); eq(Combat.intent(s,1).kind,"attack")
 local view=Actors.statusView(e); eq(view[1].id,"ritual"); eq(view[1].amount,3)
 assert(view[1].description:find("回合",1,true))
end)

test("source-derived five action trajectory is 0,6,9,12,15",function()
 local s=battle(); local e=s.enemies[1]
 for i,damage in ipairs({0,6,9,12,15}) do
  local hp=s.player.hp; assert(Combat.endTurn(s)); eq(hp-s.player.hp,damage,"round "..i)
  eq(e.statuses.strength or 0,math.max(0,(i-1)*3)); eq(e.statuses.ritual,3)
 end
end)

test("Ritual grows only after all living enemies finish",function()
 local s=battle({"cultist","jaw_worm"}); local e=s.enemies[1]
 assert(Combat.endTurn(s)); s.events={}; assert(Combat.endTurn(s))
 local lastIntent,growth=0,nil
 for i,event in ipairs(s.events) do
  if event.kind=="intent" then lastIntent=i end
  if event.kind=="status" and event.detail.target==e.id and event.detail.status=="strength" then growth=i end
 end
 assert(growth and growth>lastIntent,"Ritual must follow the teammate's action")
end)

test("multiple Cultists have independent first-round suppression",function()
 local s=battle({"cultist","cultist"}); assert(Combat.endTurn(s))
 eq(s.enemies[1].statuses.strength or 0,0); eq(s.enemies[2].statuses.strength or 0,0)
 assert(Combat.endTurn(s)); eq(s.player.hp,68)
 eq(s.enemies[1].statuses.strength,3); eq(s.enemies[2].statuses.strength,3)
 local untouched=battle(); eq(Combat.intent(untouched,1).kind,"buff")
end)

test("lethal poison prevents opening Ritual",function()
 local s=battle({"cultist","jaw_worm"}); local e=s.enemies[1]; e.hp=1
 Combat.addStatus(e,"poison",1); assert(Combat.endTurn(s)); eq(e.hp,0); eq(e.statuses.ritual,nil)
end)

test("lethal Thorns prevents round-end growth while a teammate survives",function()
 local s=battle({"cultist","jaw_worm"}); local e=s.enemies[1]
 assert(Combat.endTurn(s)); e.hp=1; Combat.addStatus(s.player,"thorns",1)
 assert(Combat.endTurn(s)); eq(e.hp,0); eq(e.statuses.strength or 0,0)
 eq(s.phase,"player"); eq(s.enemies[2].hp>0,true)
end)

test("attack uses existing Weak, Vulnerable and Block arithmetic",function()
 local s=battle(); assert(Combat.endTurn(s)); local e=s.enemies[1]
 Combat.addStatus(e,"weak",1); Combat.addStatus(s.player,"vulnerable",2)
 Combat.addStatus(s.player,"barricade",1); s.player.block=3
 assert(Combat.endTurn(s)); eq(s.player.hp,77); eq(s.player.block,0)
 eq(e.statuses.strength,3)
end)

test("sampled HP endpoints and maxHp are inclusive and reproducible",function()
 local found={}
 for seed=0,63 do
  local s=battle(nil,seed); local hp=s.enemies[1].hp
  assert(hp>=48 and hp<=54); eq(s.enemies[1].maxHp,hp)
  eq(battle(nil,seed).enemies[1].hp,hp); found[hp]=true
 end
 assert(found[48] and found[54])
end)

test("failed card restores Ritual and phase bookkeeping atomically",function()
 local s=Combat.new(data,{enemies={"cultist"},deck={"strike"},seed=42}); assert(Combat.endTurn(s))
 local e=s.enemies[1]; local before=Combat.copy(e)
 s.catalog.cards.strike.effects={{op="damage",value=6},{op="gainStatus",status="strength",value=2147483647}}
 s.player.statuses.strength=1
 eq(pcall(Combat.play,s,s.hand[1].uid,1),false)
 eq(e.hp,before.hp); eq(e.statuses.ritual,3); eq(e.aiPhase,before.aiPhase)
 eq(e.ritualSkipRound,before.ritualSkipRound)
end)
print("Cultist runtime: "..count.." groups passed")
