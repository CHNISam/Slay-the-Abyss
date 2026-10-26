package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Run,C=require('abyss_run'),require('abyss_combat')
local P=require('abyss_character_presentation')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
-- Complete source identities are selected by the real first normal victory.
local r=Run.new(F.Data,'1',{experimental=true,character='silent'})
assert(Run.startRoomCombat(r,'normal'))
for _,enemy in ipairs(r.combat.enemies)do C.damage(r.combat,r.combat.player,enemy,10000,true)end
assert(Run.finishCombat(r));eq(r.rewards.cards[3],'masterful_stab')
local host,root=F.fixture();assert(host:start());host.run,host.battleUI.run=r,r
host.battleUI:setData(r.data,P.prepare(F.Presentation,r.data));host:refresh()
local panel=root:GetChild('battlePanel');panel:GetChild('cardReward').click()
eq(host.battleUI.rewardScreen,'cards')
local missing=panel:GetChild('card3')
assert(missing.visible);assert(missing:GetChild('label').text:find('未实装',1,true))
assert(missing:GetChild('name').text:gsub('%s+',' '):find('Masterful Stab',1,true))
local before=C.copy(r);local deck,rewards=r.deck,r.rewards
local ok,why=Run.claimCardReward(r,3);eq(ok,false);eq(why,'card_content_unavailable')
same(r,before);eq(r.deck,deck);eq(r.rewards,rewards)
host.battleUI:playSlot(3);same(r,before)
assert(panel:GetChild('notice').text:find('未实装',1,true))
panel:GetChild('skip').click();eq(host.battleUI.rewardScreen,'list');assert(not r.rewards.cardResolved)
panel:GetChild('continue').click();eq(r.phase,'map')
print('REWARD_SOURCE_UI_PASS 1')
