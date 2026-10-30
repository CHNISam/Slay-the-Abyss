local R=require('abyss_rare_relics')
local C=require('abyss_combat')
local A=require('abyss_actor')
local S=require('abyss_sts_random')
local data=require('abyss_data')
local function battle(relics)
 local s=C.new(data,{seed=19,deck={'strike','defend'},enemies={'cultist'},hp=40})
 s.relics=relics;s.relicCounters={};R.bindBattle(s)
 return s
end
local function flush(s)
 while #s.cardActions>0 do
  local item=table.remove(s.cardActions,1)
  if not R.applyEffect(C,s,item.effect)then C.applyEffects(s,{item.effect},item.source or s.player,item.target)end
 end
end
local s=battle({'thread_and_needle','girya','du_vu_doll','incense_burner','captains_wheel','stone_calendar'})
s.cardActions={};s.relicCounters.girya=2;s.relicCounters.du_vu_doll=1;s.relicCounters.incense_burner=5
for _,id in ipairs(s.relics)do R.battleStart(s,id)end
flush(s);assert(s.player.statuses.plated_armor==4 and s.player.statuses.strength==3)
R.atTurnStart(s);flush(s);assert(s.player.statuses.intangible==1 and s.relicCounters.incense_burner==0)
R.atTurnStart(s);R.atTurnStart(s);flush(s);assert(s.player.block==18)
for _=4,7 do R.atTurnStart(s)end
local hp=s.enemies[1].hp;R.onPlayerEndTurn(s);flush(s);assert(s.enemies[1].hp==math.max(0,hp-52))
R.onVictory(s);assert(s.relicCounters.stone_calendar==-1 and s.relicCounters.captains_wheel==-1)
s=battle({'ginger','turnip','torii','calipers','ice_cream','magic_flower'})
assert(R.blockPower(s,s.player,'weak')and R.blockPower(s,s.player,'frail'))
assert(not R.blockPower(s,s.enemies[1],'weak'))
assert(R.onAttacked(s,s.enemies[1],'normal',5)==1 and R.onAttacked(s,nil,'normal',5)==5)
assert(R.onAttacked(s,s.enemies[1],'thorns',5)==5 and R.onAttacked(s,s.enemies[1],'normal',6)==6)
assert(R.blockAtTurnStart(s,31)==16 and R.blockAtTurnStart(s,8)==0)
s.energy=2;assert(R.rechargeEnergy(s,3)==5)
assert(R.modifyHealing(s,3,true)==5 and R.modifyHealing(s,3,false)==3)
s=battle({'pocketwatch','bird_faced_urn','champion_belt'})
s.cardActions={};R.postDraw(s);assert(#s.cardActions==0)
R.onPlayCard(s);R.onPlayCard(s);R.onPlayCard(s);R.postDraw(s)
assert(#s.cardActions==1 and s.cardActions[1].effect.value==3);s.cardActions={}
for _=1,4 do R.onPlayCard(s)end
R.postDraw(s);assert(#s.cardActions==0)
R.onUseCard(s,{type='power'});flush(s);assert(s.player.hp==42)
R.onVulnerableApplied(s,s.enemies[1]);flush(s);assert(s.enemies[1].statuses.weak==1)
s=battle({'dead_branch','charons_ashes'})
s.cardActions={};s.cardRandomRng=S.fromSeed('17')
local before=S.snapshot(s.cardRandomRng).counter;local hp=s.enemies[1].hp
R.onExhaust(s);assert(S.snapshot(s.cardRandomRng).counter==before+1)
assert(s.cardActions[1].effect.op=='rareRelicDamageAll'and s.cardActions[2].effect.op=='rareRelicGenerate')
local n=#s.hand;flush(s);assert(s.enemies[1].hp==hp-3 and #s.hand==n+1)
s=battle({'unceasing_top'});s.cardActions={};s.hand={};s.phase='player';s.draw={{uid=80,cardId='strike',upgraded=false}}
R.atTurnStart(s);assert(R.onRefreshHand(s,true));s.cardActions={}
s.player.noDraw=true;assert(not R.onRefreshHand(s,true));s.player.noDraw=false
R.disableTop(s);assert(not R.onRefreshHand(s,true));R.atTurnStart(s);assert(R.onRefreshHand(s,true))
R.onPlayerEndTurn(s);assert(not R.onRefreshHand(s,true))
s=battle({'gambling_chip'});s.cardActions={};s.phase='player'
s.hand={{uid=90,cardId='strike',upgraded=false},{uid=91,cardId='defend',upgraded=false}}
s.draw={{uid=92,cardId='strike',upgraded=false}};s.discard={}
R.postDraw(s);flush(s);local token=s.pendingChoice.token
assert(not R.chooseGambling(C,s,{90,90},token));assert(#s.hand==2)
assert(R.chooseGambling(C,s,{90},token));flush(s);assert(#s.hand==2 and s.discard[1].uid==90)
assert(not R.chooseGambling(C,s,{},token))
s.cardActions={};R.postDraw(s);assert(#s.cardActions==0)
local run={relics={'Girya','WingedGreaves','Du-Vu Doll','Prayer Wheel','Shovel','Peace Pipe'},
 data={cards={cards={{id='curse',type='curse'},{id='attack',type='attack'}}}},deck={{cardId='curse'},{cardId='attack'}}}
for _,id in ipairs(run.relics)do R.onEquip(run,id)end
assert(run.relicCounters.du_vu_doll==1 and run.relicCounters.girya==0)
for _=1,3 do assert(R.lift(run))end
assert(not R.lift(run));assert(#R.campOptions(run,true)==3)
for _=1,3 do assert(R.useWingedTravel(run))end
assert(run.relicCounters.winged_greaves==-2 and not R.canWingedTravel(run))
assert(R.extraCardRewards(run,true)==1 and R.extraCardRewards(run,false)==0)
table.remove(run.deck,1);R.onMasterDeckChange(run);assert(run.relicCounters.du_vu_doll==0)
print('RARE_RELICS_HOOKS_PASS')
