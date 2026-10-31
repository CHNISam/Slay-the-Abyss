-- Controlled prerequisites, genuine obtained master UID and public play/settlement.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,R,D=require('abyss_run'),require('abyss_combat'),require('abyss_sts_random'),require('abyss_data')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
return function(cases)
 for _,f in ipairs(cases)do
  local run=Run.new(D,f.seed,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
  local ok,masterUid=Run.obtainCard(run,'sword_boomerang',{upgraded=f.upgraded});assert(ok)
  run.floor=6 -- explicit encounter prerequisite, not a natural route
  assert(Run.startCombat(run,'elite_sentries'))
  local s=run.combat;local card
  for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do if c.deckUid==masterUid then card=c end end end
  assert(card and card.upgraded==f.upgraded,'real acquired master reaches combat')
  -- No catalog/effect edits: isolate target selection from powers and turn AI.
  s.hand={card};s.draw={};s.discard={};s.exhaust={};s.energy=3;s.player.statuses={};s.player.block=0
  for i,e in ipairs(s.enemies)do e.hp=f.hp[i];e.isDying=f.hp[i]<=0;e.maxHp=30;e.block=0;e.statuses={} end
  same(R.snapshot(s.cardRandomRng),f.initial,'source seed initialization')
  local deck=C.copy(run.deck);local hp=s.player.hp
  local untouched={};for _,k in ipairs({'shuffleRng','aiRng','miscRng','monsterHpRng','potionRng'})do if s[k]then untouched[k]=R.snapshot(s[k])end end
  local rawInt,rawDamage=R.randomInt,C.damage;local draws,hits=0,0
  R.randomInt=function(owner,maximum,...)
   if owner~=s.cardRandomRng then return rawInt(owner,maximum,...)end
   draws=draws+1;local expected=assert(f.hits[draws],'unexpected extra selection draw')
   local eligible={};for i,e in ipairs(s.enemies)do if e.hp>0 then eligible[#eligible+1]=i end end
   same(eligible,expected.eligible,'alive order before hit '..draws)
   same(R.snapshot(owner),expected.before,'before every draw');same(maximum,expected.maximum,'inclusive wrapper bound')
   local value=rawInt(owner,maximum,...);same(value,expected.value,'independent selected index')
   same(R.snapshot(owner),expected.after,'after every draw');return value
  end
  C.damage=function(state,source,target,...)
   if state~=s or source~=s.player then return rawDamage(state,source,target,...)end
   hits=hits+1;local expected=assert(f.hits[hits],'unexpected extra damage')
   assert(target==s.enemies[expected.target],'per-hit target differs from original vector')
   local result=rawDamage(state,source,target,...)
   local actual={};for _,e in ipairs(s.enemies)do actual[#actual+1]=e.hp end
   same(actual,expected.hp,'settled HP after hit '..hits);return result
  end
  local accepted,why=Run.play(run,card.uid,1)
  R.randomInt,C.damage=rawInt,rawDamage
  assert(accepted,tostring(why));same(draws,#f.hits,'exact wrapper draws');same(hits,#f.hits,'exact damage hits')
  same(R.snapshot(s.cardRandomRng),f.after,'complete final source stream')
  assert(s.energy==2 and s.player.hp==hp,'real one-energy cost/no player damage')
  assert(#s.hand==0 and #s.discard==1 and s.discard[1].uid==card.uid,'played instance discarded once')
  same(run.deck,deck,'permanent identities and upgrades retained')
  local dead=true;for _,n in ipairs(f.finalHp)do if n>0 then dead=false end end
  assert(run.phase==(dead and 'reward' or 'combat'),'public victory settlement')
  local before=C.copy(run);assert(not Run.play(run,card.uid,1));same(run,before,'stale play rejected atomically')
  assert(not Run.play(run,999999,1));same(run,before,'unknown instance rejected atomically')
  for k,v in pairs(untouched)do same(R.snapshot(s[k]),v,'unrelated combat stream '..k)end
  print('SWORD_CASE_PASS '..(f.caseId or f.seed..'/'..(f.upgraded and 'upgraded' or 'base')..'/'..f.scenario))
 end
 print('SWORD_RANDOM_ORACLE_PASS '..#cases)
end
