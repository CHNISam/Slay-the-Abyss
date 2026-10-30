package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/bounded_native_art_fixture.lua')
local R=require('abyss_card_art_runtime')
local Display=require('abyss_card_display')
local function writer(c)c:SetVisible(true)end
local function request(b,m,w)return R.request(b,b:GetChild('artSamples'),m,F.platform,b:GetChild('art'),1,w or writer)end
local function aliveCount()
 local n=0;for _,c in ipairs(F.created)do if c.alive then n=n+1 end end;return n
end
local function empty(b)
 assert(aliveCount()==0,'reentrant cancellation orphaned native controls')
 assert(R.status().livePools==0 and R.status().liveControls==0,'cancelled native budget retained/falsified')
 assert(not b:GetChild('artSamples').visible and b:GetChild('art').visible,'cancelled writer resurrected artwork')
end
local meta=F.metadata('cleave',1)
-- Register a native handle returned after cancellation before releasing it.
local b=F.face();local once=false
R.configure({instantiate=function(i,p)
 if not once then once=true;R.release(b)end
 return F.instantiate(i,p)
end,destroy=F.destroy,imageTemplateIndex=41,containerTemplateIndex=73})
request(b,meta);R.update();empty(b);R.clear();empty(b)
-- A callback can also cancel after the image exists, before final publication.
F.configure(R);b=F.face()
request(b,meta,function(c)writer(c);R.release(b)end);R.update();empty(b)
F.configure(R);b=F.face();request(b,meta,function()return false end);R.update();empty(b);R.clear()
print('NATIVE_CARD_ART_REENTRANCY_PASS initial reproductions')
local function config(instantiate,destroy)
 return {instantiate=instantiate or F.instantiate,destroy=destroy or F.destroy,imageTemplateIndex=41,containerTemplateIndex=73}
end
local alternate=F.metadata('heavy_blade',2)
local cases=0
for _,edge in ipairs({'group-create','image-create','group-setter','image-setter','image-property','color','publish','fallback-hide','writer'})do
 for _,action in ipairs({'release','clear','configure','replace'})do
  R.clear();b=F.face();local fired=false;local platform=F.platform
  local function trigger()
   if fired then return end;fired=true
   if action=='release'then R.release(b)
   elseif action=='clear'then R.clear()
   elseif action=='configure'then R.configure(config())
   else request(b,alternate)end
  end
  local function instantiate(i,p)
   local c=F.instantiate(i,p)
   if edge=='group-create' and i==73 or edge=='image-create' and i==41 then trigger()end
   local method=edge=='group-setter' and i==73 and 'SetAnchorMin' or edge=='image-setter' and i==41 and 'SetImage'
   if method then local original=c[method];c[method]=function(self,...)local result=original(self,...);trigger();return result end end
   if edge=='image-property' and i==41 then
    local mt=getmetatable(c);setmetatable(c,{__index=mt.__index,__newindex=function(t,k,v)rawset(t,k,v);if k=='imageType'then trigger()end end})
   end
   return c
  end
  if edge=='color'then platform={imageSource=F.platform.imageSource,imageTypes=F.platform.imageTypes,
   color=function(...)trigger();return F.platform.color(...)end}end
  local target=edge=='publish' and b:GetChild('artSamples') or edge=='fallback-hide' and b:GetChild('art')
  if target then local original=target.SetVisible;target.SetVisible=function(self,v)
   if edge=='publish' and v or edge=='fallback-hide' and not v then trigger()end
   return original(self,v)
  end end
  R.configure(config(instantiate))
  if edge=='writer'then request(b,meta,function(c)writer(c);trigger()end)
  else Display.writeNativeArt(b,{id='cleave'},meta,platform,b:GetChild('art'),1)end
  R.update();assert(fired,'reentrant edge not exercised: '..edge);empty(b)
  if action=='replace'then R.update();assert(R.status().livePools==1 and b:GetChild('artSamples').visible,'replacement lost after callback')end
  R.clear();empty(b);cases=cases+1
 end
