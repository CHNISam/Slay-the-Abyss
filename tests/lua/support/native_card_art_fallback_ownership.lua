package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Native=dofile('tests/lua/support/native_art_controls.lua')
local Small=dofile('tests/lua/support/bounded_native_art_fixture.lua')
local Runtime=require('abyss_card_art_runtime')
local Run,Map,Nodes=require('abyss_run'),require('abyss_map'),require('abyss_nodes')
local run=Run.new(F.Data,42);local map=Map.generate(run.data,42)
for _=1,17 do
 local choices,found=Map.available(map),false
 for _,node in ipairs(choices)do if node.type=='shop'then assert(Nodes.enter(run,map,node.id));found=true;break end end
 if found then break end;assert(Map.choose(map,assert(choices[1]).id))
end
local root=Native.decorate(F.Viewport.apply(F.control({children=F.Layout}),1280,720))
local face=root:GetChild('nodePanel'):GetChild('shopView'):GetChild('card1')
local options=Small.platform
local node=require('abyss_node_ui').new(root:GetChild('nodePanel'),run,map,F.Presentation,'click',function()end,options)
local failures,passed={},0
local function check(kind,ready,label)
 for art in pairs(F.Theme.icon.cardArt)do
  assert(face:GetChild('art_'..art).visible==(art==kind and not ready),label..': obsolete/wrong fallback '..art)
 end
 assert(face:GetChild('artSamples').visible==ready,label..': native visibility')
