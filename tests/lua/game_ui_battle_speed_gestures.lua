local F=dofile('tests/lua/support/game_ui_fixture.lua')
local cursor={CursorDown='down',CursorUp='up',CursorExit='exit',CursorEndDrag='endDrag'}
local count=0
local function test(name,fn)fn();count=count+1;print('ok speed admission '..count..' - '..name)end
local function fixture(pointer)
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{
  seed=1,originalCharacters=true,prologue=false,cursorEvents=pointer and cursor or nil,imageSource='static',
  color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
 root.ui=host
 return host,root
end
local function unchanged(h)
 assert(not h.fastMode and not h.battleUI.feedback.fastMode)
 assert(h.seed==1 and not h.run and not h.map,'speed command must not create a run or consume its seed')
end
for _,pointer in ipairs({false,true})do
 test((pointer and 'pointer' or 'click-only')..' title has no initial speed selector and defaults to normal',function()
  local h,r=fixture(pointer)
  assert(not r:GetChild('menuPanel'):GetChild('battleSpeed'))
  unchanged(h);assert(not h:setFastMode('fast'));unchanged(h)
  assert(h:setFastMode(true) and h.fastMode and h.battleUI.fastMode and h.battleUI.feedback.fastMode)
  assert(h:setFastMode(false));unchanged(h)
 end)
end
test('resize retains the program setting without introducing a title control',function()
 local h,r=fixture(true);assert(h:setFastMode(true));h:resize(1600,900)
 assert(h.fastMode and h.battleUI.feedback.fastMode and not r:GetChild('menuPanel'):GetChild('battleSpeed'))
 assert(h:setFastMode(false));unchanged(h)
end)
for _,t in ipairs({
 {name='exit',open=function(h)return h:openExit()end,close=function(h)return h:closeExit()end},
 {name='character choice',open=function(h)return h:start()end,close=function(h)return h:closeCharacters()end},
})do
 test(t.name..' modal rejects program speed changes until closed',function()
  local h=fixture(true);assert(t.open(h));assert(not h:setFastMode(true));unchanged(h)
  assert(t.close(h));assert(h:setFastMode(true));assert(h:setFastMode(false));unchanged(h)
 end)
end
test('disabled host rejects program speed commands',function()
 local h=fixture(true);assert(h:disable());assert(not h:setFastMode(true));unchanged(h)
end)
for _,phase in ipairs({'defeat','victory'})do
 test(phase..' has no title speed control and rejects program changes',function()
  local h,r=fixture(false);assert(F.start(h,'traveler'))
  -- Isolate terminal rendering; this is not an earned ending.
  h.run.phase=phase;h:refresh();assert(h.mode==phase and r:GetChild('menuPanel').visible)
  assert(not r:GetChild('menuPanel'):GetChild('battleSpeed') and not h:setFastMode(true) and not h.fastMode)
 end)
end
print('LUA_GAME_UI_BATTLE_SPEED_GESTURES_PASS '..count)
