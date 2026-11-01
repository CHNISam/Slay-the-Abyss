package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local opened,enabled=false,false
local stage={}
package.preload.abyss_menu_background=function()error('deferred title background was loaded')end
package.loaded.abyss_viewport={apply=function()return stage end}
package.loaded.abyss_traveler_portraits={new=function(root)assert(root==stage);return {}end}
package.loaded.abyss_card_art_runtime={configure=function()end}
package.loaded.abyss_ready_card_binding={enabled=false}
package.loaded.abyss_game_ui={new=function(root,_,_,_,options)
 assert(root==stage and options.background==nil,'title art must not compete with selection')
 assert(type(options.createEasterEggArt)=='function','victory artwork must have an explicit lazy factory')
 return {resize=function()end,start=function()opened=true;return true end}
end}
Enum={CursorEventType={CursorClick='click'},KeyEventType={},ImageSource={StaticReference='static'}}
game={GetUICanvasSize=function()return 1280,720 end,IsTestPlay=function()return true end}
script={object={},GetParam=function()return false end,EnableUpdate=function(_,value)enabled=value end}
dofile('src/lua/abyss_ui.lua')
OnStart()
assert(not opened and enabled,'native startup must show the official title without creating custom artwork')
print('OFFICIAL_TITLE_STARTUP_PASS')
