package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,Data=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function setup()
 local r=Run.new(Data,42);r.deck={{uid=31,cardId='defend'},{uid=32,cardId='thinking_ahead'}};r.relics={}
 assert(Run.startCombat(r,'cultist_solo'));return r,r.combat
end
local r,s=setup()
assert(s.masterDeck and #s.masterDeck==2,'combat needs ordered private permanent-deck snapshot')
assert(s.masterDeck~=r.deck and s.masterDeck[1]~=r.deck[1]);assert(s.miscRng~=r.miscRng)
local upgrade=C.copy(s.masterDeck[1]);upgrade.upgraded=true;upgrade.upgrades=1
s.masterDeck[1]=upgrade;s.masterDeckChanges={[31]=C.copy(upgrade)}
local expected=R.cloneState(s.miscRng);R.randomInt(expected,0);R.randomInt(s.miscRng,0)
assert(not Run.play(r,999,1));assert(not r.deck[1].upgraded and s.masterDeckChanges)
local card;for _,v in ipairs(s.hand)do if v.cardId=='defend'then card=v end end
assert(Run.play(r,card.uid));assert(r.deck[1].upgraded and r.deck[1].upgrades==1)
assert(not s.masterDeckChanges and r.miscRng.counter==expected.counter and r.miscRng~=s.miscRng)
-- Inject a pending owner result only to test the host transaction boundary:
-- the actual Lesson/Genetic card effects have their own production regressions.
r,s=setup();assert(Run.obtainPotion(r,'distilled_chaos'))
local old=r.miscRng.counter
local ok=Run.usePotion(r,1,nil,function(candidate)
 candidate.masterDeckChanges={[31]={uid=31,cardId='defend',upgraded=true}}
 R.randomInt(candidate.miscRng,0);error('late owner-transaction failure')
end)
assert(not ok and not r.deck[1].upgraded and r.miscRng.counter==old)
assert(r.potions[1]=='distilled_chaos' and not s.masterDeckChanges)
print('PERMANENT_OWNER_BOUNDARY_PASS ordered private snapshot, accepted commit, rejected/failed rollback, misc RNG')
