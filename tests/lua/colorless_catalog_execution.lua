package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local Actions=require('abyss_card_actions');local data=require('abyss_data')
local registered=require('abyss_colorless_cards').withCards(data)
local ids=C.copy(registered.cards.sourcePools.srcColorless)
for _,id in ipairs({'apparition','bite','jax','ritual_dagger'})do ids[#ids+1]=id end
local count=0
for _,id in ipairs(ids)do for _,upgraded in ipairs({false,true})do
 local s=C.new(registered,{deck={},enemies={'jaw_worm','jaw_worm'},seed=79,shuffleSeed='79'})
 for _,enemy in ipairs(s.enemies)do enemy.hp=1000;enemy.maxHp=1000;enemy.block=0 end
 s.player.hp=40;s.energy=5
 local card=Actions.fresh(C,s,id);if upgraded then assert(C.upgrade(s,card))end
 s.hand={card,Actions.fresh(C,s,'strike'),Actions.fresh(C,s,'defend')}
 for n=1,15 do s.draw[#s.draw+1]=Actions.fresh(C,s,n%2==0 and 'strike'or 'defend')end
 local ok,why=C.play(s,card.uid,1);assert(ok,id..' '..tostring(upgraded)..': '..tostring(why))
 local choices=0
 while s.pendingChoice do
  choices=choices+1;assert(choices<=15,'choice continuation did not finish: '..id)
  local p=s.pendingChoice
  local accepted,reason=C.chooseCard(s,p.token,p.multiple and 0 or p.uids[1]);assert(accepted,id..': '..tostring(reason))
 end
 assert(not s.cardActions,id..' left an undrained action queue')
 assert(not s.cardInUse,id..' left the played card in limbo')
 count=count+1
end end
assert(count==78)
print('ok colorless complete 35 ordinary + 4 special, all 78 base/upgraded production plays')
