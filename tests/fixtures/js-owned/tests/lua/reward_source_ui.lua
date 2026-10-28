package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,C=require('abyss_run'),require('abyss_combat')
local P=require('abyss_character_presentation')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function rememberReferences(value)
 local links,seen={},{}
 local function visit(owner)
  if seen[owner]then return end;seen[owner]=true
  for key,item in pairs(owner)do if type(item)=='table'then
   links[#links+1]={owner=owner,key=key,value=item};visit(item)
  end end
 end
 visit(value)
 return function()for _,link in ipairs(links)do eq(link.owner[link.key],link.value)end end
end
-- Complete source identities are selected by the real first normal victory.
local r=Run.new(F.Data,'1',{experimental=true,character='silent'})
assert(Run.startRoomCombat(r,'normal'))
for _,enemy in ipairs(r.combat.enemies)do C.damage(r.combat,r.combat.player,enemy,10000,true)end
assert(Run.finishCombat(r));eq(r.rewards.cards[3],'masterful_stab')
local unavailable=C.copy(r)
local host,root=F.fixture();assert(host:start());host.run,host.battleUI.run=r,r
host.battleUI:setData(r.data,P.prepare(F.Presentation,r.data));host:refresh()
local panel=root:GetChild('battlePanel');panel:GetChild('cardReward').click()
eq(host.battleUI.rewardScreen,'cards')
local implemented=panel:GetChild('card3');assert(implemented.visible)
local rules=implemented:GetChild('label').text:gsub('%s+','')
assert(not rules:find('未实装',1,true));assert(rules:find('12',1,true))
assert(rules:find('生命伤害',1,true)and rules:find('费用增加1',1,true))
eq(implemented:GetChild('cost').text,'0');eq(implemented:GetChild('type').text,'攻击')
local uid,size,permanent,prior=r.nextDeckUid,#r.deck,r.deck,{}
for i,card in ipairs(r.deck)do prior[i]=card;assert(card.uid~=uid)end
host.battleUI:playSlot(3)
eq(r.deck,permanent);eq(#r.deck,size+1);eq(r.nextDeckUid,uid+1)
for i,card in ipairs(prior)do eq(r.deck[i],card)end
eq(r.deck[#r.deck].uid,uid);eq(r.deck[#r.deck].cardId,'masterful_stab');eq(r.deck[#r.deck].upgraded,false)
eq(r.rewards.cardResolved,true);eq(host.battleUI.rewardScreen,'list')
-- Deliberately remove only the selected definition from a detached reward
-- owner. Keep the same seed1 offer/metadata/pools; never reroll another ID.
r=unavailable
local pools=C.copy(r.data.cards.sourcePools);local offers=C.copy(r.rewards.cards);local removed=0
for i=#r.data.cards.cards,1,-1 do if r.data.cards.cards[i].id=='masterful_stab'then table.remove(r.data.cards.cards,i);removed=removed+1 end end
eq(removed,1);same(r.data.cards.sourcePools,pools);same(r.rewards.cards,offers);eq(r.rewards.cards[3],'masterful_stab')
host.run,host.battleUI.run=r,r
host.battleUI:setData(r.data,P.prepare(F.Presentation,r.data));host:refresh();panel:GetChild('cardReward').click()
local missing=panel:GetChild('card3')
assert(missing.visible);assert(missing:GetChild('label').text:find('未实装',1,true))
assert(missing:GetChild('name').text:gsub('%s+',' '):find('Masterful Stab',1,true))
local before=C.copy(r);local deck,rewards=r.deck,r.rewards
local references=rememberReferences(r)
local ok,why=Run.claimCardReward(r,3);eq(ok,false);eq(why,'card_content_unavailable')
same(r,before);eq(r.deck,deck);eq(r.rewards,rewards);references()
host.battleUI:playSlot(3);same(r,before);references()
assert(panel:GetChild('notice').text:find('未实装',1,true))
panel:GetChild('skip').click();eq(host.battleUI.rewardScreen,'list');assert(not r.rewards.cardResolved)
panel:GetChild('continue').click();eq(r.phase,'map')
local upgraded=Run.new(F.Data,'1');upgraded.act,upgraded.floor=2,18
upgraded.encounters=require('abyss_encounter_queue').new('1',2)
assert(Run.startRoomCombat(upgraded,'normal'))
for _,enemy in ipairs(upgraded.combat.enemies)do C.damage(upgraded.combat,upgraded.combat.player,enemy,10000,true)end
assert(Run.finishCombat(upgraded));eq(upgraded.rewards.cards[3],'dual_wield');eq(upgraded.rewards.cardUpgrades[3],true)
local cursor={CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag'}
local h,tree=F.fixture(nil,nil,nil,cursor);assert(h:start());h.run,h.battleUI.run=upgraded,upgraded
h.battleUI:setData(upgraded.data,P.prepare(F.Presentation,upgraded.data));h:refresh()
local p=tree:GetChild('battlePanel');p:GetChild('cardReward').click()
local card=p:GetChild('card3')
assert(card:GetChild('name').text:find('＋',1,true));assert(card:GetChild('label').text:find('2 张',1,true))
local hit=card:GetChild('hit');local pointer={touchId=7}
hit.listeners.down(pointer);upgraded.rewards.cardUpgrades[3]=false
local unchanged=C.copy(upgraded);hit.listeners.up(pointer);hit.click(pointer);same(upgraded,unchanged)
upgraded.rewards.cardUpgrades[3]=true;h:refresh()
hit.listeners.down(pointer);hit.listeners.up(pointer);hit.click(pointer)
eq(upgraded.deck[#upgraded.deck].cardId,'dual_wield');eq(upgraded.deck[#upgraded.deck].upgraded,true)
print('REWARD_SOURCE_UI_PASS 2')
