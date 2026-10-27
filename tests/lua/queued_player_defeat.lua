-- Player death opens the death screen before the next queued action.
-- This differs from victory's selective clearPostCombatActions filter.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Data=require('abyss_combat'),require('abyss_data')
local passed,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why)))end
local function battle(id)return C.new(Data,{enemies={id},deck={'defend'},seed=42})end
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end;error('missing '..id)end
for _,id in ipairs({'spike_slime_m','spike_slime_l','acid_slime_m'})do
 test(id..' lethal attack stops temporary-card creation and subsequent roll',function()
  local s=battle(id);force(s.enemies[1],id..'_1');s.player.hp=1;local uid,seed=s.nextUid,s.seed;s.events={}
  assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.player.hp,0);eq(s.nextUid,uid);eq(s.seed,seed);eq(#s.draw,0);eq(#s.hand,0);eq(#s.discard,1)
  for _,event in ipairs(s.events)do assert(event.kind~='cards_created' and event.kind~='reshuffle' and event.kind~='player_turn','post-defeat event '..event.kind)end
 end)
end
test('real Jaw Thrash stops queued self Block on player death',function()
 local s=battle('jaw_worm');force(s.enemies[1],'jaw_worm_2');s.player.hp=1;assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.enemies[1].block,0)
end)
test('player defeat preserves prior effects but stops every subsequent action including Block',function()
 local s=battle('cultist');local e=s.enemies[1];s.player.hp=1;local uid=s.nextUid
 C.applyEffects(s,{{op='gainStatus',status='strength',value=2},{op='damage',value=1},{op='block',value=7},
  {op='gainStatus',status='strength',value=3},{op='makeTempCardInDiscard',card='dazed',value=1},{op='energy',value=2}},e,s.player)
 eq(C.outcome(s),'defeat');eq(e.statuses.strength,2);eq(e.block,0);eq(s.nextUid,uid);eq(s.energy,3)
end)
test('nonlethal enemy attack retains its queued payload and fixed Block',function()
 local s=battle('cultist');local e=s.enemies[1]
 C.applyEffects(s,{{op='damage',value=1},{op='block',value=7},{op='makeTempCardInDiscard',card='slimed',value=2}},e,s.player)
 eq(s.player.hp,79);eq(e.block,7);eq(#s.discard,2);eq(C.outcome(s),nil)
end)
test('victory still retains Block while clearing status-card tail',function()
 local s=battle('cultist');local e=s.enemies[1];e.hp=1
 C.applyEffects(s,{{op='damage',value=6},{op='block',value=7},{op='makeTempCardInDiscard',card='slimed',value=2}},s.player,e)
 eq(C.outcome(s),'victory');eq(s.player.block,7);eq(#s.discard,0)
end)
test('lethal enemy attack opens death screen before queued player Thorns and later payload',function()
 local s=battle('spike_slime_m');force(s.enemies[1],'spike_slime_m_1');s.player.hp=1;s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1)
 -- ThornsPower.onAttacked adds a TOP DamageAction; it is not synchronous.
 -- AbstractPlayer.damage opens DeathScreen before returning to DamageAction,
 -- and AbstractRoom.update stops advancing the manager while isScreenUp.
 local uid=s.nextUid;s.events={};assert(C.endTurn(s));eq(s.player.hp,0);eq(s.enemies[1].hp,1);eq(s.phase,'defeat');eq(s.nextUid,uid)
 for _,event in ipairs(s.events)do
  assert(not(event.kind=='status_damage'and event.detail.status=='thorns'),'queued Thorns executed after defeat')
  assert(event.kind~='cards_created'and event.kind~='player_turn','post-defeat payload '..event.kind)
 end
end)
test('simultaneous death keeps defeat priority and stops later payload',function()
 local s=C.new(Data,{enemies={'spike_slime_m'},deck={'strike'},seed=42})
 local e=s.enemies[1];s.player.hp=1;e.hp=1;C.addStatus(e,'thorns',1)
 -- Killing the final monster retains its queued DAMAGE-typed Thorns action.
 -- That action can then kill the player; defeat still wins over victory,
 -- and the later UseCardAction must not discard the card after death.
 local uid=s.nextUid
 assert(C.play(s,s.hand[1].uid,1))
 eq(s.player.hp,0);eq(e.hp,0);eq(C.outcome(s),'defeat');eq(s.phase,'defeat');eq(s.nextUid,uid)
 eq(s.player.block,0);eq(#s.discard,0)
end)
print(passed..' defeat queue groups passed; '..failed..' failed');assert(failed==0)
