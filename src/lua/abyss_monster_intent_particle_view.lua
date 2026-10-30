-- Per-instance native outputs for the two source intent particle classes.
-- Glyphs and the explicit 16-unit star bounds are replacements, not source atlas pixels.
local Particles=require('abyss_monster_intent_particles')
local Displayed=require('abyss_monster_displayed_intent')
local Surfaces=require('abyss_monster_power_surfaces')
local Random=require('abyss_randomxs128')
local Theme=require('abyss_theme')
local sequence=Particles.newSequence() -- Java static phase survives battle changes.
local cosmetic=Random.fromSeed('0') -- Separate visual stream; never combat RNG.
local M={}
local function call(control,name,...)assert(control[name](control,...)~=false,'intent particle native write rejected: '..name)end
local function createIntent(state)Particles.createIntent(state);state.createPending=true end
function M.new(platform,picture,tint)
 local self={states={},outputs={}}
 function self.release(_,box,engineDestroyed)
  local output=self.outputs[box]
  if output then
   local failure
   for _,pool in pairs(output)do local ok,why=pcall(engineDestroyed and pool.onEngineDestroy or pool.clear,pool);if not ok then failure=why end end
   if failure then error(failure)end
   self.outputs[box]=nil
  end
 end
 function self.onEngineDestroy(_)
  self.engineDestroyed=true
  local outputs=self.outputs;self.outputs={}
  self.states={};self.battle=nil;self.event=nil;self.shown=nil;self.failed=nil
  local failure
  for _,output in pairs(outputs)do for _,pool in pairs(output)do
   local ok,why=pcall(pool.onEngineDestroy,pool);if not ok then failure=why end
  end end
  assert(not failure,failure)
 end
 function self.clear(_)
  if self.engineDestroyed then return end
  local failure
  for box in pairs(self.outputs)do local ok,why=pcall(self.release,self,box);if not ok then failure=why end end
  if failure then error(failure)end
  self.states={};self.battle=nil;self.event=nil;self.shown=nil;self.failed=nil
 end
 function self.sync(_,rows,battle,event,viewActive)
  assert(not self.engineDestroyed,'monster intent view engine destroyed')
  local entering=self.battle~=battle
  if entering then self:clear();self.battle=battle end
  local firstShow=viewActive~=false and battle~=nil and not self.shown
  if firstShow and #rows>0 then self.shown=true end
  local wanted={}
  for _,row in ipairs(rows)do
   wanted[row.id]=true
   if not self.states[row.id]then local state=Particles.newActor();state.displayed=Displayed.new();if firstShow then createIntent(state)end;self.states[row.id]=state end
  end
  if viewActive~=false then for id in pairs(self.states)do if not wanted[id]then self.states[id]=nil end end end
  if event and event~=self.event then
   self.event=event
   if event.sourceIntentPowers then
    assert(event.sourceIntentPowers.scope=='all-monsters','unknown source power refresh scope')
    for _,state in pairs(self.states)do state.powersPending=true end
   end
   local d=type(event.detail)=='table' and event.detail or {}
   if event.kind=='player_turn' then for _,state in pairs(self.states)do createIntent(state)end
   elseif event.kind=='intent' and self.states[d.enemy]then Particles.flashIntent(self.states[d.enemy])
   elseif self.states[d.enemy] and (event.kind=='enemy_interrupt' or event.kind=='enemy_wake' and d.reason=='hp_loss' or event.kind=='enemy_mode' and d.mode=='defense')then
    createIntent(self.states[d.enemy])
   end
  end
 end
 function self.needsSelected(_,id)
  local state=assert(self.states[id],'missing intent instance')
  return state.createPending or state.powersPending
 end
 function self.face(_,id,selected,calculate)
  local state=assert(self.states[id],'missing intent instance')
  if state.createPending and selected then Displayed.createIntent(state.displayed,selected,calculate);state.createPending=nil end
  if state.powersPending then Displayed.applyPowers(state.displayed,selected,calculate);state.powersPending=nil end
  return Displayed.face(state.displayed)
 end
 function self.update(_,id,dt,face,g,dying,escaping)
  local state=assert(self.states[id],'missing intent instance')
  Particles.updateAlpha(state,dt)
  Particles.update(state,sequence,{dt=dt,intent=face.sourceEnum,intentAlpha=state.intentAlpha,
   isDying=dying,isEscaping=escaping,x=g.x+g.intentX,y=g.y+g.intentY,scale=g.sourceScale,
   starWidth=16,starHeight=16},function()return Random.nextFloat(cosmetic)end)
 end
 function self.alpha(_,id)return assert(self.states[id],'missing intent instance').intentAlpha end
 local function paint(box,id,g,allowed)
  local state=assert(self.states[id],'missing intent instance')
  local output=self.outputs[box]
  if not output and #state.effects==0 then return end
  if not output then
   output={};self.outputs[box]=output
   for _,layer in ipairs({'intentVfxBehind','intentVfxAfter'})do output[layer]=Surfaces.new(box:GetChild(layer),platform)end
  end
  local rows={intentVfxBehind={},intentVfxAfter={}}
  for _,effect in ipairs(state.effects)do
   local layer=effect.renderBehind and 'intentVfxBehind' or 'intentVfxAfter'
   rows[layer][#rows[layer]+1]={id=tostring(effect.effectId),effect=effect}
  end
  for layer,pool in pairs(output)do
   pool:select(rows[layer],id)
   local generation=pool.generation
   local function valid(control,key)assert(pool.generation==generation and pool:find(key)==control and control.alive~=false,'intent particle publication cancelled')end
   for _,row in ipairs(rows[layer])do
    local control=assert(pool:find(row.id));local e=row.effect
    local function write(target,name,...)valid(control,row.id);call(target,name,...);valid(control,row.id)end
    for _,name in ipairs({'edge','body','badge','count','hit'})do write(control:GetChild(name),'SetVisible',false)end
    local icon=control:GetChild('icon');write(icon,'SetVisible',true)
    valid(control,row.id);picture(icon,e.textureKey=='TINY_STAR' and Theme.image.star or Theme.icon.intent.unknown);valid(control,row.id)
    write(icon,'SetAnchoredPosition',0,0);write(icon,'SetSizeDelta',e.width,e.height)
    write(icon,'SetLocalScale',e.scale,e.scale,1);write(icon,'SetLocalRotation',0,0,e.rotationDeg)
    valid(control,row.id);tint(icon,{r=e.color[1]*255,g=e.color[2]*255,b=e.color[3]*255,a=e.color[4]*255});valid(control,row.id)
    write(control,'SetAnchoredPosition',e.centerX-g.x,e.centerY-g.y);write(control,'SetVisible',allowed)
   end
  end
 end
 function self.paint(_,box,id,g,allowed)
  assert(not self.engineDestroyed,'monster intent view engine destroyed')
  assert(not self.failed,self.failed)
  local ok,reason=pcall(paint,box,id,g,allowed)
  if not ok then
   self.failed=tostring(reason)
   pcall(self.release,self,box) -- Retain failed native cleanup ownership for explicit clear retry.
   error(reason)
  end
 end
 return self
end
return M
