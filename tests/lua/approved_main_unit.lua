local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local EnemyView=require('abyss_battle_enemy_view')
local Powers=require('abyss_monster_power_surfaces')
local Theme=require('abyss_theme')
local host,ui,panel=H.setup({'defend'},{'cultist','red_louse','green_louse','jaw_worm','sentry'})
local battle=host.run.combat
local function near(a,b,message)assert(math.abs(a-b)<1e-8,message..': '..tostring(a)..' ~= '..tostring(b))end
local surfaces=assert(require('abyss_monster_surfaces').get(panel))
local function enemy(slot)return assert(surfaces:find(battle.enemies[slot].id))end
local constructors={{0,-10,230,240},{0,0,180,140},{0,0,180,140},{0,25,260,170},{0,0,180,310}}
for slot,source in ipairs(constructors)do
 local portrait=math.max(source[3],source[4])/1.5
 local x=(1440+source[1])/1.5-640
 local y=(require('abyss_battle_enemy_view').floorY+source[2])/1.5-360+portrait/2
 local box=enemy(slot)
 near(box.x,x,'original constructor drawX')
 near(box.y,y,'original constructor drawY plus fixed new-art bounds')
 near(box:GetChild('portrait').sizeDeltaX,portrait,'fixed silhouette bounds')
 assert(not box:GetChild('plate').visible and not box:GetChild('border').visible)
 local px,_,size,_,py=EnemyView.position(5,slot,battle.enemies[slot])
 near(px,x,'target center x');near(py,y,'target center y');near(size,portrait,'fixed art size')
end
local hero=panel:GetChild('hero')
near(hero.x,430/1.5-640,'hero source center x');near(hero.y,360-425/1.5,'hero source center y')
near(hero:GetChild('portrait').sizeDeltaX,200/1.5,'hero source silhouette')
assert(not hero:GetChild('plate').visible and not hero:GetChild('border').visible)
local first=enemy(1)
-- Cultist source: hbX=-8, hbY=10, width=230, height=240.
near(first:GetChild('intentIcon').x,-8/1.5,'intent follows source hitbox center')
-- Native full-bleed glyph and horizontal damage clear both square art and source hitbox.
-- Original constructor, help width, HP anchors and ordered source powers stay below.
local glyph=math.min(128/1.5,Theme.layout.intent.size)
local nativeTop=math.max(240/3,(10+240)/1.5-240/3)
local intentY=nativeTop+math.max(Theme.layout.nativeText.lineHeight,Theme.layout.intent.size)/2+Theme.space.xs
near(first:GetChild('intentIcon').y,intentY,'native intent anchor clears full art')
near(first:GetChild('intentIcon').sizeDeltaX,glyph,'readable intent glyph size')
assert(first:GetChild('intentIcon').y-glyph/2>=nativeTop+Theme.space.xs-1e-8,'full glyph body clearance')
near(first:GetChild('intentHit').sizeDeltaX,64/1.5,'source intent hitbox size')
near(first:GetChild('hpFill').y,(10-18)/1.5-240/3,'source health anchor below hitbox')
near(first:GetChild('hpFill').sizeDeltaY,20/1.5,'source health bar height')
near(first:GetChild('hpFill').x,-8/1.5,'health bar follows source hitbox center')
near(first:GetChild('hpFill').sizeDeltaX,230/1.5,'enemy source health width')
near(hero:GetChild('hpFill').sizeDeltaX,220/1.5,'hero source health width')
local function normalCount(n)
 battle.enemies[1].statuses={strength=2,weak=1,vulnerable=1,regen=2,thorns=2,artifact=1,metallicize=1,plated_armor=2,poison=1,ritual=1}
 -- Explicit synthetic acquisition history, not alphabetical map iteration.
 battle.enemies[1].powerOrder={'strength','weak','vulnerable','regen','thorns','artifact','metallicize','plated_armor','poison','ritual'}
 if n==1 then battle.enemies[1].statuses={strength=2};battle.enemies[1].powerOrder={'strength'} end
 ui:render()
 return enemy(1):GetChild('statusRow')
