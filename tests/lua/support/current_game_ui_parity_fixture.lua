-- Current production GameUI, generated layout/templates and real actor manager.
-- Explicitly disable artwork painting, not native actor allocation or core logic.
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run=require('abyss_run')
local M={F=F,Run=Run}
local function difference(a,b,seen)
 if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do
  -- Scalar fields dominate full-state traces. Compare each directly instead
  -- of paying a recursive Lua call; tables still traverse every field.
  local other=b[k];local kind=type(v)
  local mismatch
  if kind~=type(other)then mismatch=' type mismatch'
  elseif kind=='table'then mismatch=difference(v,other,seen)
  elseif v~=other then mismatch=': '..tostring(v)..' ~= '..tostring(other)end
  if mismatch then return '.'..tostring(k)..mismatch end
 end
 for k in pairs(b)do if a[k]==nil then return '.'..tostring(k)..' missing' end end
end
function M.same(a,b,path)
 local kind=type(a);local mismatch
 if kind~=type(b)then mismatch=' type mismatch'
 elseif kind=='table'then mismatch=difference(a,b,{})
 elseif a~=b then mismatch=': '..tostring(a)..' ~= '..tostring(b)end
 if mismatch then error((path or 'state')..mismatch)end
end
-- Initial independent-graph guard: even RNG limb tables and nested actor state
-- must not be shared with the direct oracle. This is not an equality cache.
function M.detached(a,b,seen)
 if type(a)~='table'then return end
 assert(type(b)=='table' and not rawequal(a,b),'UI and oracle share a state table')
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do if type(v)=='table'then M.detached(v,b[k],seen)end end
end
function M.setup(seed,controlled,sound)
 local canvas=F.control({children=F.Layout});local root=F.Viewport.apply(canvas,1280,720)
 local host=F.GameUI.new(root,F.Data,F.Presentation,'click',{seed=seed,nativeMonsterArtEnabled=false,sound=sound,
  imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end})
 root.ui=host;assert(F.start(host));assert(Run.startCombat(host.run,'cultist_solo'))
 if controlled then host.run.combat=F.Combat.new(F.Data,{deck={'strike','defend'},enemies={'cultist'},seed=seed})end
 host:refresh()
 local panel=root:GetChild('battlePanel')
 local surfaces=assert(require('abyss_monster_surfaces').get(panel))
 for _,enemy in ipairs(host.run.combat.enemies)do
  local box=assert(surfaces:find(enemy.id));assert(box:GetChild('intentVfxBehind') and box:GetChild('intentVfxAfter'))
  local ok,art=pcall(box.GetChild,box,'monsterArt')
  assert(not ok or not art or not art.visible,'artOFF must use the explicit production option')
 end
 return host,panel,surfaces
end
function M.click(panel,name)
 local box=assert(panel:GetChild(name));local hit=box.click and box or assert(box:GetChild('hit'))
 assert(hit.raycastTarget~=false and (hit.kind~='presetButton' or hit.interactable~=false))
 return assert(hit.click)()
end
function M.play(host,panel,surfaces,slot,target)
 local battle=host.run.combat;local uid=battle.hand[slot].uid
 M.click(panel,'card'..slot);assert(host.battleUI.selected==uid)
 local _,reason=F.Combat.canPlay(battle,uid,nil)
 if reason=='invalid_target' then
  local box=assert(surfaces:find(battle.enemies[target or 1].id));assert(box:GetChild('hit').raycastTarget~=false)
  box:GetChild('hit').click()
 else M.click(panel,'playArea')end
end
-- GameUI owns run wall-clock accounting; direct Run commands have no update API.
-- Advance the oracle by the input dt, never copy elapsedSeconds from the UI.
function M.tick(host,expected,dt)
 if expected and expected.phase~='defeat' and expected.phase~='victory' then
  expected.elapsedSeconds=expected.elapsedSeconds+dt
 end
 host:update(dt)
end
function M.drain(host,expected)
 for _=1,400 do if not host.battleUI.busy then return end;M.tick(host,expected,.05)end
 error('current GameUI playback did not release input')
end
function M.clear(events)for i=#events,1,-1 do events[i]=nil end end
return M
