local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local Layout=require('abyss_battle_reward_layout')
local draw=Layout.render
local targets,buttons,calls={},{},0
local function watch(c)
 if targets[c]then return end
 targets[c]=true
 local setter=c.SetSizeDelta
 c.SetSizeDelta=function(self,...)calls=calls+1;return setter(self,...)end
end
Layout.render=function(frame,child,...)
 local box=child('rewardList')
 for _,name in ipairs({'goldReward','stolenGold','relicReward1','relicReward2','emeraldKeyReward','claimPotion','cardReward','continue','skip'})do buttons[child(name)]=true end
 for _,c in ipairs({box,box:GetChild('border'),box:GetChild('plate'),box:GetChild('title'),box:GetChild('subtitle'),(child('potionReward'))})do watch(c)end
 return draw(frame,child,...)
end
local h,root=F.fixture();assert(F.start(h));assert(Run.startCombat(h.run,'cultist_solo'));h:refresh()
local u=h.battleUI
local function preserveGraph(value)
 local saved={}
 local function remember(v)
  if type(v)~='table' or saved[v]then return end
  local copy={};saved[v]=copy
  for k,item in pairs(v)do copy[k]=item;remember(k);remember(item)end
 end
 remember(value)
 return function()
  for original,copy in pairs(saved)do
   for k,v in pairs(original)do assert(copy[k]==v,'run/RNG graph changed')end
   for k,v in pairs(copy)do assert(original[k]==v,'run/RNG graph entry removed')end
  end
 end
end
local function preserveControls()
 local saved={}
 local keys={'x','y','sizeDeltaX','sizeDeltaY','visible','raycastTarget','interactable','text','click','parent','kind'}
 local function capture(c)
  local values={};for _,k in ipairs(keys)do values[k]=c[k]end
  saved[c]=values
 end
 for c in pairs(targets)do capture(c)end
 for c in pairs(buttons)do capture(c)end
 return function()
  for c,values in pairs(saved)do
   for _,k in ipairs(keys)do assert(c[k]==values[k],'layout/control contract changed: '..k)end
  end
 end
end

local runUnchanged,controlsUnchanged=preserveGraph(h.run),preserveControls()
local before=calls
for _=1,3 do u:render(true)end
local hidden=calls-before
runUnchanged();controlsUnchanged()
print('REWARD_SIZE_HOST hidden repeated renders=3 writes='..hidden)
-- Real reward generation and native button handler open the card picker.
for _,enemy in ipairs(h.run.combat.enemies)do enemy.hp=0 end
assert(Run.finishCombat(h.run));h:refresh()
local panel=root:GetChild('battlePanel');local stage=panel:GetChild('stage')or panel
local button=stage:GetChild('cardReward')
assert(button.visible and button.interactable and button.click)
assert(button.click()~=false);assert(u.rewardScreen=='cards' and u.rewardView)
runUnchanged=preserveGraph(h.run);controlsUnchanged=preserveControls()
local animation=u.rewardView.cards[1].rise
before=calls;u:update(1/60)
local animated=calls-before
assert(u.rewardView.cards[1].rise~=animation,'actual reward entrance must continue animating')
runUnchanged();controlsUnchanged()
print('REWARD_SIZE_HOST actual reward animation update=1 writes='..animated)
assert(hidden==0 and animated==0,'stable reward dimensions were redundantly submitted by real Host')
print('REWARD_SIZE_HOST_PASS')
