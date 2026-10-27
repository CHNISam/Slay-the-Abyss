-- Real generated five-slot controls at explicit boundary HP. Not live/native.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local C,A=H.F.Combat,require('abyss_actor')
local Slots=require('abyss_battle_enemy_view')
local Status=require('abyss_battle_status_view')
local host,ui,panel,_,tap,drain,_,root=H.setup({'bludgeon','bludgeon','bludgeon'},{'darkling','darkling','darkling'})
local s=host.run.combat
local function click(control,touch)
 assert(control.visible and control.listeners and control.listeners.click,'missing real click control')
 return control.listeners.click({touchId=touch})
end
local function has(text,part)assert(text:find(part,1,true),text..' missing '..part)end
local info=panel:GetChild('statusInfo')
local function detail(box,touch,part)
 click(box:GetChild('intentHit'),touch);assert(info.visible)
 local found=false
 for i=1,4 do local row=info:GetChild('text'..i);if row and row.text and row.text:find(part,1,true)then found=true end end
 assert(found,'missing intent detail '..part);click(info:GetChild('hit'),touch+1)
end
assert(Slots.capacity==5 and #Slots.slots(s)==3)
for i,e in ipairs(s.enemies)do local box=panel:GetChild('enemy'..i)
 assert(box.visible);has(box:GetChild('name').text,'共生暗影')
 assert(box:GetChild('hp').text==string.format('%d/%d',e.hp,e.maxHp))
 local entry=C.statusView(e)[1];assert(entry.id=='regrow'and entry.amount==-1 and Status.statusKind(entry)=='buff')
 local text,tag,note=Status.statusDetail(entry,{},e)
 assert(text=='生命归零后休眠；第二次行动时回复半数最大生命'and tag=='复生')
 assert(note=='所有暗影同时休眠时，全体被击败','linked-death condition must remain visible')
 assert(box:GetChild('statusRow'):GetChild('count1').text=='','no number for Life Link sentinel')
end
assert(not panel:GetChild('enemy4').visible and not panel:GetChild('enemy5').visible)
local e=s.enemies[1];e.hp=1;host:refresh()
tap('card1',201);tap('enemy1',202);drain()
assert(host.run.phase=='combat'and e.hp==0 and e.halfDead and A.isPresent(e)and not A.isActive(e))
assert(panel:GetChild('enemy1').visible);has(panel:GetChild('enemy1'):GetChild('hp').text,'0/')
assert(panel:GetChild('enemy1'):GetChild('intentLabel').text=='再生')
assert(not ui.feedback.deaths[e.id]);detail(panel:GetChild('enemy1'),203,'复生')
-- Clicking a sleeping slot cannot spend a targeted attack or secretly hit an ally.
s.energy=3;host:refresh();local uid=s.hand[1].uid;local energy=s.energy;local allyHp=s.enemies[2].hp
tap('card1',205);tap('enemy1',206);drain()
assert(s.hand[1].uid==uid and s.energy==energy and s.enemies[2].hp==allyHp)
tap('endTurn',207);drain()
assert(e.hp==0 and e.halfDead);assert(panel:GetChild('enemy1').visible)
assert(panel:GetChild('enemy1'):GetChild('intentLabel').text=='复生');detail(panel:GetChild('enemy1'),208,'生命')
tap('endTurn',210);drain()
assert(e.hp==math.floor(e.maxHp/2)and not e.halfDead and A.isActive(e))
assert(panel:GetChild('enemy1'):GetChild('hp').text==string.format('%d/%d',e.hp,e.maxHp))
-- Two previously sleeping actors must collapse at final linked death too.
for i=1,2 do
 s.enemies[i].hp=1;s.energy=3;host:refresh();tap('card1',212+i*2);tap('enemy'..i,213+i*2);drain()
 assert(host.run.phase=='combat'and s.enemies[i].halfDead and not ui.feedback.deaths[s.enemies[i].id])
end
s.enemies[3].hp=1;s.energy=3;host:refresh();tap('card1',220);tap('enemy3',221);drain()
assert(host.run.phase=='reward'and host.run.victories==1)
for _,actor in ipairs(s.enemies)do assert(actor.isDying and not A.isPresent(actor));assert(ui.feedback.deaths[actor.id],'all source die transitions must collapse')end
assert(root:GetChild('battlePanel').visible)
print('DARKLINGS_UI_PASS generated-five-slots/Chinese-regrow-reincarnate/zero-HP/invalid-target/no-premature-collapse/all-final-collapse/reward-once')
