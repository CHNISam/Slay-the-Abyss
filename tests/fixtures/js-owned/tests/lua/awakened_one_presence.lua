-- Public card/choice commands at an explicit halfDead-only component boundary.
-- This is not a natural cross-act route or a native-client proof.
local C,A,D=require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local Profiles=require('abyss_character_profiles')
local Cards=require('abyss_card_actions')
local R=require('abyss_sts_random')
local bundles={}
local count,failed=0,0
local function eq(a,b,label)assert(a==b,'[AWAKENED_PRESENCE '..(label or 'value')..'] '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 if ABYSS_MUTATION_CASE and ABYSS_MUTATION_CASE~=name then return end
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function battle(class,deck)
 if not bundles[class]then bundles[class]=Profiles.prepare(D,class)end
 local s=C.new(bundles[class],{deck=deck,seed=42,cardRandomSeed='42',enemies={'awakened_one'},
  hp=500,maxHp=500,enableStances=class=='watcher',orbSlots=class=='defect'and 3 or nil})
 return s,s.enemies[1]
end
local function held(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('missing '..id)
end
local function play(s,id,target)local ok,why=C.play(s,held(s,id).uid,target);assert(ok,why)end
local function down(s,e)
 C.damage(s,s.player,e,1000,true);eq(e.hp,0);assert(e.halfDead and A.isPresent(e)and not A.isActive(e))
 eq(C.outcome(s),nil)
end
local function add(s,pile,id)
 local c=Cards.fresh(C,s,id);s[pile][#s[pile]+1]=c;return c
end
local function done(s)
 eq(s.actionQueue,nil);eq(s.cardActions,nil);eq(s.pendingPlay,nil);eq(s.cardInUse,nil);eq(C.outcome(s),nil)
end
test('True Grit upgraded opens and resumes real hand choice while the only monster is halfDead',function()
 local s,e=battle('ironclad',{{cardId='true_grit',upgraded=true},'defend','strike'})
 down(s,e);play(s,'true_grit');local p=assert(s.pendingHandChoice,'hand choice must pause')
 local chosen=held(s,'defend');assert(C.chooseHand(s,{chosen.uid},p.token));eq(s.exhaust[1],chosen)
 done(s);eq(C.chooseHand(s,{chosen.uid},p.token),false);eq(e.hp,0)
end)
test('Warcry retains its draw and PutOnDeck choice on a halfDead-only board',function()
 local s,e=battle('ironclad',{'warcry','strike','defend'});add(s,'draw','defend')
 down(s,e);play(s,'warcry');local p=assert(s.pendingHandChoice,'Warcry choice must pause')
 local chosen=held(s,'strike');assert(C.chooseHand(s,{chosen.uid},p.token))
 eq(s.draw[#s.draw],chosen);eq(s.exhaust[1].cardId,'warcry');done(s)
end)
test('Seek opens and resumes real draw-pile selection without a targetable monster',function()
 local s,e=battle('defect',{'seek'});local chosen=add(s,'draw','defend_blue');add(s,'draw','strike_blue')
 down(s,e);play(s,'seek');local p=assert(s.pendingPileChoice,'Seek must pause')
 assert(C.choosePile(s,{chosen.uid},p.token,0));eq(held(s,'defend_blue'),chosen);done(s)
end)
test('Exhume returns the exact exhausted card through the real pile choice while halfDead',function()
 local s,e=battle('ironclad',{'exhume'});local chosen=add(s,'exhaust','defend');add(s,'exhaust','strike')
 down(s,e);play(s,'exhume');local p=assert(s.pendingPileChoice,'Exhume must pause')
 assert(C.choosePile(s,{chosen.uid},p.token,0));eq(held(s,'defend'),chosen);done(s)
end)
test('Third Eye opens and resumes real Scry while halfDead without a manual-discard trigger',function()
 local s,e=battle('watcher',{'third_eye'});local chosen=add(s,'draw','defend_purple');add(s,'draw','strike_purple')
 down(s,e);play(s,'third_eye');local p=assert(s.pendingScry,'Scry must pause')
 assert(C.chooseScry(s,{chosen.uid},p.token));eq(s.discard[1],chosen);eq(s.discardedThisTurn or 0,0)
 done(s)
end)
test('Survivor opens and resumes real discard selection while halfDead',function()
 local s,e=battle('silent',{'survivor','strike_green','defend_green'})
 down(s,e);play(s,'survivor');local p=assert(s.pendingDiscard,'discard must pause')
 local chosen=held(s,'defend_green');assert(C.chooseDiscard(s,{chosen.uid},p.token))
 eq(s.discard[1],chosen);eq(s.discardedThisTurn,1);done(s)
end)
test('Dark Embrace draws from a real exhaust after first-form death',function()
 local s,e=battle('ironclad',{'dark_embrace','seeing_red'});play(s,'dark_embrace')
 local nextCard=add(s,'draw','defend');down(s,e);play(s,'seeing_red')
 local actual;for _,c in ipairs(s.hand)do if c.cardId=='defend'then actual=c end end
 eq(actual,nextCard,'Dark Embrace continuation');done(s)
end)
for _,advanced in ipairs({false,true})do
 test((advanced and 'advanced'or 'native')..' Red Skull and Centennial Puzzle remain active in the halfDead combat interval',function()
  local I=require('abyss_inventory')
  local opening=assert(I.opening(D.relics.relics,{'red_skull','centennial_puzzle'}))
  local s=C.new(D,{deck={'bloodletting'},seed=42,enemies={'awakened_one'},hp=41,maxHp=80,enableStances=advanced,
   beforeOpeningDraw=function(current)return I.applyOpening(current,opening.beforeDraw)end})
  assert(I.applyOpening(s,opening.afterDraw));local e=s.enemies[1]
  for _=1,3 do add(s,'draw','defend')end
  down(s,e);play(s,'bloodletting');eq(s.player.hp,38);eq(s.player.statuses.strength,3,'Red Skull threshold')
  eq(#s.hand,3,'Centennial draw');assert(s.relicCombat.centennialUsed)
  C.applyEffects(s,{{op='heal',value=3}},s.player,s.player);eq(s.player.hp,41);eq(s.player.statuses.strength,0)
  done(s)
 end)
end
test('Zap and Dualcast retain channel and empty-target evoke without a card RNG draw',function()
 local s,e=battle('defect',{'zap','dualcast'});down(s,e);local counter=s.cardRandomRng.counter
 play(s,'zap');eq(#s.orbs.balls,1,'channel during halfDead');play(s,'dualcast')
 eq(#s.orbs.balls,0);eq(s.cardRandomRng.counter,counter,'empty target does not draw RNG');eq(e.hp,0);done(s)
end)
test('Frost Plasma and Dark non-targeting effects continue while damage target lists stay empty',function()
 local O=require('abyss_orbs');local s,e=battle('defect',{})
 down(s,e);local counter=s.cardRandomRng.counter
 for _,kind in ipairs({'frost','plasma','dark'})do assert(O.channel(s,kind,C))end
 eq(#s.orbs.balls,3);local frost=O.preparePassive(s,1,'end');assert(frost);assert(O.resolve(s,frost,C));eq(s.player.block,2)
 local energy=s.energy;local plasma=O.preparePassive(s,2,'start');assert(O.resolve(s,plasma,C));eq(s.energy,energy+1)
 O.preparePassive(s,3,'end');eq(s.orbs.balls[3].stored,12);eq(e.hp,0);eq(s.cardRandomRng.counter,counter)
end)
test('Mayhem plays a self card after a real Vault skips the halfDead Rebirth turn',function()
 local s,e=battle('watcher',{{cardId='mayhem',upgraded=true},'vault',{cardId='miracle',upgraded=true}})
 play(s,'mayhem');down(s,e);play(s,'miracle');local nextCard=add(s,'draw','defend_purple')
 -- Source Mayhem queues PlayTop behind the ordinary draw. Leave one card
 -- below the five normal draws, rather than assuming it plays before draw.
 for _=1,5 do add(s,'draw','defend_purple')end
 local counter=s.cardRandomRng.counter;play(s,'vault')
 eq(e.hp,0);assert(e.halfDead);eq(s.turn,2);eq(s.player.block,5,'Mayhem self autoplay')
 local played=false;for _,event in ipairs(s.events)do if event.kind=='play'and event.detail.uid==nextCard.uid then played=true end end
 assert(played,'the real autoplay must emit its normal play event');eq(s.cardRandomRng.counter,counter)
 done(s)
end)
test('Sunder intentionally refunds on first-form HP zero unlike Feed Greed and Ritual Dagger',function()
 local s,e=battle('defect',{'sunder'});e.hp=1;play(s,'sunder',1)
 eq(s.energy,3,'source Sunder HP-zero refund');assert(e.halfDead);eq(C.outcome(s),nil);done(s)
end)
print('AWAKENED_ONE_PRESENCE '..count..' groups; '..failed..' failed')
assert(count>0 and failed==0,'Awakened non-target continuation regression')
