local C=require('abyss_combat')
local D=require('abyss_data')
local View=require('abyss_battle_intent_view')
local function force(e,id)for i,v in ipairs(e.intents)do if v.id==id then e.intentIndex=i;return end end;error(id)end
local function has(text,part)assert(text:find(part,1,true),text..' missing '..part)end
local function battle(ids)return C.new(D,{enemies=ids,deck={},seed=42,hp=500,maxHp=500})end
local slime=battle({'slime_boss'});local boss=slime.enemies[1]
C.damage(slime,slime.player,boss,80,true)
local split=View.intentView(slime,1)
assert(split.label=='分裂' and split.kind=='unknown')
has(split.text,slime.catalog.enemies.spike_slime_l.name)
has(split.text,slime.catalog.enemies.acid_slime_l.name)
has(split.text,'当前生命')
local hex=battle({'hexaghost'});local ghost=hex.enemies[1]
local activate=View.intentView(hex,1);assert(activate.label=='未知' and activate.kind=='unknown')
force(ghost,'inferno');ghost.statuses.strength=2
local inferno=View.intentView(hex,1)
has(inferno.text,'灼伤');has(inferno.text,'3张');has(inferno.text,'弃牌堆');assert(#inferno.rows==2)
assert(C.endTurn(hex));local sear=View.intentView(hex,1);has(sear.text,'+')
local pair=battle({'deca','donu'});force(pair.enemies[1],'square')
local defend=View.intentView(pair,1)
has(defend.text,'全体');has(defend.text,'16')
local circle=View.intentView(pair,2);has(circle.text,'全体');has(circle.text,'3')

-- Real generated battle controls must open the mixed split tooltip and keep
-- both new actors targetable, with no nil single-child metadata assumption.
local H=dofile('tests/lua/support/battle_action_fixture.lua')
local host,ui,panel,_,tap,drain=H.setup({'strike'},{'slime_boss'})
local s=host.run.combat;local parent=s.enemies[1]
C.damage(s,s.player,parent,80,true);host:refresh()
assert(panel:GetChild('enemy1'):GetChild('intentIcon').visible)
assert(panel:GetChild('enemy1'):GetChild('intentIcon').imageId==H.F.Theme.icon.intent.unknown)
tap('enemy1',31)
has(panel:GetChild('notice').text,s.catalog.enemies.spike_slime_l.name)
has(panel:GetChild('notice').text,s.catalog.enemies.acid_slime_l.name)
tap('endTurn',32);drain()
assert(#s.enemies==3 and s.enemies[2]==parent and parent.hp==0)
local left,right=panel:GetChild('enemy1'),panel:GetChild('enemy2')
assert(left.visible and right.visible)
assert(left:GetChild('name').text==s.catalog.enemies.spike_slime_l.name)
assert(right:GetChild('name').text==s.catalog.enemies.acid_slime_l.name)
local hp=s.enemies[3].hp
tap('card1',33);tap('enemy2',34);drain()
assert(s.enemies[3].hp==hp-6 and s.enemies[1].hp==60)
assert(ui.active and not ui.busy)
print('BOSSES_INTENT_UI_PASS unknown/mixed-split/burn-upgrade/group-block/real-controls/child-target')
