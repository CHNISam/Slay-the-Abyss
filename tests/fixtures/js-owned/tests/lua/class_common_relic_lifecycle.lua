package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local R,C,A,H=require('abyss_run'),require('abyss_combat'),require('abyss_actor'),require('abyss_relic_hooks')
local S=require('abyss_sts_random')
local D=require('abyss_data')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 assert(type(a)==type(b),'type differs');if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,'extra key '..tostring(k))end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function run(character,ids)
 local r=R.new(D,'42',character and {experimental=true,character=character}or nil)
 for _,id in ipairs(ids or {})do assert(R.obtainRelic(r,id))end
 assert(R.startCombat(r,'cultist_solo'));local s=r.combat;s.enemies[1].hp=10000;s.enemies[1].maxHp=10000
 return r,s
end
local function nextBattle(r)
 local old=r.combat
 C.damage(old,old.player,old.enemies[1],20000,true)
 assert(R.finishCombat(r));assert(R.leaveCombatRewards(r));assert(R.startCombat(r,'cultist_solo'))
 assert(r.combat~=old);return r.combat
end

test('Damaru dispatches one queued Mantra each real player turn, before normal draw',function()
 local r,s=run('watcher',{'Damaru'});eq(s.player.statuses.mantra,1);eq(s.mantraGained,1)
 local mantraFrame
 for i,event in ipairs(s.events)do
  if event.kind=='status'and event.detail.status=='mantra'then mantraFrame=event.frame;eq(event.detail.source,nil,'Damaru source is null')end
 end
 assert(mantraFrame and #mantraFrame.hand==1 and #s.hand==6,'Damaru follows Pure Water and precedes normal draw')
 s.player.statuses.artifact=2;assert(R.endTurn(r));eq(s.player.statuses.mantra,2);eq(s.mantraGained,2);eq(s.player.statuses.artifact,2)
end)
test('Damaru threshold uses the existing stance owner and exits Divinity next turn',function()
 local r,s=run('watcher',{'damaru'});s.player.hp=10000;s.player.maxHp=10000
 for expected=2,10 do assert(R.endTurn(r));eq(s.mantraGained,expected);if expected<10 then eq(s.player.statuses.mantra,expected)end end
 eq(s.player.statuses.mantra,nil);eq(s.player.stance,'Divinity');eq(s.energy,6)
 assert(R.endTurn(r));eq(s.player.stance,'Neutral');eq(s.player.statuses.mantra,1);eq(s.energy,3);eq(s.mantraGained,11)
end)
test('Damaru appends before Devotion but both constructors count once before resolution',function()
 local r,s=run('watcher',{'damaru'});s.player.statuses.mantra=8
 A.applyPower(s,s.player,'devotion',2,s.player)
 assert(R.endTurn(r));eq(s.player.statuses.mantra,1);eq(s.player.stance,'Divinity');eq(s.mantraGained,4)
end)
test('externally acquired Damaru works for non-Watcher and default Ironclad Run profiles',function()
 for _,character in ipairs({'silent','defect','ironclad'})do
  local r,s=run(character,{'damaru'});eq(s.player.statuses.mantra,1)
  s.player.statuses.mantra=9;assert(R.endTurn(r));eq(s.player.stance,'Divinity');eq(s.energy,6)
 end
 local _,s=run(nil,{'damaru'});eq(s.player.statuses.mantra,1)
end)
test('owners without Damaru never gain Mantra and battle teardown cannot tick it',function()
 local r,s=run('watcher');eq(s.player.statuses.mantra,nil);assert(R.endTurn(r));eq(s.player.statuses.mantra,nil)
 s.relics={'damaru'};s.enemies[1].hp=0;s.phase='victory'
 local before=s.mantraGained;assert(C.startPlayerTurn(s)==nil);eq(s.mantraGained,before);eq(s.player.statuses.mantra,nil)
end)
test('failed real end turn restores Damaru constructor counter, stack and retained owners',function()
 local r,s=run('watcher',{'damaru'});local statuses,events=s.player.statuses,s.events
 local before=C.copy(s);local original=A.applyPower
 A.applyPower=function(state,actor,id,...)
  local value=original(state,actor,id,...);if id=='mantra'then error('AFTER_DAMARU_APPLY')end;return value
 end
 local called,ok=pcall(R.endTurn,r);A.applyPower=original
 assert(not called or not ok);eq(r.combat,s);eq(s.player.statuses,statuses);eq(s.events,events);same(s,before)
 assert(R.endTurn(r));eq(s.player.statuses.mantra,2);eq(s.mantraGained,2)
end)
test('Snake Skull failed card application rolls back extra poison, energy and card identity',function()
 local r,s=run('silent',{'snake_skull'});s.hand={{uid=999,cardId='deadly_poison',upgraded=false}}
 local card=s.hand[1];local before=C.copy(s);local original=A.applyPower
 A.applyPower=function(state,actor,id,...)
  local value=original(state,actor,id,...);if id=='poison'then error('AFTER_SNAKE_APPLY')end;return value
 end
 local called,ok=pcall(R.play,r,card.uid,1);A.applyPower=original
 assert(not called or not ok);eq(r.combat,s);eq(s.hand[1],card);same(s,before)
 assert(R.play(r,card.uid,1));eq(s.enemies[1].statuses.poison,6)
end)
test('all three relics have no immediate onEquip benefit; failed obtain preserves ownership and entropy',function()
 for _,id in ipairs({'snake_skull','data_disk','damaru'})do
  local r=R.new(D,'42');local before=C.copy(r);local refs={r.relics,r.miscRng,r.deck}
  local original=H.onEquip
  H.onEquip=function(staged,relic,...)
   original(staged,relic,...);S.randomInt(staged.miscRng,99);error('AFTER_CLASS_RELIC_EQUIP')
  end
  local ok=R.obtainRelic(r,id);H.onEquip=original;assert(not ok);same(r,before)
  eq(r.relics,refs[1]);eq(r.miscRng,refs[2]);eq(r.deck,refs[3])
  assert(R.obtainRelic(r,id));eq(r.hp,before.hp);eq(r.maxHp,before.maxHp);same(r.miscRng,before.miscRng)
  local obtained=C.copy(r);assert(not R.obtainRelic(r,id));same(r,obtained)
 end
end)
test('outer transaction refusal rolls back active-combat ownership synchronization',function()
 for _,id in ipairs({'snake_skull','data_disk','damaru'})do
  local r,s=run('silent');local before=C.copy(r);local relics=s.relics
  local ok,why=R.transaction(r,function(staged)
   assert(R.obtainRelic(staged,id));assert(H.owns(staged.combat,id))
   return false,'AFTER_CLASS_RELIC_SYNC'
  end)
  assert(not ok and why=='AFTER_CLASS_RELIC_SYNC');same(r,before);eq(r.combat,s);eq(s.relics,relics)
 end
end)
test('Damaru and DataDisk reset only battle-local powers on an actual next battle',function()
 local r,s=run('defect',{'damaru','data_disk','snake_skull'});eq(s.player.statuses.focus,1);eq(s.player.statuses.mantra,1)
 s.player.statuses.focus=7;s.player.statuses.mantra=8;s.mantraGained=12
 local fresh=nextBattle(r);eq(fresh.player.statuses.focus,1);eq(fresh.orbs.focus,1);eq(fresh.player.statuses.mantra,1);eq(fresh.mantraGained,1)
 A.applyPower(fresh,fresh.enemies[1],'poison',3,fresh.player);eq(fresh.enemies[1].statuses.poison,4)
end)
test('mid-combat external acquire updates ownership without an invented equip effect',function()
 local r,s=run('silent');assert(R.obtainRelic(r,'vajra'));s=r.combat;assert(not H.owns(s,'vajra'),'unrelated snapshot ABI is unchanged')
 assert(R.obtainRelic(r,'data_disk'));s=r.combat;eq(s.player.statuses.focus,nil)
 assert(R.obtainRelic(r,'damaru'));s=r.combat;eq(s.player.statuses.mantra,nil)
 assert(R.obtainRelic(r,'snake_skull'));s=r.combat;A.applyPower(s,s.enemies[1],'poison',3,s.player);eq(s.enemies[1].statuses.poison,4)
 assert(R.endTurn(r));eq(s.player.statuses.mantra,1);eq(s.player.statuses.focus,nil)
 local fresh=nextBattle(r);eq(fresh.player.statuses.focus,1);eq(fresh.player.statuses.mantra,1)
end)
assert(failed==0,tostring(failed)..' class common lifecycle cases failed')
print('CLASS_COMMON_RELIC_LIFECYCLE_PASS '..count)
