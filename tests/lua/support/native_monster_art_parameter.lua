local stage,expected={},true
package.loaded.abyss_viewport={apply=function()return stage end}
package.loaded.abyss_traveler_portraits={new=function()return {}end}
package.loaded.abyss_card_art_runtime={configure=function()end}
package.loaded.abyss_ready_card_binding={enabled=false}
package.loaded.abyss_game_ui={new=function(_,_,_,_,options)
 assert(options.nativeMonsterArtEnabled==expected,'native monster artwork must follow GetParam')
 return {resize=function()end}
end}
Enum={CursorEventType={CursorClick='click'},KeyEventType={},ImageSource={StaticReference='static'}}
game={GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return true end}
for _,mode in ipairs({'enabled','disabled','absent','unavailable'}) do
 expected=mode~='disabled'
 local reads=0
 script=setmetatable({object={},EnableUpdate=function()end,GetParam=function(_,name)
  if name=='nativeBgmEnabled' then return false end
  assert(name=='nativeMonsterArtEnabled','unexpected parameter')
  reads=reads+1
  if mode=='unavailable' then error('parameter unavailable') end
  if mode=='absent' then return nil end
  return mode=='enabled'
 end},{__index=function(_,name)error('unsupported script field '..name)end})
 dofile('src/lua/abyss_ui.lua');OnStart()
 assert(reads==1,'real native entry must read its registered parameter exactly once')
end
print('NATIVE_MONSTER_ART_PARAMETER_PASS')