end
local function render(id)run.nodeFlow.cards[1].id=id;node:render()end
local function scenario(name,fn)
 Runtime.clear();Small.configure(Runtime)
 for _,id in ipairs({'strike','defend','inflame'})do F.Presentation[id].nativeArt=Small.metadata(id,1)end
 local ok,reason=pcall(fn)
 if ok then passed=passed+1;print('PASS '..name)else failures[#failures+1]=name..': '..tostring(reason);print('FAIL '..failures[#failures])end
 Runtime.clear()
end
for _,state in ipairs({'ready','pending'})do
 for _,target in ipairs({{'defend','skill'},{'inflame','power'},{'injury','status'}})do
  scenario(state..' attack to '..target[2],function()
   if state=='pending'then F.Presentation.strike.nativeArt=Small.metadata('strike',100)end
   render('strike');Runtime.update();check('attack',state=='ready','original '..state)
   render(target[1]);check(target[2],false,'replacement before update')
   Runtime.update();check(target[2],target[1]~='injury','replacement after update')
  end)
 end
end
for _,target in ipairs({{'defend','skill'},{'inflame','power'},{'injury','status'}})do
 scenario('deferred attack to '..target[2],function()
  local once=false
  Runtime.configure({instantiate=function(index,parent)
   local control=Small.instantiate(index,parent)
   if index==41 then
    local image=control.SetImage
    control.SetImage=function(self,...)
     if not once then once=true;render(target[1])end
     return image(self,...)
    end
   end
   return control
  end,destroy=Small.destroy,imageTemplateIndex=41,containerTemplateIndex=73})
  render('strike');Runtime.update();assert(once,'replacement callback not delivered')
  check(target[2],false,'deferred cleanup')
  Runtime.update();check(target[2],target[1]~='injury','deferred replacement update')
 end)
end
-- Cleanup and final fallback writes can re-enter before the native setter lands.
for _,edge in ipairs({'pool-hide','fallback-show','destroy'})do
 scenario('cleanup '..edge..' changes latest type',function()
  render('strike');Runtime.update();check('attack',true,'ready before cleanup')
  local once=false
  local function replace()if not once then once=true;render('inflame')end end
  local control=edge=='pool-hide' and face:GetChild('artSamples') or face:GetChild('art_attack')
  local original=control.SetVisible
  if edge~='destroy'then control.SetVisible=function(self,value)
   if edge=='pool-hide' and not value or edge=='fallback-show' and value then replace()end
   return original(self,value)
  end end
  -- The destruction callback is bound into each allocation record.
  if edge=='destroy'then
   Runtime.clear();Runtime.configure({instantiate=Small.instantiate,destroy=function(c)replace();Small.destroy(c)end,
    imageTemplateIndex=41,containerTemplateIndex=73})
   render('strike');Runtime.update()
  end
  require('abyss_card_display').clearNativeArt(face)
  control.SetVisible=original
  assert(once,'cleanup callback not delivered')
  check('power',false,'cleanup latest owner');Runtime.update();check('power',true,'cleanup latest ready')
 end)
end
-- Legacy explicit static pools remain supported, including a deferred handoff.
for _,state in ipairs({'ready','pending','deferred'})do
 scenario('runtime to static '..state,function()
  local pool=face:GetChild('artSamples')
  local group=Native.decorate(F.control({name='group000',kind='container',children={
   {name='shape0000',kind='image',size={1,1},visible=false}}},pool))
  pool.children.group000=group
  local meta=Small.metadata('defend',1);meta.runtime=nil;F.Presentation.defend.nativeArt=meta
  if state=='pending'then F.Presentation.strike.nativeArt=Small.metadata('strike',100)end
  local once=false
  if state=='deferred'then Runtime.configure({instantiate=function(index,parent)
   local c=Small.instantiate(index,parent)
   if index==41 then local original=c.SetImage;c.SetImage=function(self,...)
    if not once then once=true;render('defend')end
    return original(self,...)
   end end
   return c
  end,destroy=Small.destroy,imageTemplateIndex=41,containerTemplateIndex=73})end
  render('strike');Runtime.update()
  if state=='deferred'then assert(once,'static handoff callback not delivered')else render('defend')end
  check('skill',true,'static handoff');Runtime.update();check('skill',true,'static after update')
  assert(Runtime.status().livePools==0,'static handoff retained runtime allocation')
  require('abyss_card_display').clearNativeArt(face)
  pool.children.group000=nil
 end)
end
local function static(id)
 local pool=face:GetChild('artSamples')
 pool.children.group000=Native.decorate(F.control({name='group000',kind='container',children={
  {name='shape0000',kind='image',size={1,1},visible=false}}},pool))
 local meta=Small.metadata(id,1);meta.runtime=nil;F.Presentation[id].nativeArt=meta
 return pool.children.group000:GetChild('shape0000')
end
for _,target in ipairs({{'defend','skill','pool-hide'},{'strike','attack','fallback-show'}})do
 scenario('cleanup to static '..target[3],function()
  render('strike');Runtime.update()
  local shape=static(target[1]);local once=false
  local control=face:GetChild(target[3]=='pool-hide' and 'artSamples' or 'art_attack')
  local original=control.SetVisible
  control.SetVisible=function(self,value)
   if not once and (target[3]=='pool-hide' and not value or target[3]=='fallback-show' and value)then
    once=true;render(target[1])
   end
   return original(self,value)
  end
  require('abyss_card_display').clearNativeArt(face)
  control.SetVisible=original
  assert(once,'static cleanup callback not delivered')
  check(target[2],true,'latest static publication')
  assert(shape.visible,'outer cleanup hid the replacement static shape')
  require('abyss_card_display').clearNativeArt(face);face:GetChild('artSamples').children.group000=nil
 end)
end
scenario('unbound fallback setter hands off again',function()
 render('strike');Runtime.update()
 local control=face:GetChild('art_status');local original=control.SetVisible;local once=false
 control.SetVisible=function(self,value)
  -- The first write is NodeUI's selection loop; re-enter the runtime-owned write.
  if value then once=(once or 0)+1;if once==2 then render('defend')end end
  return original(self,value)
 end
 render('injury');control.SetVisible=original
 assert(once==2,'unbound native visibility callback not delivered')
 check('skill',false,'latest unbound replacement');Runtime.update();check('skill',true,'latest unbound ready')
end)
scenario('failed destroy blocks static publication without a TTL',function()
 render('strike');Runtime.update();static('defend')
 Small.failDestroy=true;render('defend');check('skill',false,'retained old allocation')
 local calls=Small.destroyCalls
 for _=1,300 do Runtime.update()end
 assert(Small.destroyCalls==calls,'retained cleanup retried every frame')
 assert(Runtime.status().livePools==1 and Runtime.status().liveControls==2,'retained ownership lost budget')
 check('skill',false,'retained old allocation after updates')
 Small.failDestroy=false;require('abyss_card_display').clearNativeArt(face)
 assert(Runtime.status().livePools==0,'explicit cleanup did not release retained ownership')
 face:GetChild('artSamples').children.group000=nil
end)
local function staticMetadata(id,image)
 local meta=Small.metadata(id,1);meta.runtime=nil;meta.slots[1].image=image
 F.Presentation[id].nativeArt=meta
end
scenario('superseded static bind stops before writing',function()
 render('strike');Runtime.update();local shape=static('defend')
 staticMetadata('defend',100002);staticMetadata('inflame',100003)
 local pool=face:GetChild('artSamples');local original=pool.SetVisible;local once=false
 pool.SetVisible=function(self,value)
  if not value and not once then once=true;render('inflame')end
  return original(self,value)
 end
 render('defend');pool.SetVisible=original
 assert(once,'nested static bind callback not delivered');check('power',true,'latest nested static')
 assert(shape.imageId==100003,'stale static bind overwrote latest geometry')
 require('abyss_card_display').clearNativeArt(face);pool.children.group000=nil
end)
for _,edge in ipairs({'shape-hide','shape-write'})do
 scenario('stale static '..edge..' fails closed until explicit render',function()
  local shape=static('strike');render('strike')
  staticMetadata('defend',100002);staticMetadata('inflame',100003)
  local method=edge=='shape-hide' and 'SetVisible' or 'SetImage'
  local original=shape[method];local once=false
  shape[method]=function(self,...)
   if not once then once=true;render('inflame')end
   return original(self,...)
  end
  if edge=='shape-hide'then require('abyss_card_display').clearNativeArt(face)else render('defend')end
  shape[method]=original
  assert(once,'static shape callback not delivered');check('power',false,'stale static mutation must fail closed')
  render('inflame');check('power',true,'explicit render restores latest static')
  assert(shape.visible and shape.imageId==100003,'explicit render reused corrupted static cache')
  require('abyss_card_display').clearNativeArt(face);face:GetChild('artSamples').children.group000=nil
 end)
end
for _,edge in ipairs({'ordinary','shape-hide'})do
 scenario('static to runtime '..edge..' leaves no static tail',function()
  local shape=static('strike');render('strike')
  local original=shape.SetVisible;local once=false
  if edge=='shape-hide'then shape.SetVisible=function(self,value)
   if not once then once=true;render('inflame')end
   return original(self,value)
  end end
  if edge=='shape-hide'then
   require('abyss_card_display').clearNativeArt(face);shape.SetVisible=original
   assert(once,'runtime replacement callback not delivered')
   for _=1,3 do Runtime.update()end
   check('power',false,'damaged pool must not republish from update')
   assert(Runtime.status().livePools==0,'damaged pending owner was not retired')
  end
  render('inflame');Runtime.update();check('power',true,'explicit runtime binding')
  assert(not shape.visible,'runtime artwork exposed stale static shapes')
  require('abyss_card_display').clearNativeArt(face);face:GetChild('artSamples').children.group000=nil
 end)
end
for _,edge in ipairs({'property','color'})do
 scenario('stale static '..edge..' callback fails closed',function()
  local shape=static('strike');render('strike')
  staticMetadata('defend',100002);staticMetadata('inflame',100003)
  local once=false;local mt=getmetatable(shape);local color=options.color
  local function replace()if not once then once=true;render('inflame')end end
  if edge=='property'then
   shape.imageType=nil
   setmetatable(shape,{__index=mt.__index,__newindex=function(t,k,v)
    if k=='imageType'then replace()end
    mt.__newindex(t,k,v)
   end})
  else options.color=function(r,g,b,a)
   if r==4 and g==5 and b==6 and a==7 then replace()end
   return color(r,g,b,a)
  end end
  render('defend');setmetatable(shape,mt);options.color=color
  assert(once,'static '..edge..' callback not delivered');check('power',false,'cancelled static '..edge)
  render('inflame');check('power',true,'explicit render after '..edge)
  assert(shape.visible and shape.imageId==100003,'stale '..edge..' cache survived')
  require('abyss_card_display').clearNativeArt(face);face:GetChild('artSamples').children.group000=nil
 end)
end
for _,mode in ipairs({'false','throw'})do
 scenario('rejected static hide blocks runtime '..mode,function()
  local shape=static('strike');render('strike')
  local original=shape.SetVisible;local calls=0
  shape.SetVisible=function()calls=calls+1;if mode=='throw'then error('static hide rejected')end;return false end
  render('inflame');check('power',false,'rejected static hide')
  local saved=calls;for _=1,3 do Runtime.update()end
  assert(calls==saved and Runtime.status().livePools==0,'failed static hide retried/admitted runtime')
  check('power',false,'rejected static hide remains fallback')
  shape.SetVisible=original;render('inflame');Runtime.update();check('power',true,'explicit hide recovery')
  assert(not shape.visible,'successful recovery retained static tail')
  require('abyss_card_display').clearNativeArt(face);face:GetChild('artSamples').children.group000=nil
 end)
end
for _,name in ipairs({'artSamples','art_attack'})do
 scenario('ordinary release callback converges '..name,function()
  render('strike');Runtime.update()
  local control=face:GetChild(name);local original=control.SetVisible;local calls=0
  control.SetVisible=function(self,value)
   calls=calls+1;assert(calls<20,'ordinary release reconciliation did not converge')
   Runtime.release(face);return original(self,value)
  end
  Runtime.release(face);control.SetVisible=original
  assert(calls<20,'identical ordinary release kept replacing ownership')
  check('attack',false,'ordinary release callback');assert(Runtime.status().livePools==0)
 end)
end
assert(#failures==0,table.concat(failures,'\n'))
print('NATIVE_CARD_ART_FALLBACK_OWNERSHIP_PASS '..passed)
