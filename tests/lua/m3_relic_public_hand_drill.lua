-- Source HandDrill queues Vulnerable2 after the block-breaking attack resolves.
-- Only initial deck/enemy block are controlled; all attacks use real Run.play.
local Run=require('abyss_run');local D=require('abyss_data')
local function fixture(block,owned)
 local r=Run.new(D,42);if owned then assert(Run.obtainRelic(r,'HandDrill'))end
 r.deck={};for i=1,10 do r.deck[i]={uid=i,cardId='strike',upgraded=false}end;r.nextDeckUid=11
 assert(Run.startCombat(r,'cultist_solo'));r.combat.enemies[1].block=block;return r
end
local function attack(r)
 local uid;for _,c in ipairs(r.combat.hand)do if c.cardId=='strike'then uid=c.uid;break end end
 assert(uid);assert(Run.play(r,uid,1))
end
for _,case in ipairs({{0,6,0},{20,0,14},{4,2,0}})do
 local r=fixture(case[1],true);local e=r.combat.enemies[1];local hp=e.hp
 attack(r);assert(e.hp==hp-case[2] and e.block==case[3],'first strike uses unmodified6 damage')
 if case[1]==4 then
  assert(e.statuses.vulnerable==2,'real block break must dispatch queued Vulnerable2')
  hp=e.hp;attack(r);assert(e.hp==hp-9,'following strike uses existing Vulnerable')
 else assert(not e.statuses.vulnerable,'unbroken/no block cannot trigger HandDrill')end
end
local r=fixture(4,false);local e=r.combat.enemies[1];local hp=e.hp
attack(r);assert(e.hp==hp-2 and not e.statuses.vulnerable);attack(r);assert(e.hp==hp-8)
print('M3_RELIC_PUBLIC_HAND_DRILL_PASS 4')
