package.path='source197/src/lua/?.lua;source197/build/lua/?.lua;'..package.path
local C,Cap,data=require('abyss_combat'),require('abyss_card_capability'),require('abyss_data')
local function find(id) for _,card in ipairs(data.cards.cards)do if card.id==id then return card end end end
for _,id in ipairs({'clash','true_grit','warcry','metallicize','whirlwind','demon_form','reaper'})do
 assert(Cap.isImplemented(find(id))==false,id..' must remain rejected in original197')
 local s=C.new(data,{deck={id},enemies={'cultist'},seed=17})
 local ok,why=C.canPlay(s,s.hand[1].uid,1)
 assert(ok==false,id..' prototype unexpectedly executable')
 print('ORIGINAL197 '..id..': capability=false; Combat.canPlay='..tostring(ok)..'/'..tostring(why))
end
print('PASS: original197 rejects all seven unimplemented prototypes. No single-PR gate bug is claimed.')
