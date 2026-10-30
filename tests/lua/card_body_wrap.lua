-- Body fit must mirror native breaking and metrics; otherwise dynamic suffixes
-- such as 格挡反击「（当前 N 点）」 pass fit and are clipped mid-sentence.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local D,T=require('abyss_card_display'),require('abyss_theme')
local Run,Data,P,E=require('abyss_run'),require('abyss_data'),require('abyss_character_presentation'),require('abyss_presentation')
local card=T.layout.card
local function fits(text)
 local _,ok=D.fitBody(text,card.textBox)
 if ok then return 'normal' end
 _,ok=D.fitBody(text,card.longTextBox)
 return ok and 'long' or nil
end
assert(D.fit('ab12cd 一',T.font.card,T.font.card*0.65*6,T.font.card*1.3)<T.font.card,
 'a Latin/digit run must wrap whole, not split mid-word')
assert(fits('对目标造成与自己当前格挡等量的伤害。（当前 999 点）'),'body slam live text must fit')
local run=Run.new(Data,42,{character='ironclad',experimental=true})
local presentation=P.prepare(E,run.data)
for _,id in ipairs({'body_slam'})do
 local display=presentation[id]
 if display then for _,t in ipairs({display.text,display.upgradeText})do
  assert(not t:find('费用：'),'cost belongs to the cost orb, not the body: '..id)
  assert(fits(t..'（当前 999 点）'),'dynamic body must fit: '..id)
 end end
end
print('card body wrap ok')
