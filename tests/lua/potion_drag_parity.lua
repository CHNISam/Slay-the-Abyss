local H=dofile('tests/lua/support/battle_gesture_fixture.lua')
local Surfaces=require('abyss_monster_surfaces')
local function actorBox(panel,battle,index)
    local box,slot,entry=Surfaces.get(panel):find(assert(battle.enemies[index]).id)
    assert(box,'actor surface missing')
    return box,slot,entry
end
local function sourceSetup(...)
    local host,ui,panel,event,tap,drain,openClose,root=H.setup(...)
    -- Deliberately synthetic encounter constructor offsets, not MonsterHelper
    -- formation or count-dependent production spacing. Distinguish two targets.
    local actors=host.run.combat.enemies
    if #actors==2 then
        actors[1].sourcePosition={x=-240,y=0}
        actors[2].sourcePosition={x=80,y=0}
        host:refresh()
    end
    return host,ui,panel,event,tap,drain,openClose,root
end
local first,last=...;first,last=first or 1,last or 2
local Run,Combat=H.Run,H.F.Combat
local passed,failed,registered=0,0,0
local function test(name,fn)registered=registered+1;if registered<first or registered>last then return end;local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function same(a,b,seen)
 if a==b then return end;assert(type(a)==type(b),'preview changed rule value type')
 if type(a)~='table'then assert(a==b,'preview changed rule value');return end
 seen=seen or {};if seen[a]then assert(seen[a]==b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil,'preview added rule state')end
end
local function setup(id)
 local h,u,p,event,tap,drain=sourceSetup({'defend','defend'},{'cultist','jaw_worm'})
 assert(Run.obtainPotion(h.run,id or 'fire_potion'));h:refresh()
 local function emit(name,kind,touch,x,y)
  local index=name:match('^enemy(%d+)$')
  local c=index and actorBox(p,h.run.combat,tonumber(index))or p:GetChild(name)or p:GetChild('potionHelp'):GetChild(name)
  local hit=c.listeners and c or c:GetChild('hit');local fn=hit.listeners and hit.listeners[kind]
  assert(fn,name..'/'..kind..' listener missing')
  return fn({touchId=touch,GetUIPos=function()return 640+(x or c.x or 0),360+(y or c.y or 0)end})
 end
 local function target(slot)local enemy=actorBox(p,h.run.combat,slot);return enemy.x,enemy.y end
 local function start(control,touch,slot)
  local c=p:GetChild(control)or p:GetChild('potionHelp'):GetChild(control)
  emit(control,'down',touch,c.x,c.y);local x,y=target(slot or 2);emit(control,'drag',touch,x,y)
  return x,y
 end
 return h,u,p,emit,target,start,drain
