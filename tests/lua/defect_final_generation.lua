package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,P,D,R=require('abyss_combat'),require('abyss_card_actions'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_sts_random')
local data=P.prepare(D,'defect');local Final=require('abyss_defect_final_cards')
local function setup()return C.new(data,{deck={},enemies={'cultist'},seed=42,orbSlots=3,cardRandomSeed='17',shuffleSeed='17'})end
local function play(s,id,up)local c=A.fresh(C,s,id);c.upgraded=up;s.hand={c};s.energy=10;assert(C.play(s,c.uid));return c end
local s=setup();local common=Final.pool(s,'common');local power=Final.pool(s,'power')
assert(#common==18 and #power==13 and common[4]=='recursion' and power[1]=='defragment' and power[13]=='creative_ai')
for _,id in ipairs(power)do assert(id~='self_repair')end
for _,up in ipairs({false,true})do
 s=setup();local expected=R.cloneState(s.cardRandomRng);local id=power[R.randomInt(expected,12)+1]
 play(s,'white_noise',up);assert(s.hand[1].cardId==id and s.hand[1].costForTurn==0 and not s.hand[1].deckUid)
 assert(s.cardRandomRng.counter==expected.counter and #s.exhaust==1)
 for _,kind in ipairs({'hello_world','creative_ai'})do
  s=setup();play(s,kind,up);local pool=kind=='hello_world'and common or power;expected=R.cloneState(s.cardRandomRng)
  id=pool[R.randomInt(expected,#pool-1)+1];assert(C.endTurn(s));assert(s.hand[1].cardId==id and not s.hand[1].deckUid)
  assert(s.cardRandomRng.counter==expected.counter and not s.hand[1].upgraded)
 end
end
s=setup();local card=A.fresh(C,s,'white_noise');s.hand={card};local original=s.catalog.cards.echo_form;s.catalog.cards.echo_form=nil
local counter,energy=s.cardRandomRng.counter,s.energy;local ok,why=pcall(C.play,s,card.uid);assert(not ok and tostring(why):find('incomplete power source pool: echo_form',1,true))
assert(s.hand[1]==card and s.energy==energy and s.cardRandomRng.counter==counter);s.catalog.cards.echo_form=original
-- The shared Master Reality callback is invoked at both source hand creation sites.
s=setup();s.player.statuses.master_reality=1;play(s,'white_noise');assert(s.hand[1].upgraded and s.hand[1].costForTurn==0)
print('DEFECT_FINAL_GENERATION_PASS full18/13 source order, use/start timing, healing exclusion, RNG/UID/private rollback and generated upgrades')
