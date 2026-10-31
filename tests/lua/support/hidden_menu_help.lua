-- Current public help entries are retired. Keep internal guide-routing tests
-- explicit: seeding this state is fixture setup, never a supported user path.
local M={}
local function same(a,b,seen)
 if a==b then return true end
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 seen=seen or {};if seen[a]then return seen[a]==b end;seen[a]=b
 for k,v in pairs(a)do if not same(v,b[k],seen)then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
function M.rejected(ui,root)
 local run,map=ui.run,ui.map
 local before=require('abyss_combat').copy({run=run,map=map},run and {[run.data]=run.data}or nil)
 local flags={}
 for _,key in ipairs({'mode','exitOpen','menuOpen','controlsOpen','routeOpen','settlementRequested','settlementBusy'})do flags[key]=ui[key]end
 local guide=root:GetChild('exitPanel'):GetChild('guide')
 local visible=guide.visible
 for _,panel in ipairs({'exitPanel','runMenu'})do
  local box=root:GetChild(panel):GetChild('help');local hit=box:GetChild('hit')
  assert(box.visible==false,panel..' help must stay hidden')
  assert(not hit.click(),panel..' hidden help must reject direct/stale click')
  if ui.controller then
   assert(not hit.canControllerFocus,panel..' help must not receive controller focus')
   local record=ui.controller.byControl[hit]
   assert(record and not record.enabled(),panel..' help command itself must be disabled')
   assert(not hit.navigationListeners.confirm(),panel..' hidden help must reject controller confirm')
  end
 end
 assert(ui.run==run and ui.map==map and same({run=run,map=map},before),'hidden help mutated run/map/RNG')
 for _,key in ipairs({'mode','exitOpen','menuOpen','controlsOpen','routeOpen','settlementRequested','settlementBusy'})do
  assert(ui[key]==flags[key],'hidden help changed '..key)
 end
 assert(guide.visible==visible,'hidden help changed guide visibility')
end
function M.internalGuideFixture(ui,root)
 assert(ui.exitOpen and not ui.controlsOpen,'internal guide fixture needs an existing exit/menu layer')
 ui.controlsOpen=true
 root:GetChild('exitPanel'):GetChild('guide'):SetVisible(true)
 ui:refresh()
 assert(ui.controlsOpen)
 if root:GetChild('mapPanel').visible then assert(not ui.mapUI.navigationEnabled)end
end
return M