end
-- Actual CardDisplay initial visibility must occur after ownership registration.
F.configure(R);b=F.face();local initialPool=b:GetChild('artSamples');local initialShow=initialPool.SetVisible;once=false
initialPool.SetVisible=function(self,v)if not once then once=true;R.release(b)end;return initialShow(self,v)end
Display.writeNativeArt(b,{id='cleave'},meta,F.platform,b:GetChild('art'),1);R.update();empty(b)
-- Ready-visibility callbacks also cannot publish after release.
F.configure(R);b=F.face();request(b,meta);R.update()
local pool=b:GetChild('artSamples');local show=pool.SetVisible;once=false
pool.SetVisible=function(self,v)if v and not once then once=true;R.release(b)end;return show(self,v)end
assert(not request(b,meta));empty(b)
-- Explicit false/throw from native setters is a cached fail-closed error.
for _,edge in ipairs({'SetAnchorMin','SetSizeDelta','SetImage','SetVisible'})do
 for _,mode in ipairs({'false','throw'})do
  b=F.face();local calls=0
  R.configure(config(function(i,p)
   local c=F.instantiate(i,p)
   if i==(edge=='SetImage' and 41 or 73)then c[edge]=function()calls=calls+1;if mode=='throw'then error('setter failure')end;return false end end
   return c
  end))
  Display.writeNativeArt(b,{id='cleave'},meta,F.platform,b:GetChild('art'),1);R.update()
  empty(b);local saved=calls;request(b,meta);R.update();assert(calls==saved,'failed setter retried each frame')
  R.clear();empty(b)
 end
end
-- Hide failure never short-circuits destruction; both false and throw remain diagnosed.
for _,mode in ipairs({'false','throw'})do
 F.configure(R);b=F.face();request(b,meta);R.update();pool=b:GetChild('artSamples')
 pool.SetVisible=function()if mode=='throw'then error('hide failure')end;return false end
 R.release(b);assert(aliveCount()==0 and R.status().livePools==0 and b:GetChild('art').visible,'hide failure orphaned controls')
end
-- Invalid metadata follows safe cleanup in the real CardDisplay entry, even
-- when a native hide throws or destroys the fallback during that callback.
for _,mode in ipairs({'hide-throws','fallback-dies'})do
 F.configure(R);b=F.face();Display.writeNativeArt(b,{id='cleave'},meta,F.platform,b:GetChild('art'),1);R.update()
 local art=b:GetChild('art');pool=b:GetChild('artSamples');local nativeShow=pool.SetVisible
 pool.SetVisible=function(self,v)
  if mode=='hide-throws'then error('invalid-metadata hide failure')end
  art.alive=false;return nativeShow(self,v)
 end
 assert(not Display.writeNativeArt(b,{id='strike'},nil,F.platform,art,1))
 assert(aliveCount()==0 and R.status().livePools==0,'invalid metadata retained native controls')
end
-- A returned control remains charged while its deferred destruction fails.
b=F.face();once=false
R.configure(config(function(i,p)local c=F.instantiate(i,p);if not once then once=true;F.failDestroy=true;R.release(b)end;return c end))
request(b,meta);R.update();assert(aliveCount()==1 and R.status().livePools==1 and R.status().liveControls==1)
local destroys=F.destroyCalls;request(b,alternate);for _=1,300 do R.update()end
assert(F.destroyCalls==destroys and R.status().livePools==1 and aliveCount()==1,'retained failure retried/escaped budget')
assert(not b:GetChild('artSamples').visible and b:GetChild('art').visible,'replacement exposed retained stale shapes')
F.failDestroy=false;R.clear();empty(b)
-- Destroy callbacks can replace metadata; cleanup must not erase the newer request.
b=F.face();once=false
R.configure(config(nil,function(c)if not once then once=true;request(b,alternate)end;F.destroy(c)end))
request(b,meta);R.update();R.release(b);empty(b);R.update()
assert(R.status().livePools==1 and b:GetChild('artSamples').visible,'destroy callback replacement was clobbered')
R.clear();empty(b)
-- A newer configure from a destroy callback wins over its outer caller.
b=F.face();once=false;local newer=0
local replacementConfig=config(function(i,p)newer=newer+1;return F.instantiate(i,p)end)
R.configure(config(nil,function(c)if not once then once=true;R.configure(replacementConfig)end;F.destroy(c)end))
request(b,meta);R.update();R.configure(config());empty(b);request(b,meta);R.update();assert(newer==2,'nested configure was overwritten')
R.clear();empty(b)
-- Nested update never resets/duplicates the one global creation budget.
b=F.face();R.configure(config(function(i,p)R.update();return F.instantiate(i,p)end))
request(b,F.metadata('cleave',130));local before=#F.created;R.update()
assert(#F.created-before==64 and R.status().createdLastUpdate==64,'nested update exceeded global batch')
R.clear();empty(b)
print('NATIVE_CARD_ART_REENTRANCY_MATRIX_PASS '..cases..' cancellation edges; setters/hide/destroy/configure/budget')
