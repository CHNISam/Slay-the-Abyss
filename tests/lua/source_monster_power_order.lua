-- Behavioral port tests against actual actor/constructor paths, sts@319009d5.
local C,A,D=require('abyss_combat'),require('abyss_actor'),require('abyss_data')
local O,G=require('abyss_power_order'),require('abyss_guardian_ai')
local Events=require('abyss_events')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function battle(id)return C.new(D,{enemies={id or 'cultist'},deck={},seed=42,hp=500,maxHp=500})end
local function ids(e)local out={};for _,p in ipairs(A.statusView(e))do out[#out+1]=p.id end;return table.concat(out,',')end
local function order(e)return table.concat(e.powerOrder or {},',')end

test('constructor append is unsorted; new action stably sorts by source priority',function()
 local s=battle();local e=s.enemies[1]
 A.addStatus(e,'weak',2);A.addStatus(e,'strength',1)
 eq(order(e),'weak,strength');eq(ids(e),'weak,strength')
 A.applyPower(s,e,'frail',2,s.player)
 eq(order(e),'strength,frail,weak');eq(ids(e),order(e))
end)
test('equal priority preserves actual list position not lexical IDs',function()
 local s=battle();local e=s.enemies[1]
 A.applyPower(s,e,'strength',1,e);A.applyPower(s,e,'artifact',1,e)
 eq(order(e),'strength,artifact')
 A.applyPower(s,e,'strength',1,e);eq(order(e),'strength,artifact')
 require('abyss_power_schedule').remove(s,e,'strength');e.statuses.strength=nil
 A.applyPower(s,e,'strength',1,e);eq(order(e),'artifact,strength')
end)
test('stack retains even a deliberately unsorted constructor list',function()
 local s=battle();local e=s.enemies[1]
 A.addStatus(e,'weak',2);A.addStatus(e,'strength',1)
 A.applyPower(s,e,'weak',1,s.player);eq(order(e),'weak,strength')
end)
test('negative Strength is visible; stack-zero removes and later reacquires',function()
 local s=battle();local e=s.enemies[1]
 A.applyPower(s,e,'strength',-2,s.player);A.applyPower(s,e,'thorns',1,e)
 local row=A.statusView(e)[1];eq(row.amount,-2);eq(row.canGoNegative,true);eq(row.isTurnBased,false)
 A.applyPower(s,e,'strength',2,e);eq(ids(e),'thorns')
 A.applyPower(s,e,'strength',1,e);eq(ids(e),'thorns,strength')
end)
test('a NEW zero Power is not confused with an expired zero sentinel',function()
 local s=battle();local e=s.enemies[1]
 A.applyPower(s,e,'strength',0,e);eq(ids(e),'strength');eq(A.statusView(e)[1].amount,0)
 A.applyPower(s,e,'strength',1,e);eq(ids(e),'strength')
 A.applyPower(s,e,'strength',-1,e);eq(ids(e),'')
 A.applyPower(s,e,'strength',0,e);eq(ids(e),'strength') -- New object after zero sentinel.
end)
test('Artifact blocked debuff creates no membership; consumed Artifact disappears',function()
 local s=battle();local e=s.enemies[1]
 A.applyPower(s,e,'artifact',1,e);eq(ids(e),'artifact')
 eq(A.applyPower(s,e,'weak',2,s.player),false);eq(ids(e),'');eq(e.statuses.weak,nil)
 A.applyPower(s,e,'weak',2,s.player);eq(ids(e),'weak')
end)
test('round-decay removes only its membership and reapplies at source priority',function()
 local s=battle();local e=s.enemies[1]
 A.applyPower(s,e,'weak',1,s.player);A.applyPower(s,e,'thorns',1,e)
 A.endRound(s,e);eq(ids(e),'thorns');eq(e.statuses.weak,0)
 A.applyPower(s,e,'weak',1,s.player);eq(ids(e),'thorns,weak')
end)
test('Guardian retains zero ModeShift until queued phase-removal boundary',function()
 local s=battle('guardian');local e=s.enemies[1]
 eq(ids(e),'mode_shift');local before=e.hp;e.hp=e.hp-e.aiThreshold
 G.hpLost(s,e,before);eq(e.statuses.mode_shift,0);eq(ids(e),'mode_shift')
 G.flush(s,e);eq(ids(e),'')
 A.applyPower(s,e,'sharp_hide',3,e);eq(ids(e),'sharp_hide')
 e.aiReturning=true;G.afterEffects(s,e);eq(ids(e),'mode_shift')
end)
test('Guardian source damage can make ModeShift negative before removal',function()
 local s=battle('guardian');local e=s.enemies[1];local before=e.hp;e.hp=e.hp-e.aiThreshold-2
 G.hpLost(s,e,before);eq(e.statuses.mode_shift,-2);eq(ids(e),'mode_shift')
 eq(A.statusView(e)[1].canGoNegative,false)
 G.flush(s,e);eq(ids(e),'')
end)
test('Flight removal/regrant follows list lifecycle, no displayed zero sentinel',function()
 local s=battle('byrd');local e=s.enemies[1];eq(ids(e),'flight')
 for _=1,3 do C.damage(s,s.player,e,2)end
 eq(e.statuses.flight,0);eq(ids(e),'')
 A.applyPower(s,e,'flight',3,e);eq(ids(e),'flight')
 for _,event in ipairs(s.events)do
  if event.kind=='status'and event.detail.status=='flight'and event.detail.amount==-1 then
   local framed=event.frame.enemies[1]
   if framed.statuses.flight==0 then eq(ids(framed),'')end
  end
 end
end)
test('large slime and boss constructor directly append original Split sentinel',function()
 for _,id in ipairs({'acid_slime_l','spike_slime_l','slime_boss'})do
  local s=battle(id);local e=s.enemies[1];eq(e.statuses.split,-1);eq(ids(e),'split')
  local row=A.statusView(e)[1];eq(row.sourceAmount,-1);eq(row.canGoNegative,false);eq(row.isTurnBased,false)
 end
 for _,id in ipairs({'acid_slime_m','spike_slime_m','acid_slime_s','spike_slime_s'})do eq(ids(battle(id).enemies[1]),'')end
end)
test('source constructor overload appends carried Poison after Split without sorting',function()
 local s=battle('acid_slime_l');local e=s.enemies[1]
 -- Explicit constructor overload only: natural source split calls pass poison=0.
 A.addStatus(e,'poison',4);eq(ids(e),'split,poison')
 A.applyPower(s,e,'weak',1,s.player);eq(ids(e),'split,poison,weak')
end)
test('real split does not invent inherited poison or change child Split membership',function()
 local s=battle('slime_boss');local parent=s.enemies[1]
 C.damage(s,s.player,parent,math.ceil(parent.maxHp/2),true)
 assert(C.endTurn(s));local children=0
 for _,e in ipairs(s.enemies)do if e~=parent then children=children+1;eq(ids(e),'split');eq(e.statuses.poison,nil)end end
 eq(children,2)
end)
test('read is pure and copy-on-write keeps captured event power lists immutable',function()
 local s=battle();local e=s.enemies[1];A.applyPower(s,e,'weak',2,s.player)
 local frame=Events.frame(s);local old=frame.enemies[1].powerOrder
 A.applyPower(s,e,'strength',1,e);eq(table.concat(old,','),'weak');eq(ids(frame.enemies[1]),'weak')
 local live=e.powerOrder;local rows=A.statusView(e);rows[1].amount=999;eq(e.powerOrder,live);eq(e.statuses.strength,1)
end)
test('player list and display contract remain outside enemy migration',function()
 local s=battle();A.applyPower(s,s.player,'weak',2,s.player);A.applyPower(s,s.player,'strength',1,s.player)
 eq(order(s.player),'weak,strength');eq(ids(s.player),'strength,weak');eq(A.statusView(s.player)[1].canGoNegative,nil)
end)
test('unknown raw monster history is refused, never alphabetically invented',function()
 local s=battle();local e=s.enemies[1];e.statuses.thorns=2
 local ok,why=pcall(A.statusView,e);eq(ok,false);assert(tostring(why):find('missing source order',1,true))
end)
test('source sentinel flag mappings do not manufacture positive counters',function()
 local s=battle('spheric_guardian');local e=s.enemies[1]
 eq(ids(e),'barricade,artifact');local p=A.statusView(e)[1];eq(p.amount,1);eq(p.sourceAmount,-1)
 local row=O.sourceFacts.poison;eq(row.isTurnBased,true);eq(row.canGoNegative,false)
 eq(O.sourceFacts.weak.priority,99);eq(O.sourceFacts.frail.priority,10)
end)
test('specialized enemy Focus path records creation and zero-stack removal',function()
 local s=battle();local e=s.enemies[1]
 A.applyPower(s,e,'focus',-1,s.player);eq(ids(e),'focus')
 A.applyPower(s,e,'focus',1,e);eq(ids(e),'');eq(e.statuses.focus,nil)
end)
test('Lock On direct expiry removes position before source-priority reacquisition',function()
 local Engine=require('abyss_defect_engine_cards')
 local s=C.new(Engine.withCards(D),{enemies={'cultist'},deck={},seed=42});local e=s.enemies[1]
 Engine.applyLockOn(s,e,1);A.applyPower(s,e,'strength',1,e)
 Engine.endRound(s);eq(ids(e),'strength');eq(e.statuses.lock_on,nil)
 Engine.applyLockOn(s,e,1);eq(ids(e),'strength,lock_on')
end)
test('real incoming card debuffs use verified source priorities and amount flags',function()
 local Silent=require('abyss_silent_tactics_cards');local Watcher=require('abyss_watcher_flow_cards')
 for _,entry in ipairs({{Silent.withCardDefinitions(D),'choked'}, {Watcher.withCards(D),'mark'}, {Watcher.withCards(D),'block_return'}})do
  local s=C.new(entry[1],{enemies={'cultist'},deck={},seed=42});local e=s.enemies[1]
  A.applyPower(s,e,'weak',1,s.player);A.applyPower(s,e,entry[2],2,s.player)
  eq(ids(e),entry[2]..',weak')
  local row=A.statusView(e)[1];eq(row.canGoNegative,false);eq(row.isTurnBased,false);eq(row.sourceVerified,true)
 end
end)
print('SOURCE_MONSTER_POWER_ORDER '..count..' groups passed')
