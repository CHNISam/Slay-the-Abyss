-- Verify the listening room's queue and once-only death trigger without any combat core or RNG.
local callbacks, nodes, sent, logs = {}, {}, {}, {}
local function node(name)
 if nodes[name] then return nodes[name] end
 local n={};nodes[name]=n
 function n:GetChild(child) return node(name.."/"..child) end
 function n:SetVisible(value)self.visible=value end
 function n:SetLocalScale(...)assert(select('#',...)==3,"native SetLocalScale requires x,y,z");self.scale={...}end
 function n:AddCursorEventListener(_,fn)callbacks[name]=fn end
 return n
end
script={object=node("root"),EnableUpdate=function()end}
Enum={CursorEventType={CursorClick=1}}
game={GetUICanvasSize=function()return 1600,900 end,ServerSignal=function(name)
 local s={name=name,args={}};function s:AddInt(v)self.args[#self.args+1]=v end
 function s:SendSignal()sent[#sent+1]=self end;return s
end}
print=function(s)logs[#logs+1]=s end
assert(loadfile(arg[1]))()
OnStart()
local function click(name)assert(callbacks["root/stage/"..name.."/hit"],name)()end
local function step(seconds)for _=1,seconds*20 do OnUpdate(0.05)end end
local function sounds()local result={};for _,s in ipairs(sent)do if s.name=="SFX_LISTEN"then result[#result+1]=s end end;return result end
click("tour");step(101)
local s=sounds();assert(#s==14,"14 distinct tour entries")
assert(s[1].args[1]==50936 and s[2].args[1]==50941,"legacy AB preserved")
assert(s[3].args[1]==40305 and s[14].args[1]==20139,"candidate order")
local deaths=0;for _,line in ipairs(logs)do if line:find("SFX_DEATH_ONCE",1,true)then deaths=deaths+1 end end
assert(deaths==5,"one death trigger per D0/D1/D2/D3/D4")
click("bgm");click("burst");click("burst");step(9)
assert(#sounds()==20,"six hits, locked duplicate click ignored")
click("mix");step(9);assert(#sounds()==24,"three hits then one death")
click("pick10");click("like");click("tag3")
assert(logs[#logs]:find("SFX_REVIEW D2",1,true) and logs[#logs]:find("满足",1,true),"review records candidate and comment")
assert(nodes["root/stage/detail"].text:find("攻击 A1 / 死亡 D2",1,true),"active mixed pair is visible")
click("burst");click("cancel");step(10);assert(#sounds()==24,"cancel clears pending queue")
io.write("PASS: tour order, legacy AB, once-only deaths, six-hit repetition, BGM mix, review log, cancellation\n")
