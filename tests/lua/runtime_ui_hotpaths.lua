local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local host,root=F.fixture();assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'));host:refresh()
local ui,panel=host.battleUI,root:GetChild('battlePanel')
local render,renders=ui.render,0
ui.render=function(self,...)renders=renders+1;return render(self,...)end
host:refresh()
print('RUNTIME_HOST refresh battle renders='..renders)
if not ABYSS_RUNTIME_BASELINE then assert(renders==2,'GameUI refresh must preserve both observable render boundaries')end
renders=0;ui:setActive(true);assert(renders==1,'standalone activation must render')
for _=1,180 do ui:update(1/60)end
local counts={position=0,size=0,scale=0}
local watched={}
for i=1,#host.run.combat.hand do
 local box=panel:GetChild('card'..i)
 for _,control in ipairs({box,box:GetChild('hit')})do
  watched[#watched+1]=control
  for method,key in pairs({SetAnchoredPosition='position',SetSizeDelta='size',SetLocalScale='scale'})do
   local original=control[method]
   control[method]=function(self,...)counts[key]=counts[key]+1;return original(self,...)end
  end
 end
end
local saved={}
local function remember(value)
 if type(value)~='table' or saved[value]then return end
 local copy={};saved[value]=copy;for k,v in pairs(value)do copy[k]=v;remember(k);remember(v)end
end
remember(host.run)
local fields={}
for _,c in ipairs(watched)do fields[c]={x=c.x,y=c.y,sx=c.sizeDeltaX,sy=c.sizeDeltaY,scale=c.scale[1],rotation=c.localRotationZ}end
for _=1,300 do ui:update(1/60)end
print('RUNTIME_HOST settled cards='..#host.run.combat.hand..' frames=300 position='..counts.position..' size='..counts.size..' scale='..counts.scale)
for original,copy in pairs(saved)do
 for k,v in pairs(original)do assert(copy[k]==v,'stable UI mutated run/RNG')end
 for k,v in pairs(copy)do assert(original[k]==v,'stable UI removed run/RNG state')end
end
for c,v in pairs(fields)do
 assert(c.x==v.x and c.y==v.y and c.sizeDeltaX==v.sx and c.sizeDeltaY==v.sy and c.scale[1]==v.scale and c.localRotationZ==v.rotation,'stable hand geometry changed')
end
if not ABYSS_RUNTIME_BASELINE then assert(counts.position==0 and counts.size==0 and counts.scale==0,'settled card geometry resubmitted')end
-- Native visibility writes occur between activation and the final battle paint.
-- Exercise a public command at that exact boundary; a first-paint-only shortcut
-- leaves an old energy counter even though the live command has committed.
local mapPanel=root:GetChild('mapPanel')
local visible=mapPanel.SetVisible
local injected=false
mapPanel.SetVisible=function(self,value)
 local result=visible(self,value)
 if not injected then
  injected=true
  local uid
  for _,card in ipairs(host.run.combat.hand)do
   if F.Combat.canPlay(host.run.combat,card.uid,nil)then uid=card.uid;break end
  end
  assert(uid and Run.play(host.run,uid),'native reentry public command did not execute')
 end
 return result
end
host:refresh();mapPanel.SetVisible=visible
assert(injected,'native visibility injection did not execute')
assert(panel:GetChild('energy').text==require('abyss_numbers').integer(host.run.combat.energy)..'/3','GameUI final paint missed reentrant Run.play')
print('RUNTIME_HOST native visibility reentry final paint PASS')
print('RUNTIME_UI_HOTPATHS_PASS')
