-- Independent source-contract review, fixed aeubanks/sts@319009d5.
-- Controlled real Core states, not natural acquisition or original-client proof.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local A=require('abyss_actor')
local T=require('abyss_card_triggers')
local D=require('abyss_defect_utility_cards').withCards(require('abyss_defect_cards').withFoundationCards(T.withCards(require('abyss_data'),'silent')))
local passed,failed=0,0
local function eq(a,b,why)assert(a==b,(why or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 local ok,why=pcall(fn)
 if ok then passed=passed+1;print('ok phase_three_review '..name)
 else failed=failed+1;print('not ok phase_three_review '..name..' -- '..tostring(why))end
end
local function held(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c end end;error('missing held '..id)end
local function inPile(pile,uid)for _,c in ipairs(pile)do if c.uid==uid then return true end end;return false end
local function play(s,id,target)local ok,why=C.play(s,held(s,id).uid,target);assert(ok,why)end
local function setup(deck)
 local s=C.new(D,{seed=42,cardRandomSeed='42',deck=deck,enemies={'cultist','jaw_worm'},orbSlots=3})
 for _,e in ipairs(s.enemies)do e.hp=200;e.maxHp=200 end
 return s
end
local function beamVoid(hp)
 local s=setup({'sweeping_beam','void','defend','defend','defend'})
 -- Move the genuine opening Void instance back to the top of the real deck;
 -- all Combat-created UIDs are preserved. No function or handler is replaced.
 local v=held(s,'void');local hand={}
 for _,c in ipairs(s.hand)do if c~=v then hand[#hand+1]=c end end
 s.hand=hand;s.draw={v};s.energy=3;s.player.hp=hp
 A.applyPower(s,s.enemies[1],'sharp_hide',3,s.enemies[1])
 return s,v
end

test('AoE poison on later target resolves before earlier-target lethal Thorns',function()
 local s=setup({'envenom','cleave'})
 play(s,'envenom');s.player.hp=3
 A.applyPower(s,s.enemies[1],'thorns',3,s.enemies[1])
 local first,last=s.enemies[1],s.enemies[2]
 play(s,'cleave',1)
 eq(s.phase,'defeat');eq(s.player.hp,0);eq(first.hp,192);eq(last.hp,192)
 -- Monster.damage source lines649/653: Envenom TOP precedes Thorns TOP.
 -- AoE t1 adds [Thorns1,Poison1]; t2 adds Poison2 above both.
 eq(last.statuses.poison,1,'later target must receive poison before death')
 eq(first.statuses.poison or 0,0,'earlier poison remains below lethal Thorns')
 local poison,death
 for i,e in ipairs(s.events)do
  if e.kind=='status' and e.detail.status=='poison' and e.detail.target==last.id then poison=i end
  if e.kind=='status_damage' and e.detail.status=='thorns' then death=i end
 end
 assert(poison and death and poison<death,'Poison2 precedes Thorns1 in real event frames')
end)

test('ordinary Sweeping Beam drawing Void keeps energy when Sharp Hide is lethal',function()
 local s,v=beamVoid(3);local beam=held(s,'sweeping_beam')
 play(s,'sweeping_beam',1)
 eq(s.phase,'defeat');eq(s.energy,2,'queued Void loss stops after lethal Sharp Hide')
 assert(inPile(s.hand,v.uid));assert(s.cardInUse==beam,'lethal onUse keeps exact using UID')
 assert(not inPile(s.discard,beam.uid))
end)

test('surviving Sweeping Beam resolves Sharp Hide before Void energy tail',function()
 local s,v=beamVoid(30);local beam=held(s,'sweeping_beam')
 play(s,'sweeping_beam',1)
 eq(s.player.hp,27);eq(s.energy,1);assert(inPile(s.hand,v.uid));assert(inPile(s.discard,beam.uid));eq(s.cardInUse,nil)
 local hide
 for _,e in ipairs(s.events)do
  if e.kind=='status_damage' and e.detail.status=='sharp_hide' then hide=e end
 end
 assert(hide,'real Sharp Hide event exists')
 eq(hide.frame.energy,2,'Sharp Hide executes before Void energy loss')
 assert(not inPile(hide.frame.discard,beam.uid),'Void tail is after UseCard, Sharp Hide before UseCard')
end)
print('PHASE_THREE_REVIEW_PASS '..passed..' FAIL '..failed)
if failed>0 then error('phase_three_review found '..failed..' source-contract violations')end
