local F=dofile('tests/lua/support/toxic_egg_fixture.lua');local L=dofile('tests/helpers/library_event.lua')
local Run,C,H=F.Run,F.C,require('abyss_relic_hooks')
local pass,fail=0,0
local function test(name,fn)local ok,why=pcall(fn);if ok then pass=pass+1;print('PASS '..name)else fail=fail+1;print('FAIL '..name..': '..tostring(why))end end
local function damage(r,card)return C.cardDefinition({catalog={cards={[card.cardId]=F.definition(r,card.cardId)}}},card).effects[1].value end
local function selected(r)
 for _,c in ipairs(L.read(r))do if c.cardId=='searing_blow'then return c end end
 error('fixed Library seed42 must offer Searing Blow')
end
test('source Library constructor copy preserves count but resets base damage before actual Molten hook, next battle and permanent upgrade',function()
 local r,m=L.fixture();assert(Run.obtainRelic(r,'Molten Egg 2'));assert(Run.obtainRelic(r,'CeramicFish'))
 local preview=selected(r);F.eq(preview.upgrades,1);F.eq(preview.upgraded,true);F.eq(damage(r,preview),16)
 local gold,uid,rng=r.gold,r.nextDeckUid,C.copy({r.cardRng,r.miscRng,r.relicPool});local original,reached=H.onObtainCard,false
 H.onObtainCard=function(owner,card,d,api)
  F.eq(card.cardId,'searing_blow');F.eq(card.upgrades,1);F.eq(card.upgraded,false);F.eq(card.searingBlowCopyUpgrades,1);F.eq(damage(owner,card),12)
  F.eq(#owner.deck,#r.deck);local ok,why=original(owner,card,d,api)
  F.eq(card.upgrades,2);F.eq(card.upgraded,true);F.eq(damage(owner,card),17);reached=true;return ok,why
 end
 local ok,why=L.Nodes.chooseEvent(r,'select',preview.offerToken);H.onObtainCard=original;assert(ok,why);assert(reached)
 local permanent=r.deck[#r.deck];F.eq(permanent.uid,uid);F.eq(permanent.upgrades,2);F.eq(permanent.searingBlowCopyUpgrades,1);F.eq(damage(r,permanent),17)
 F.eq(r.gold,gold+9);F.same({r.cardRng,r.miscRng,r.relicPool},rng);F.eq(preview.upgrades,1)
 local before=C.copy(permanent);H.onPreviewObtainCard(r,permanent,F.definition(r,'searing_blow'));F.same(permanent,before)
 assert(L.Nodes.chooseEvent(r,'leave'));r.encounters=require('abyss_encounter_queue').new(r.runSeed,2)
 local node=F.Map.available(m)[1];for _,v in ipairs(m.nodes)do if v.id==node.id then v.type='combat'end end
 assert(L.Nodes.enter(r,m,node.id));local found
 for _,pile in ipairs({r.combat.hand,r.combat.draw,r.combat.discard})do for _,c in ipairs(pile)do if c.deckUid==uid then found=c end end end
 assert(found);F.eq(found.upgrades,2);F.eq(found.searingBlowCopyUpgrades,1);F.eq(C.cardDefinition(r.combat,found).effects[1].value,17)
 assert(Run.upgradeCard(r,uid));permanent=r.deck[#r.deck];F.eq(permanent.uid,uid);F.eq(permanent.upgrades,3);F.eq(damage(r,permanent),23)
 -- A permanent upgrade must not retroactively rewrite an already constructed battle card.
 F.eq(C.cardDefinition(r.combat,found).effects[1].value,17)
end)
test('unupgraded source constructor count remains count-only without Egg, normal Searing growth is unchanged',function()
 local r=Run.new(F.D,42)
 local ok,uid=Run.obtainCard(r,'searing_blow',{upgrades=7,upgraded=false,searingBlowCopyUpgrades=7});assert(ok,uid)
 local c=r.deck[#r.deck];F.eq(c.upgrades,7);F.eq(c.upgraded,false);F.eq(damage(r,c),12)
 assert(Run.upgradeCard(r,uid));c=r.deck[#r.deck];F.eq(c.upgrades,8);F.eq(damage(r,c),23)
 assert(Run.obtainCard(r,'searing_blow',{upgrades=2}));local ordinary=r.deck[#r.deck];F.eq(ordinary.searingBlowCopyUpgrades,nil);F.eq(damage(r,ordinary),21)
 assert(Run.upgradeCard(r,ordinary.uid));F.eq(damage(r,r.deck[#r.deck]),27)
 assert(Run.obtainRelic(r,'Molten Egg 2'));local before=C.copy(r.deck)
 H.onPreviewObtainCard(r,c,F.definition(r,c.cardId));F.same(r.deck,before)
 -- Real play resolves constructor-copy baseDamage, not ordinary count2 damage21.
 local state=C.new(r.data,{seed=42,deck={{uid=99,cardId='searing_blow',upgraded=true,upgrades=2,searingBlowCopyUpgrades=1}},enemies={'cultist'}})
 local card=state.hand[1];local hp=state.enemies[1].hp;assert(C.play(state,card.uid,1));F.eq(state.enemies[1].hp,hp-17)
end)
test('invalid constructor states reject before publication through prepare/commit and Combat initialization',function()
 local r=Run.new(F.D,42);assert(Run.obtainRelic(r,'Molten Egg 2'))
 for _,spec in ipairs({
  {'strike',1,1,false},{'searing_blow',false,1,false},{'searing_blow',-1,1,false},{'searing_blow',.5,1,false},{'searing_blow','1',1,false},
  {'searing_blow',2,1,false},{'searing_blow',1,2,false},{'searing_blow',1,1,true},{'searing_blow',1,nil,false},{'searing_blow',1,1,'false'}})do
  local before=C.copy(r);local options={searingBlowCopyUpgrades=spec[2],upgrades=spec[3],upgraded=spec[4]}
  local ok=Run.obtainCard(r,spec[1],options);F.eq(ok,false);F.same(r,before)
  local offer={cardId=spec[1],searingBlowCopyUpgrades=spec[2],upgrades=spec[3],upgraded=spec[4]}
  F.eq(Run.commitCard(r,offer),false);F.same(r,before)
  local built=pcall(C.new,r.data,{seed=42,deck={offer},enemies={'cultist'}});F.eq(built,false)
 end
end)
test('late hook failure restores constructor state offers UID gold and source streams for a real retry',function()
 local r=L.fixture();assert(Run.obtainRelic(r,'Molten Egg 2'));assert(Run.obtainRelic(r,'CeramicFish'));local card=selected(r)
 local before=C.copy(r);local offers=r.nodeFlow.event.offers;local original,reached=H.onObtainCard,false
 H.onObtainCard=function(owner,c,d,api)original(owner,c,d,api);F.eq(c.upgrades,2);F.eq(damage(owner,c),17);reached=true;error('AFTER_SOURCE_COPY_OBTAIN')end
 local ok=L.Nodes.chooseEvent(r,'select',card.offerToken);H.onObtainCard=original;F.eq(ok,false);assert(reached);F.same(r,before);F.eq(r.nodeFlow.event.offers,offers)
 assert(L.Nodes.chooseEvent(r,'select',card.offerToken));F.eq(damage(r,r.deck[#r.deck]),17)
end)
print('MOLTEN_EGG_SEARING_COPY '..pass..' passed; '..fail..' failed');assert(fail==0)
