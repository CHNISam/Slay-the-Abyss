package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,Presentation,Display,Theme=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_character_presentation'),require('abyss_card_display'),require('abyss_theme')
local data=P.prepare(D,'watcher');local display=Presentation.prepare({},data)
local s=C.new(data,{seed=1,enableStances=true,deck={'spirit_shield','swivel','ragnarok'},enemies={'cultist'}})
s.player.statuses.dexterity=2;s.player.statuses.strength=2
local function held(id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end end
local shield=held('spirit_shield');local values=Display.values(C.cardDefinition(s,shield),C.cardPreview(s,shield));assert(values[1] and values[1].current==8)
local rag=held('ragnarok');values=Display.values(C.cardDefinition(s,rag),C.cardPreview(s,rag));assert(values[1] and values[1].current==7)
local exp=require('abyss_card_actions').fresh(C,s,'expunger',{cardId='expunger',upgraded=false,expungerHits=3});s.hand[#s.hand+1]=exp
local d=C.cardDefinition(s,exp);local preview=C.cardPreview(s,exp);local text=Display.format(display.expunger.combatText,d,preview,Theme.color)
assert(text:find('3',1,true) and text:find('11',1,true),'Expunger displays actual stored hits and modified damage')
assert(not text:find('{',1,true))
print('WATCHER_FINAL_LIVE_DISPLAY modified block/damage and stored Expunger hit count passed')
