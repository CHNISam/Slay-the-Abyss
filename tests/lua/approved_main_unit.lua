local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local EnemyView=require('abyss_battle_enemy_view')
local host,ui,panel=H.setup({'defend'},{'cultist','red_louse','green_louse','jaw_worm','sentry'})
local battle=host.run.combat
local function near(a,b,message)assert(math.abs(a-b)<1e-8,message..': '..tostring(a)..' ~= '..tostring(b))end
for slot=1,5 do
 local front=slot%2==1
 local portrait=(front and 185 or 159)/1.5
 local x=(1010+168*(slot-.5))/1.5-640
 local y=360-((front and 300 or 180)+58+16+portrait*1.5/2)/1.5
 local box=panel:GetChild('enemy'..slot)
 near(box.x,x,'Main exact slot x')
 near(box.y,y,'Main exact normal row y')
 near(box:GetChild('portrait').sizeDeltaX,portrait,'Main silhouette size')
 assert(not box:GetChild('plate').visible and not box:GetChild('border').visible,'Main has no portrait box')
 local px,_,size,_,py=EnemyView.position(5,slot,battle.enemies[slot])
 near(px,x,'target center x');near(py,y,'target center y');near(size,portrait,'target silhouette size')
end
local hero=panel:GetChild('hero')
near(hero.x,430/1.5-640,'hero source center x');near(hero.y,360-425/1.5,'hero source center y')
near(hero:GetChild('portrait').sizeDeltaX,200/1.5,'hero source silhouette')
assert(not hero:GetChild('plate').visible and not hero:GetChild('border').visible)
local first=panel:GetChild('enemy1')
near(first:GetChild('intentIcon').y,185/3+(16+29)/1.5,'intent follows source head gap')
near(first:GetChild('hpFill').x,0,'health bar remains centered with reserved external Block')
near(first:GetChild('hpFill').sizeDeltaX,160/1.5,'enemy source health width')
near(hero:GetChild('hpFill').sizeDeltaX,220/1.5,'hero source health width')
local function normalCount(n)
 battle.enemies[1].statuses={strength=2,weak=1,vulnerable=1,regen=2,thorns=2,artifact=1,metallicize=1,plated_armor=2,poison=1,ritual=1}
 if n==1 then battle.enemies[1].statuses={strength=2} end
 ui:render()
 return panel:GetChild('enemy1'):GetChild('statusRow')
end
local row=normalCount(1)
near(row:GetChild('icon1').sizeDeltaX,32/1.5,'source status icon size')
near(row.y+row:GetChild('icon1').y,-185/3-(14+25.5+8+34+10+16)/1.5,'status follows HP row')
print('APPROVED_MAIN_UNIT_PASS')
-- The 40-high transparent native text boxes remain unchanged; clearance uses
-- visible 14-high digits and the actual 44-high status touch surface.
local UnitView=require('abyss_battle_unit_view')
local beforeY=first.y
row=normalCount(10)
local x,_,portrait,_,y=EnemyView.position(5,1,battle.enemies[1])
local baseY=360-(300+58+16+185/2)/1.5
local lower=row.y+row:GetChild('hit6').y-row:GetChild('hit6').sizeDeltaY/2
local bandTop=360-700/1.5
near(y,baseY+math.max(0,bandTop-(baseY+lower)),'only minimum necessary full-two-row lift')
assert(y>beforeY and first.x==x,'crowd clearance changes only y')
near(first.y+lower,bandTop,'boundary is exact, not arbitrary extra offset')
assert(row:GetChild('count1').sizeDeltaY==40,'retain native transparent text box')
row=normalCount(1);near(first.y,beforeY,'returns to source when crowd status clears')
local boss=H.F.Combat.new(H.F.Data,{enemies={'guardian'}}).enemies[1]
local _,_,bossPortrait,_,bossY=EnemyView.position(1,1,boss)
local sourceBossY=360-(300+58+16+260/2)/1.5
local lift,lowerBound,top=UnitView.noticeLift(boss,bossPortrait,sourceBossY,false)
assert(lift>0,'actual Boss feet/status touch extends into Main operation strip')
near(bossY,sourceBossY+lift,'Boss targets use same minimal clearance')
near(sourceBossY+lowerBound+lift,top,'Boss exact required difference')
battle.enemies[1].statuses={strength=-123,dexterity=123}
ui:render()
row=first:GetChild('statusRow')
local found={}
for i=1,10 do
 local c=row:GetChild('count'..i)
 if c.visible then
  found[c.text]=true
  local glyphs=utf8.len(c.text)
  assert(c.sizeDeltaX>=glyphs*14*.6,'native count box must fit all digits without font shrinking')
 end
end
assert(found['99+'] and found['−123'],'clamp positive large count and retain signed negative value')
local before=H.F.Combat.copy(battle)
ui:render();ui:render()
local function same(a,b)
 assert(type(a)==type(b),'render changed state type')
 if type(a)~='table'then assert(a==b,'render changed state');return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'render added state')end
end
same(before,battle)
print('APPROVED_MAIN_CLEARANCE_PASS')

-- Even one status uses a real 44-high target. One through four actors must
-- move only by the exact overlap and return to source when that status clears.
for count=1,4 do
 local members={};for i=1,count do members[i]='cultist'end
 local short=H.F.Combat.new(H.F.Data,{deck={'defend'},enemies=members})
 host.run.combat=short
 for _,actor in ipairs(short.enemies)do actor.statuses={strength=2}end
 ui:render()
 for slot,actor in ipairs(short.enemies)do
  local box=panel:GetChild('enemy'..slot)
  local status=box:GetChild('statusRow');local touch=status:GetChild('hit1')
  local rowTop=slot%2==1 and 300 or 180
  local portrait=box:GetChild('portrait').sizeDeltaY
  local base=360-(rowTop+58+16+portrait*1.5/2)/1.5
  local lower=status.y+touch.y-touch.sizeDeltaY/2
  near(box.y,base+math.max(0,bandTop-base-lower),'ordinary single-row exact lift '..count..'/'..slot)
  assert(box.y+lower>=bandTop-1e-8,'ordinary single-row touch cannot enter short strip')
  actor.statuses={}
 end
 ui:render()
 for slot,actor in ipairs(short.enemies)do
  local box=panel:GetChild('enemy'..slot);local portrait=box:GetChild('portrait').sizeDeltaY
  near(box.y,360-((slot%2==1 and 300 or 180)+58+16+portrait*1.5/2)/1.5,'ordinary clear restores source')
 end
end
print('APPROVED_MAIN_ORDINARY_CLEARANCE_PASS 1..4')
