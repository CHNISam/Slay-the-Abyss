local capture=dofile('experiments/ui-polish-sim/text-style.lua')
local spec={text={fontSize=24,minFontSize=14,autoSize=true,align='left',valign='middle',colour='#FFFFFF'}}
local resolved=capture({text='余烬之心'},spec,function(v)return v end)
assert(resolved.autoSize==true and resolved.fontSize==24 and resolved.minFontSize==14)
local fixed=capture({text='普通攻击',fontSize=18,minimumFontSize=16,adaptiveFontSize=false},spec,function(v)return v end)
assert(fixed.autoSize==false and fixed.fontSize==18 and fixed.minFontSize==16,'runtime false and size must win')
print('UI_POLISH_TEXT_STYLE_PASS')