end
test('target potion drag uses shared aim and pure target-only HP preview then commits once',function()
 local h,u,p,e,pos,start,drain=setup();local b=h.run.combat;local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp
 local energy,events,inventory=b.energy,#b.events,h.run.potions
 local before=Combat.copy(h.run,{[h.run.data]=h.run.data})
 local x,y=start('potion1',7,2)
 assert(u.potionAim and u.potionAim.moving and p:GetChild('dragLayer').visible)
 assert(p:GetChild('dragLayer'):GetChild('aim1').visible)
 assert(actorBox(p,h.run.combat,2):GetChild('damagePreview').text=='−20')
 assert(not actorBox(p,h.run.combat,1):GetChild('damagePreview').visible)
 assert(not actorBox(p,h.run.combat,1):GetChild('targetH-1_-1').visible)
 same(before,h.run)
 assert(u.potionAim.x==(640+x)-640 and u.potionAim.y==(360+y)-360,'shared aim endpoint must retain the actual native pointer')
 assert(b.enemies[1].hp==hp1 and b.enemies[2].hp==hp2 and b.energy==energy and #b.events==events and h.run.potions==inventory)
 e('dragLayer','up',7,x,y);drain();assert(h.run.potions[1]==nil and b.enemies[2].hp==hp2-20 and b.enemies[1].hp==hp1)
 e('potion1','endDrag',7,x,y);e('potion1','click',7,x,y);assert(b.enemies[2].hp==hp2-20 and not u.potionAim and not p:GetChild('dragLayer').visible)
end)
test('description-button drag never arms or uses a potion and retains click and hold details',function()
 local h,u,p,e,pos,start,drain=setup();local x,y=start('potionHelp1',4,2)
 local b=h.run.combat;local hp1,hp2=b.enemies[1].hp,b.enemies[2].hp;local inventory=h.run.potions
 e('potionHelp1','up',4,x,y);drain()
 assert(h.run.potions==inventory and h.run.potions[1]=='fire_potion'and b.enemies[1].hp==hp1 and b.enemies[2].hp==hp2,
  'description-button Down/Drag/Up must preserve the bottle and both enemies HP')
 assert(not u.potionAim and not p:GetChild('dragLayer').visible)
 e('potionHelp1','click',4,x,y);assert(p:GetChild('statusInfo').visible,'effect description must remain reachable')
 local h2,u2,p2,e2=setup();e2('potionHelp1','down',5);e2('potionHelp1','up',5);e2('potionHelp1','click',5)
 assert(p2:GetChild('statusInfo').visible and not u2.potionAim and h2.run.potions[1]=='fire_potion')
 local h3,u3,p3,e3,pos3=setup();e3('potionHelp1','down',6);h3:update(.4)
 local tx,ty=pos3(2);e3('potionHelp1','drag',6,tx,ty);e3('potionHelp1','up',6,tx,ty);e3('potionHelp1','click',6,tx,ty)
 assert(p3:GetChild('statusInfo').visible and not u3.potionAim and h3.run.potions[1]=='fire_potion','fired long press must retain detail ownership')
end)
test('ground hand and off-canvas release cancel without using or leaving a carried bottle',function()
 for _,point in ipairs({{0,0},{0,-280},{900,20},{0/0,20}})do
  local h,u,p,e,pos,start=setup();start('potion1',7,2)
  e('dragLayer','drag',7,point[1],point[2]);e('dragLayer','up',7,point[1],point[2]);e('potion1','click',7)
  assert(h.run.potions[1]=='fire_potion'and not u.potionAim and not p:GetChild('dragLayer').visible)
 end
 local h,u,p,e,pos,start=setup();start('potion1',7,2)
 p:GetChild('dragLayer'):GetChild('hit').listeners.up({touchId=7})
 assert(h.run.potions[1]=='fire_potion'and not u.potionAim)
end)
test('wrong touch cannot redirect or release another touch potion drag',function()
 local h,u,p,e,pos,start,drain=setup();local b=h.run.combat;local hp=b.enemies[2].hp;local x,y=start('potion1',7,2)
 e('potion1','down',8,0,0)
 e('dragLayer','drag',8,0,0);e('dragLayer','up',8,0,0);assert(h.run.potions[1]=='fire_potion'and u.potionAim)
 e('dragLayer','up',7,x,y);drain();assert(h.run.potions[1]==nil and b.enemies[2].hp==hp-20)
end)
test('turn battle and inventory replacement retire old drag releases',function()
 for _,change in ipairs({'turn','battle','inventory','resize','inactive'})do
  local h,u,p,e,pos,start=setup();local x,y=start('potion1',7,2)
  if change=='turn'then h.run.combat.turn=h.run.combat.turn+1
  elseif change=='battle'then h.run.combat=Combat.new(H.F.Data,{deck={'defend'},enemies={'cultist','jaw_worm'}})
  elseif change=='inventory'then h.run.potions=Combat.copy(h.run.potions)
  elseif change=='resize'then u:resize(1600,900)
  else u:setActive(false)end
  u:render();e('dragLayer','up',7,x,y);assert(h.run.potions[1]=='fire_potion'and not u.potionAim)
 end
end)
test('poison aim previews no immediate HP loss and does not apply poison before release',function()
 local h,u,p,e,pos,start,drain=setup('poison_potion');local b=h.run.combat;local hp=b.enemies[2].hp
 local x,y=start('potion1',7,2);assert(not actorBox(p,h.run.combat,2):GetChild('damagePreview').visible)
 assert((b.enemies[2].statuses.poison or 0)==0 and b.enemies[2].hp==hp)
 e('dragLayer','up',7,x,y);drain();assert(b.enemies[2].statuses.poison==6 and b.enemies[2].hp==hp and h.run.potions[1]==nil)
end)
test('click-only target selection remains an explicit alternate input',function()
 local h,u,p,e,pos,start,drain=setup();local hp=h.run.combat.enemies[2].hp
 e('potion1','down',9);e('potion1','up',9);e('potion1','click',9)
 assert(u.potionMenu and not u.potionAim and h.run.potions[1]=='fire_potion' and h.run.combat.enemies[2].hp==hp)
 local use=p:GetChild('potionHelp'):GetChild('potionPopup'):GetChild('use')
 for _,kind in ipairs({'down','up','click'})do use.listeners[kind]({touchId=11})end
 assert(not u.potionMenu and u.potionAim and not u.potionAim.moving)
 e('enemy2','down',10);e('enemy2','up',10);e('enemy2','click',10);drain()
 assert(h.run.potions[1]==nil and h.run.combat.enemies[2].hp==hp-20)
end)
assert(failed==0,tostring(failed)..' potion drag regressions failed')
assert(registered==7 and passed==last-first+1,'all selected potion cases must execute')
print('POTION_DRAG_PARITY_PASS '..passed)
