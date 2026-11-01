local C,V=require('abyss_combat'),require('abyss_battle_intent_view')
local I,D=require('abyss_monster_source_intents'),require('abyss_monster_displayed_intent')
local E=require('abyss_events')
local s=C.new(require('abyss_data'),{deck={'defend'},enemies={'fat_gremlin'},seed=42})
local function same(a,b)
 assert(type(a)==type(b))
 if type(a)~='table'then assert(a==b);return end
 for key,value in pairs(a)do same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil)end
end
local cases=SOURCE_DESCRIPTOR_CASES
if not cases then
 cases={}
 for id,definition in pairs(s.catalog.enemies)do
  if I.hasDefinition({definitionId=id})then
   for _,move in ipairs(definition.intents)do cases[#cases+1]={id,move.id,I.enum({definitionId=id},move)}end
  end
 end
end
local attacks,ops=0,{}
for _,row in ipairs(cases)do
 local definition=assert(s.catalog.enemies[row[1]],row[1])
 local index;for at,move in ipairs(definition.intents)do if move.id==row[2]then index=at end end
 assert(index,row[1]..'/'..row[2])
 local actor={id='source-case',definitionId=row[1],hp=1,statuses={},intents=definition.intents,intentIndex=index}
 local state={enemies={actor}}
 local before=C.copy(actor)
 local descriptor=V.selectedDescriptor(state,1)
 assert(descriptor.id==row[2] and descriptor.intent==row[3],row[1]..'/'..row[2])
 if row[3]:sub(1,6)=='ATTACK'then
  attacks=attacks+1
  local raw
  for _,effect in ipairs(definition.intents[index].effects)do
   if effect.op=='damage' or effect.op=='damageAll' or effect.op=='enemyVampireDamage'then raw=effect;break end
  end
  assert(raw,'pinned source attack needs audited damage metadata')
  ops[raw.op]=true
  assert(descriptor.baseDamage==raw.value and descriptor.multiplier==(raw.times or 1))
 else assert(descriptor.baseDamage==-1)end
 same(actor,before)
end
assert(attacks>0 and ops.damage and ops.enemyVampireDamage,'ordinary and vampire source attacks both covered')
-- Artifact depletion can make a FUTURE Weak application invalid. Reading the
-- current selected world base must succeed; the ordered tooltip must still fail.
local actor=s.enemies[1]
s.player.statuses.weak=2147483647;s.player.statuses.artifact=0
local before=E.frame(s);local events=s.events
local descriptor=V.selectedDescriptor(s,1)
assert(descriptor.baseDamage==4)
local displayed=D.new()
D.createIntent(displayed,descriptor,function(base)return C.intentAttackAmount(s,actor,s.player,base)end)
assert(D.face(displayed).value=='4')
local ok,why=pcall(V.intentView,s,1)
assert(not ok and tostring(why):find('status stack overflow',1,true),'ordered tooltip must still reject real overflow')
same(E.frame(s),before);assert(s.events==events)
-- Synthetic legal metadata keeps the next self buff in the tooltip only.
s.player.statuses.weak=0
actor.intents={{id='fat_gremlin_1',kind='attack',effects={{op='gainStatus',status='strength',value=2},{op='damage',value=10}}}}
actor.intentIndex=1
local selected=V.selectedDescriptor(s,1)
assert(selected.baseDamage==10 and V.intentView(s,1).value=='12')
actor.intents[1].id='foreign-move'
assert(not pcall(V.selectedDescriptor,s,1),'unknown source move cannot acquire display metadata')
print('SOURCE_INTENT_DESCRIPTOR_PASS '..#cases)

-- Recovery catches up real callbacks, without status-hash refresh inference.
local View=require('abyss_monster_intent_particle_view')
local view=View.new({},function()end,function()end)
local row={id='probe',actor={},index=1}
local battle={events={}}
local move={id='probe',intent='ATTACK',baseDamage=10,multiplier=1,isMultiDamage=false,face={kind='attack',rows={}}}
local strength,calls=0,0
local function calculate(base)calls=calls+1;return base+strength end
local function shown()return view:face('probe',view:needsSelected('probe')and move or nil,calculate).value end
view:sync({row},battle,nil,true);assert(shown()=='10')
strength=2
local raw={kind='status',detail={status='strength'}};battle.events={raw}
view:sync({row},battle,raw,true);view:reconcile(battle)
assert(shown()=='10','raw mutation/recovery cannot invent a source callback')
local source={kind='status',detail={},sourceIntentPowers={scope='all-monsters'}}
battle.events[#battle.events+1]=source
assert(view:reconcile(battle) and shown()=='12','unseen committed applyPowers must survive cancellation')
local count=calls;view:reconcile(battle);assert(shown()=='12'and calls==count,'seen callbacks cannot repeat source calculation')
local nextBattle={events={source}}
strength=4;view:sync({row},nextBattle,nil,true);assert(shown()=='14')
strength=5
assert(not view:reconcile(battle),'old battle cannot write current displayed state')
assert(view:reconcile(nextBattle)and shown()=='15','event identities are scoped to their battle')
nextBattle.events={{kind='status',sourceIntentPowers={scope='foreign'}}}
assert(not pcall(view.reconcile,view,nextBattle),'unknown source callback scope must remain an error')