end
local row=normalCount(1)
local chip=assert(Powers.get(row):find('strength'))
near(chip:GetChild('icon').sizeDeltaX,48/1.5,'source status icon size')
near(chip.x,(-8-230/2+10)/1.5,'source power row starts at health left plus ten')
-- Full-bleed status images need explicit HP clearance, not source atlas padding.
local powerY=(10-18)/1.5-240/3-math.max(20/1.5,Theme.font.small)/2-Theme.space.s-(48/1.5)/2
near(chip.y,powerY,'native power row below full HP bar')
assert(chip.y+chip:GetChild('icon').sizeDeltaY/2<=first:GetChild('hpFill').y-first:GetChild('hpFill').sizeDeltaY/2-Theme.space.s+1e-8,'power never covers HP')
print('APPROVED_MAIN_UNIT_PASS')
-- Status overflow cannot move the original creature coordinates.
local beforeY=first.y
row=normalCount(10)
local x,_,portrait,_,y=EnemyView.position(5,1,battle.enemies[1])
near(y,beforeY,'statuses must not reflow original source position')
assert(first.x==x and first.y==beforeY)
local powerCount=0
Powers.get(row):each(function(box,slot,entry)
 powerCount=powerCount+1
 near(box.x,(-8-230/2+10+(powerCount-1)*48)/1.5,'source ordered single power row')
 near(box.y,powerY,'powers never wrap')
 assert(box:GetChild('count').sizeDeltaY==40,'retain native transparent text box')
 assert(entry.id==battle.enemies[1].powerOrder[powerCount],'power acquisition order changed')
end)
assert(powerCount==10,'every power has an independent native control')
row=normalCount(1);near(first.y,beforeY,'status clearing must not move instance')
local boss=H.F.Combat.new(H.F.Data,{enemies={'guardian'}}).enemies[1]
local bx,_,bossPortrait,_,bossY=EnemyView.position(1,1,boss)
near(bx,(1440-50)/1.5-640,'Guardian constructor x')
near(bossPortrait,440/1.5,'Guardian fixed new-art box follows original hitbox bounds')
near(bossY,(EnemyView.floorY-100)/1.5-360+bossPortrait/2,'Guardian constructor y never notice-lifted')
battle.enemies[1].statuses={strength=-123,dexterity=123}
battle.enemies[1].powerOrder={'strength','dexterity'}
ui:render()
row=first:GetChild('statusRow')
local found={}
Powers.get(row):each(function(box)
 local c=box:GetChild('count')
 assert(c.visible,'signed Strength/Dexterity counts must be visible')
 found[c.text]=true
 assert(c.sizeDeltaX>=utf8.len(c.text)*14*.6,'native count box must fit all digits without font shrinking')
end)
assert(found['123'] and found['-123'] and not found['99+'],'source amounts retain full signed integers')
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

-- Explicit repeated-definition fixtures must not invent count-dependent spacing/scale.
for count=1,4 do
 local members={};for i=1,count do members[i]='cultist'end
 local short=H.F.Combat.new(H.F.Data,{deck={'defend'},enemies=members})
 host.run.combat=short
 for _,actor in ipairs(short.enemies)do actor.statuses={strength=2};actor.powerOrder={'strength'}end
 ui:render()
 local positions={}
 for slot,actor in ipairs(short.enemies)do
  local box=assert(surfaces:find(actor.id));positions[slot]={box.x,box.y}
  near(box.x,320,'cultist original default x');near(box.y,(EnemyView.floorY-10)/1.5-360+240/3,'cultist original default y')
  actor.statuses={};actor.powerOrder={}
 end
 ui:render()
 for slot,actor in ipairs(short.enemies)do
  local box=assert(surfaces:find(actor.id));near(box.x,positions[slot][1],'status clearing x');near(box.y,positions[slot][2],'status clearing y')
 end
end
print('APPROVED_MAIN_ORDINARY_CLEARANCE_PASS fixed source1..4')
