package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,Actions=require('abyss_combat'),require('abyss_actor'),require('abyss_card_actions')
local D=require('abyss_warrior_strength_cards').withCards(require('abyss_character_profiles').prepare(require('abyss_data'),'watcher'))
local Act3=require('abyss_act3_powers')
local passed,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function fresh(advanced)
 local s=C.new(D,{deck={'study','combust'},enemies={'cultist'},seed=42,orbSlots=0,enableStances=true,cardRandomSeed='42'})
 s.experimentalMechanics=advanced;return s
end
local function play(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then assert(C.play(s,c.uid));return end end
 error('missing real card '..id)
end
for _,advanced in ipairs({false,true})do for _,first in ipairs({'study','combust'})do
 test('source acquisition '..first..' first '..tostring(advanced),function()
  local s=fresh(advanced);play(s,first);play(s,first=='study'and 'combust'or 'study');s.enemies[1].hp=1
  local uid=s.nextUid;assert(C.endTurn(s));eq(C.outcome(s),'victory')
  eq(s.nextUid,uid+(first=='study'and 1 or 0));eq(#s.draw,first=='study'and 1 or 0)
  if first=='study'then eq(s.draw[1].cardId,'insight')end
 end)
end end
-- A generic extension contract fixture, not a fabricated supported encounter.
-- The actual Growth module is independently owned and supplies this same ABI.
local priorIds,priorPlan=Act3.ownerEndIds,Act3.ownerEndPlan
Act3.ownerEndIds={fixture_damage_105=true}
Act3.ownerEndPlan=function(s,id,n)
 eq(id,'fixture_damage_105');return {bottom={{op='ownerEndThorns',source=s.enemies[1],value=n}}}
end
local function applyExtension(s,n)
 s.catalog.statuses.fixture_damage_105={id='fixture_damage_105',priority=105,kind='debuff',stack='intensity',decay='none'}
 A.applyPower(s,s.player,'fixture_damage_105',n,s.enemies[1])
end
for _,advanced in ipairs({false,true})do
 test('priority5 temporary loss precedes earlier acquired105 '..tostring(advanced),function()
  local s=fresh(advanced);s.hand={};applyExtension(s,7);A.addTemporaryStrength(s.player,5,s)
  s.player.hp=20;assert(C.endTurn(s));eq(s.player.hp,13);eq(s.player.statuses.strength,0);eq(s.player.temporaryStrength,0)
  local damage;for _,e in ipairs(s.events)do if e.kind=='status_damage'and e.detail.target=='player'then damage=e end end
  assert(damage);eq(damage.frame.player.statuses.strength,0)
 end)
 test('retained captured-source damage after final Combust gives defeat '..tostring(advanced),function()
  local s=fresh(advanced);play(s,'combust');s.hand={};applyExtension(s,7)
  local source=s.enemies[1];source.hp=1;s.player.hp=6
  local original=C.retaliate;local called=false
  C.retaliate=function(state,owner,target,n)if target==s.player then eq(owner,source);eq(owner.hp,0);called=true end;return original(state,owner,target,n)end
  local ok,why=pcall(C.endTurn,s);C.retaliate=original;assert(ok,why)
  eq(called,true);eq(source.hp,0);eq(s.player.hp,0);eq(C.outcome(s),'defeat');eq(s.phase,'defeat')
 end)
end
Act3.ownerEndIds,Act3.ownerEndPlan=priorIds,priorPlan
print('OWNER_END_MEMBERSHIP '..passed..' passed; '..failed..' failed');assert(failed==0,'owner-end acquisition/priority/retained damage mismatch')
