-- Native image/text replacement for AbstractCreature.renderPowerIcons' ordered row.
-- Source list membership/order stays in Actors; this module only owns native outputs.
local Combat=require('abyss_combat')
local Theme=require('abyss_theme')
local Surfaces=require('abyss_monster_power_surfaces')
local number=require('abyss_numbers').integer
local M={}
function M.new(platform,picture,tint,ink,onCreate,onRetire)
 local self={pools={},missingIcons={}}
 local function valid()assert(not self.engineDestroyed,'monster power publication cancelled')end
 local function native(control,name,...)
  valid();local value=control[name](control,...);valid();return value
 end
 local function paint(box,entry,index,g)
  local mobile=platform.touchScreen and platform.touchScreen()
  local s=g.sourceScale;local pitch=(mobile and 55 or 48)*s
  local x=g.healthX-g.hitWidth/2+(10+(index-1)*(mobile and 55 or 48))*s
  local iconSize=48*s*(mobile and 1.17 or 1)
  -- Native icons have no transparent atlas padding: keep their full rectangle below HP.
  local y=g.healthY-math.max(g.healthHeight,Theme.font.small)/2-Theme.space.s-iconSize/2
  native(box,'SetAnchoredPosition',x,y)
  for _,name in ipairs({'edge','body','badge'})do native(box,'GetChild',name):SetVisible(false)end
  local icon=native(box,'GetChild','icon');native(icon,'SetVisible',true)
  native(icon,'SetAnchoredPosition',0,0);native(icon,'SetSizeDelta',iconSize,iconSize)
  local image=Theme.icon.status[entry.icon or entry.id]
  if (not image or Theme.icon.statusReplacementNotes and Theme.icon.statusReplacementNotes[entry.id])and not self.missingIcons[entry.id]then
   self.missingIcons[entry.id]=true;print('ABYSS_POWER_ICON_MISSING '..entry.id..' using labelled unknown placeholder')
  end
  valid();picture(icon,image or Theme.icon.intent.unknown);valid()
  tint(icon,{r=255,g=255,b=255,a=255});valid()
  local amount=entry.sourceAmount or entry.amount
  local count=native(box,'GetChild','count')
  local shown=amount>0 or amount<0 and entry.canGoNegative==true
  native(count,'SetVisible',shown)
  valid();count.text=shown and number(amount)or '';valid()
  local width=math.max(40,utf8.len(count.text)*Theme.font.small)
  native(count,'SetSizeDelta',width,Theme.layout.nativeText.lineHeight)
  native(count,'SetAnchoredPosition',22*s-width/2,(mobile and -22 or -18)*s-Theme.layout.nativeText.lineHeight/2)
  local colour=amount<0 and {r=255,g=0,b=0,a=255}or entry.isTurnBased and {r=255,g=255,b=255,a=255}or {r=0,g=255,b=0,a=255}
  ink(count,colour);valid()
  local hit=native(box,'GetChild','hit');native(hit,'SetVisible',true);native(hit,'SetAnchoredPosition',0,0);native(hit,'SetSizeDelta',pitch,48*s)
  native(box,'SetVisible',true)
 end
 function self.release(_,actorBox,engineDestroyed)
  local pool=self.pools[actorBox]
  if pool then
   if engineDestroyed then pool:onEngineDestroy()else pool:clear()end;self.pools[actorBox]=nil
  end
 end
 function self.onEngineDestroy(_)
  self.engineDestroyed=true
  local pools=self.pools;self.pools={}
  local failure
  for _,pool in pairs(pools)do local ok,why=pcall(pool.onEngineDestroy,pool);if not ok then failure=why end end
  assert(not failure,failure)
 end
 function self.render(_,actorBox,actorSlot,actor,g)
  assert(not self.engineDestroyed,'monster power view engine destroyed')
  local pool=self.pools[actorBox]
  if not pool then
   pool=Surfaces.new(actorBox:GetChild('statusRow'),platform,function(slot,box)onCreate(actorSlot,slot,box,self.pools[actorBox])end,onRetire)
   self.pools[actorBox]=pool
  end
  local rows={}
  for _,entry in ipairs(Combat.statusView(actor))do rows[#rows+1]={id=entry.id,status=entry}end
  pool:select(rows,actor.id)
  for index,row in ipairs(rows)do paint(assert(pool:find(row.id)),row.status,index,g)end
 end
 return self
end
return M
