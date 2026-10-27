package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,D=require('abyss_run'),require('abyss_combat'),require('abyss_card_actions'),require('abyss_data')
local function count(pile,id)local n=0;for _,c in ipairs(pile)do if c.cardId==id then n=n+1 end end;return n end
local function setup(puzzle,warcry)
 local r=Run.new(D,42,{character='defect',experimental=true});r.deck={{uid=31,cardId='all_for_one'}}
 r.relics=puzzle and {'centennial_puzzle'}or {}
 if warcry then
  local red=require('abyss_character_profiles').prepare(D,'ironclad')
  for _,card in ipairs(red.cards.cards)do if card.id=='warcry'then r.data.cards.cards[#r.data.cards.cards+1]=C.copy(card)end end
 end
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat;local c=s.hand[1]
 for _=1,7 do s.hand[#s.hand+1]=A.fresh(C,s,'defend_blue')end
 s.draw={A.fresh(C,s,'defend_blue'),A.fresh(C,s,'defend_blue'),A.fresh(C,s,'defend_blue')}
 s.discard={A.fresh(C,s,'beam_cell'),A.fresh(C,s,'beam_cell'),A.fresh(C,s,'beam_cell')}
 s.enemies[1].hp,s.enemies[1].maxHp=1000,1000;s.enemies[1].statuses.thorns=1;s.energy=5
 return r,s,c
end
local r,s,c=setup(true);assert(Run.play(r,c.uid,1))
assert(#s.hand==10 and #s.draw==0 and count(s.hand,'beam_cell')==0 and count(s.discard,'beam_cell')==3,'Puzzle TOP draw must fill hand before All For One BOTTOM retrieval')
assert(s.relicCombat.centennialUsed and not s.actionQueue and not s.cardActions)
r,s,c=setup(false);assert(Run.play(r,c.uid,1));assert(#s.hand==10 and #s.draw==3 and count(s.hand,'beam_cell')==3)
r,s,c=setup(false);s.hand={};for _=1,10 do s.hand[#s.hand+1]=A.fresh(C,s,'defend_blue')end
C.queueCard(s,c,{append=true,targetIndex=1,purge=false,exhaustCards=false});A.drain(C,s)
assert(#s.hand==10 and #s.draw==3 and count(s.discard,'beam_cell')==3)
r,s,c=setup(true);s.draw[3]=A.fresh(C,s,'void');assert(Run.play(r,c.uid,1))
assert(count(s.hand,'void')==1 and #s.draw==0 and s.energy==2 and count(s.discard,'beam_cell')==3,'bridged Draw must run real Void on-draw callback exactly once')
r,s,c=setup(true,true)
C.queueCard(s,A.fresh(C,s,'warcry'),{append=true,purge=true,exhaustCards=false})
assert(Run.play(r,c.uid,1));assert(#s.draw==0 and count(s.discard,'beam_cell')==3)
local p=assert(s.pendingHandChoice,'real queued Warcry must still pause after bridged draw')
assert(not Run.chooseHand(r,{p.handUids[1]},p.token+1,r.combatGeneration));assert(s.pendingHandChoice==p)
assert(Run.chooseHand(r,{p.handUids[1]},p.token,r.combatGeneration));assert(not s.actionQueue and not s.pendingHandChoice and not s.cardInUse)
r,s,c=setup(true);local hand,draw,discard,enemy=s.hand,s.draw,s.discard,s.enemies[1]
local hp,enemyHp,energy,eventCount=s.player.hp,enemy.hp,s.energy,#s.events
local cardCounter,shuffleCounter=s.cardRandomRng.counter,s.shuffleRng.counter
local realDraw=C.draw
C.draw=function(state,n)local result=realDraw(state,n);if state==s then error('intentional post-Puzzle-draw failure')end;return result end
local ok,why=pcall(Run.play,r,c.uid,1);C.draw=realDraw
assert(not ok and tostring(why):find('intentional post%-Puzzle%-draw failure'))
assert(s.hand==hand and s.draw==draw and s.discard==discard and s.enemies[1]==enemy and s.hand[1]==c)
assert(s.player.hp==hp and enemy.hp==enemyHp and s.energy==energy and #s.events==eventCount)
assert(s.cardRandomRng.counter==cardCounter and s.shuffleRng.counter==shuffleCounter and not s.relicCombat.centennialUsed)
assert(not s.actionQueue and not s.cardActions and not s.cardInUse and not s.pendingPlay)
print('RELIC_TOP_BRIDGE_PASS Puzzle source TOP ordering, ordinary/full-hand retrieval, Void draw, real choice resume and post-draw rollback')
