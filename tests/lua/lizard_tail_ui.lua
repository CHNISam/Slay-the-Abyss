local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/?.lua;'..package.path
local F=require('support.game_ui_fixture')
local Run,C,Tail=require('abyss_run'),require('abyss_combat'),require('abyss_lizard_tail')
local passed,failed=0,0
local function same(a,b)
 assert(type(a)==type(b),'type changed')
 if type(a)~='table'then assert(a==b,'value changed');return end
 for k,v in pairs(a)do same(v,b[k])end
 for k in pairs(b)do assert(a[k]~=nil,'field added')end
end
local function setup(owned,mark)
 local ui,root=F.fixture();assert(testStart(ui))
 if owned then assert(Run.obtainRelic(ui.run,'Lizard Tail'))end
 if mark then assert(Run.obtainRelic(ui.run,'Mark of the Bloom'))end
 assert(Run.startCombat(ui.run,'cultist_solo'));ui:refresh()
 return ui,root,ui.run.combat
end
local function hero(ui,root)
 local hit=root:GetChild('battlePanel'):GetChild('hero'):GetChild('hit')
 assert(hit.kind=='cursorArea' and hit.raycastTarget~=false)
 local box=hit
 while box do assert(box.visible~=false and box.activeInHierarchy~=false,'hero detail surface hidden');box=box.parent end
 hit.click();assert(ui.battleUI.info and root:GetChild('battlePanel'):GetChild('statusInfo').visible)
end
local function read(ui,root)
 local panel=root:GetChild('battlePanel'):GetChild('statusInfo');local rows,labels={},{}
 local pages=assert(ui.battleUI.info.pages)
 for page=1,pages do
  for i=1,F.Theme.layout.statusInfo.sections do
   local label=panel:GetChild('section'..i);if label.visible then labels[#labels+1]=label.text end
  end
  for i=1,F.Theme.layout.statusInfo.rows do
   local name,text=panel:GetChild('name'..i),panel:GetChild('text'..i)
   if name.visible then rows[#rows+1]=name.text..'\n'..text.text end
  end
  if page<pages then panel:GetChild('page').click()end
 end
 return table.concat(rows,'\n'),table.concat(labels,'\n')
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print('PASS Tail UI '..name)else failed=failed+1;print('FAIL Tail UI '..name..': '..tostring(err))end
end
-- Battle portrait details only. Noncombat owned relics have no detail entry yet.
test('actual obtain and battle binding expose available without a fake Power or mutation',function()
 local ui,root,s=setup(true,false);assert(Tail.state(s)=='available')
 local before=C.copy(ui.run);local counters=s.relicCounters
 hero(ui,root);local text,labels=read(ui,root)
 assert(labels:find('遗物',1,true) and text:find('蜥蜴尾巴 · 可用',1,true),'available Tail row missing')
 assert(text:find('仙灵药水优先',1,true))
 assert(s.player.statuses.lizard_tail==nil and s.relicCounters==counters);same(ui.run,before)
 root:GetChild('battlePanel'):GetChild('statusInfo'):GetChild('hit').click();assert(not ui.battleUI.info);same(ui.run,before)
end)
test('a real fatal reserve displays spent from live battle while persistent Run still says available',function()
 local ui,root,s=setup(true,false);s.player.hp=1
 C.damage(s,s.enemies[1],s.player,999,true)
 assert(s.player.hp>0 and Tail.state(s)=='spent' and ui.run.relicCounters.lizard_tail==-1)
 local before=C.copy(ui.run);hero(ui,root);local text=read(ui,root)
 assert(text:find('蜥蜴尾巴 · 本局已用',1,true),'spent Tail row missing')
 same(ui.run,before)
end)
test('actual Mark ownership exposes the block without spending the reserve',function()
 local ui,root,s=setup(true,true);assert(Tail.state(s)=='blocked_by_mark' and s.relicCounters.lizard_tail==-1)
 local before=C.copy(ui.run);hero(ui,root);local text=read(ui,root)
 assert(text:find('蜥蜴尾巴 · 绽放印记阻断',1,true),'Mark block row missing')
 assert(text:find('使用机会',1,true));same(ui.run,before)
end)
test('absent Tail enemy details and a selected Power keep their own content',function()
 local ui,root,s=setup(false,false);local before=C.copy(ui.run)
 hero(ui,root);local text,labels=read(ui,root);assert(not text:find('蜥蜴尾巴',1,true) and not labels:find('遗物',1,true));same(ui.run,before)
 local other,otherRoot,battle=setup(true,false)
 assert(other.battleUI:showStatus(1));text,labels=read(other,otherRoot)
 assert(not text:find('蜥蜴尾巴',1,true) and not labels:find('遗物',1,true))
 C.addStatus(battle.player,'strength',2)
 assert(other.battleUI:openHelp({index=0,statusId='strength'},nil,false));text,labels=read(other,otherRoot)
 assert(not text:find('蜥蜴尾巴',1,true) and not labels:find('遗物',1,true))
end)
test('the existing pager keeps the relic and real Powers reachable without changing resources',function()
 local ui,root,s=setup(true,false)
 for _,id in ipairs({'strength','dexterity','weak','vulnerable','frail','artifact','thorns','regen'})do C.addStatus(s.player,id,2)end
 local before=C.copy(ui.run);hero(ui,root);assert(ui.battleUI.info.pages>1)
 local text,labels=read(ui,root)
 assert(text:find('蜥蜴尾巴 · 可用',1,true) and labels:find('遗物',1,true),'Tail missing across pages')
 assert(text:find('力量',1,true) and text:find('易伤',1,true));same(ui.run,before)
end)
test('missing and invalid owned counters remain errors and are never initialized by rendering',function()
 for _,kind in ipairs({'missing','invalid'})do
  local ui,root,s=setup(true,false);s.relicCounters.lizard_tail=kind=='invalid' and 0 or nil
  local before=C.copy(ui.run);local ok=pcall(hero,ui,root)
  assert(not ok,'invalid Tail counter must preserve its strict diagnostic')
  assert(s.relicCounters.lizard_tail==(kind=='invalid' and 0 or nil));same(ui.run,before)
 end
end)
assert(failed==0,tostring(failed)..' Tail battle detail groups failed')
print('LIZARD_TAIL_UI_PASS '..passed)
