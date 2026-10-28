package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
-- Controlled offline real Combat fixture: no player draw/plays and forced
-- intent IDs isolate takeTurn/queue contracts, not natural Act4 route evidence.
local C,D,R,A=require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),require('abyss_actor')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)fn();count=count+1;print('PASS ending runtime '..count..' '..name)end
local function battle(ids,advanced,slots,sourceData)
 local data=C.copy(sourceData or D);data.rules.player.drawPerTurn=0
 local streams={};for _,key in ipairs({'aiRng','monsterHpRng','shuffleRng','cardRandomRng'})do streams[key]=R.fromSeed('42')end
 return C.new(data,{enemies=ids,deck={},roomSeed='42',roomStreams=streams,maxHp=5000,hp=5000,
  orbSlots=slots or 0,enableStances=advanced or false})
end
local function force(e,id)
 for i,move in ipairs(e.intents)do if move.id==id then e.intentIndex=i;return end end;error(id)
end
local function created(s,pile)
 local cards={};for _,event in ipairs(s.events)do if event.kind=='cards_created'and event.detail.pile==pile then
  cards[#cards+1]=event.detail.cardId
 end end;return cards
end

test('real constructors register A0 definitions and initialize ordered source power ownership',function()
 local pair=battle({'spire_shield','spire_spear'});local shield,spear=pair.enemies[1],pair.enemies[2]
 eq(shield.hp,110);eq(spear.hp,160);eq(pair.monsterHpRng.counter,2)
 eq(shield.statuses.artifact,1);eq(spear.statuses.artifact,1)
 eq(pair.player.statuses.surrounded,1);eq(shield.statuses.back_attack,1)
 local heart=battle({'corrupt_heart'});local e=heart.enemies[1]
 eq(e.hp,750);eq(heart.monsterHpRng.counter,1);eq(heart.aiRng.counter,1)
 eq(e.statuses.invincible,300);eq(e.statuses.beat_of_death,1)
 eq(e.intents[e.intentIndex].id,'debilitate')
end)

for _,advanced in ipairs({false,true})do
 test((advanced and 'advanced'or 'native')..' Heart executes real debuffs, five draw inserts and captured first Buff',function()
  local s=battle({'corrupt_heart'},advanced);local e=s.enemies[1]
  local card=R.cloneState(s.cardRandomRng);for size=1,4 do R.randomInt(card,size-1)end
  assert(C.endTurn(s));eq(#s.draw,5);eq(#s.discard,0)
  same(created(s,'draw'),{'dazed','slimed','wound','burn','void'})
  same(R.snapshot(s.cardRandomRng),R.snapshot(card))
  for _,id in ipairs({'vulnerable','weak','frail'})do eq(s.player.statuses[id],2,id)end
  -- Two source attacks then first escalation. Cap/Beat damage integration is
  -- explicitly outside this fixture: the player does not attack/use cards.
  assert(C.endTurn(s));assert(C.endTurn(s));assert(C.endTurn(s))
  eq(e.statuses.strength,2);eq(e.statuses.artifact,2);eq(e.heartBuffCount,1)
  eq(s.aiRng.counter,7,'5 primary plus two attack-pair Boolean draws')
 end)
end

test('Bash samples the orb debuff before retaliation and dead owner still rolls while partner lives',function()
 local s=battle({'spire_shield','spire_spear'},false,3);local shield,spear=s.enemies[1],s.enemies[2]
 force(shield,'bash');force(spear,'piercer');s.player.statuses.thorns=110
 local expected=R.cloneState(s.aiRng);local focus=R.randomBoolean(expected)
 R.randomInt(expected,99);R.randomInt(expected,99)
 assert(C.endTurn(s));eq(shield.hp,0)
 eq(focus and s.orbs.focus or s.player.statuses.strength,-1)
 same(R.snapshot(s.aiRng),R.snapshot(expected))
 eq(shield.spireMoveCount,2,'dead Shield queued source RollMove survives')
end)

test('Smash block captures output before damage callbacks can change weakness',function()
 local s=battle({'spire_shield','spire_spear'});local e=s.enemies[1]
 force(e,'smash');force(s.enemies[2],'piercer');s.player.statuses.vulnerable=1;e.statuses.weak=1
 -- Plan includes source BackAttack after ordinary truncation. The shared
 -- Actor integration owns that multiplier for real damage and UI separately.
 local plans=require('abyss_ending_actions').plan(C,s,e,e.intents[e.intentIndex],C.random)
 eq(plans[1].normalAmount,57);eq(plans[2].value,57)
 e.statuses.weak=nil;s.player.statuses.vulnerable=nil
 s.phase='enemy'
 for _,plan in ipairs(plans)do require('abyss_ending_actions').resolve(C,s,plan,e)end
 eq(e.block,57)
end)

test('Spear Burn Strike places exactly two Burns in discard without spending card RNG',function()
 local s=battle({'spire_shield','spire_spear'});local before=R.snapshot(s.cardRandomRng)
 force(s.enemies[1],'fortify');force(s.enemies[2],'burn_strike')
 assert(C.endTurn(s));eq(#s.draw,0);eq(#s.discard,2)
 for _,card in ipairs(s.discard)do eq(card.cardId,'burn');eq(card.upgraded,false)end
 same(R.snapshot(s.cardRandomRng),before)
end)
test('Heart inserts into a nonempty real draw pile with five separate source card draws',function()
 local s=battle({'corrupt_heart'},false,0,require('abyss_watcher_final_cards').withCards(D))
 s.draw={{uid=9000,uuid=9000,cardId='strike',upgraded=false}}
 local expected=R.cloneState(s.cardRandomRng);for size=1,5 do R.randomInt(expected,size-1)end
 s.player.statuses.master_reality=1
 assert(C.endTurn(s));eq(#s.draw,6)
 for _,card in ipairs(s.draw)do eq(card.upgraded,false)end
 same(R.snapshot(s.cardRandomRng),R.snapshot(expected))
end)
test('private admission rejects edited source plans and leaves ordinary effect admission unchanged',function()
 local ending=require('abyss_act4_enemies');local heart=require('abyss_corrupt_heart')
 local e=C.copy(heart.enemy);local move=C.copy(e.intents[1]);move.effects[1].value=99
 assert(not pcall(ending.validateIntent,e,move),'edited source plan must fail closed')
 assert(not require('abyss_effects').supported(heart.enemy.intents[1].effects),'Heart private ops must not enter general whitelist')
 local ordinary={ai={kind='jaw_worm'}}
 eq(require('abyss_ending_actions').plan(C,{},ordinary,{},C.random),nil)
end)
test('real six-round Shield Spear queues preserve independent source AI states for zero and empty positive orb slots',function()
 for _,vector in ipairs(dofile('tests/fixtures/spire-pair-vectors.lua'))do if vector.seed=='42'then
  local s=battle({'spire_shield','spire_spear'},false,vector.orbSlots)
  same(R.snapshot(s.aiRng),vector.openingAfter)
  for _,step in ipairs(vector.steps)do
   eq(s.enemies[1].intents[s.enemies[1].intentIndex].id,step.shield)
   eq(s.enemies[2].intents[s.enemies[2].intentIndex].id,step.spear)
   assert(C.endTurn(s));same(R.snapshot(s.aiRng),step.after)
  end
 end end
end)
test('real Heart escalation applies negative strength repair before permanent source Painful Stabs',function()
 local s=battle({'corrupt_heart'});local e=s.enemies[1]
 -- Controlled escalation stage, not a claim that ten natural turns were played.
 force(e,'buff');e.heartBuffCount=2;e.statuses.strength=-7
 assert(C.endTurn(s));eq(e.statuses.strength,2);eq(e.statuses.painful_stabs,-1)
 eq(e.heartBuffCount,3)
end)
print('ENDING_ENEMY_RUNTIME_PASS '..count..' groups; real lifecycle/actions only; cap/Beat/Act4 admission pending')
