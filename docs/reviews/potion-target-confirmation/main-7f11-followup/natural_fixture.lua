package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,Combat=require('abyss_run'),require('abyss_combat')
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function setup(pointer)
  local run=Run.new(F.Data,4)
  assert(Run.startCombat(run,'cultist_solo'))
  for _=1,160 do
    if run.phase~='combat' then break end
    local uid
    for _,card in ipairs(run.combat.hand) do
      if Combat.canPlay(run.combat,card.uid,1) then
        uid=card.uid
        if Combat.cardDefinition(run.combat,card).type=='attack' then break end
      end
    end
    if uid then assert(Run.play(run,uid,1)) else assert(Run.endTurn(run)) end
  end
  eq(run.phase,'reward');eq(run.rewards.potion.id,'fire_potion')
  assert(Run.claimPotionReward(run));assert(Run.claimCardReward(run,0))
  dofile('tests/lua/support/finish_combat_rewards.lua')(run)
  eq(run.phase,'map');assert(Run.startCombat(run,'small_slimes'))
  eq(#run.combat.enemies,2)
  local cursor=pointer and {CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag',CursorEnter='enter',CursorExit='exit'} or nil
  local h,r=F.fixture(nil,nil,nil,cursor);h.run=run;h.battleUI.run=run;h.nodeUI.run=run
  h:resize(1280,720);h:refresh()
  local u,p=h.battleUI,r:GetChild('battlePanel')
  local function emit(name,kind,touch)
    local box=p:GetChild(name);local hit=box.listeners and box or box:GetChild('hit')
    local fn=hit.listeners and hit.listeners[kind]
    if fn then return fn({touchId=touch}) end
  end
  local function drain()for _=1,400 do if not u.busy then return end h:update(.05) end error('busy') end
  local function click(name)local result=emit(name,'click');drain();return result end
  local function tap(name,id)emit(name,'down',id);emit(name,'up',id);emit(name,'click',id);drain()end
  return h,u,p,r,emit,click,tap,drain
end
-- Real generated full-game UI and real rules. This harness is not platform input evidence.
local function untouched(h,hp1,hp2)
  eq(Run.potionCount(h.run),1);eq(h.run.combat.enemies[1].hp,hp1);eq(h.run.combat.enemies[2].hp,hp2)
end
local function suite(label)
  local passed,failed=0,0
  local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
  end
  local function finish()
    print(label..' '..passed..' passed; '..failed..' failed');assert(failed==0)
  end
  return test,finish
end
return {setup=setup,Run=Run,Combat=Combat,F=F,eq=eq,untouched=untouched,suite=suite}
