package.path='src/lua/?.lua;'..package.path
package.preload.abyss_theme=function()return {} end
local Display=require('abyss_card_display')
assert(type(Display.bindNativeAssets)=='function','native artwork binding missing')
local art={cardId='strike',runtime=true,rectangles='00009040010203',rectangleCount=1,rectangleEncoding='xywh-rgb24-hex14'}
local p={strike={name='普通攻击',text='原始效果'}}
local ok=pcall(Display.bindNativeAssets,p,{strike=art,missing={cardId='missing',runtime=true}})
assert(not ok and p.strike.nativeArt==nil,'invalid registry mutated presentation')
Display.bindNativeAssets(p,{strike=art})
assert(p.strike.nativeArt==art and p.strike.name=='普通攻击' and p.strike.text=='原始效果','art binding changed rules/text')
print('READY_ART_BINDING_PASS')
