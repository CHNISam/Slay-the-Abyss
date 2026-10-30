package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local Effects=require('abyss_effects')
local Curses=require('abyss_curses')
local Colorless=require('abyss_colorless_cards')
local Final=require('abyss_watcher_final_cards')
local Original=require('abyss_original_v4')
local Watcher=require('abyss_watcher_attack_cards')
local card,flags,log
local function mark(x)log[#log+1]=x end
C.cardDefinition=function(_,c)mark('definition:'..c.uid);return c.uid==2 and {type='skill'}or card end
Curses.limitsPlay=function()mark('normality');return flags.normality end
Effects.supported=function()mark('effects');return not flags.effects,'bad_op' end
Final.supported=function()mark('watcher_content');return not flags.final end
Colorless.canUse=function()mark('colorless');return not flags.colorless,'colorless_refusal' end
Original.preflight=function()mark('original');return not flags.original,'original_refusal' end
Watcher.canUse=function()mark('watcher_requirement');return not flags.watcher,'watcher_refusal' end
local count=0
local function base()
    card={id='test',type='attack',cost=1,effects={{op='block',value=1}}}
    flags={};log={}
    return {phase='player',energy=3,player={statuses={}},hand={{uid=1},{uid=2}},draw={},enemies={{id='enemy',hp=10,statuses={}}}}
end
local function check(name,configure,reason,target,uid)
    local s=base();configure(s)
    local ok,why=C.canPlay(s,uid or 1,target)
    assert(ok==(reason==nil)and why==reason,'[CAN_PLAY_CONTRACT] '..name..': '..tostring(ok)..'/'..tostring(why)..' expected '..tostring(reason))
    count=count+1
    if ABYSS_CAN_PLAY_TRACE then print('CAN_PLAY_TRACE '..name..'|'..tostring(ok)..'|'..tostring(why)..'|'..table.concat(log,','))end
end
local pending={'pendingChoice','cardActions','pendingPlay','pendingScry','pendingHandChoice','pendingPileChoice','actionQueue','pendingDiscard'}
for i,key in ipairs(pending)do
    check('pending '..key,function(s)
        for j=i,#pending do s[pending[j]]={}end
        s.phase='enemy';card.cost=-2;flags.normality=true;s.player.statuses.entangled=1
    end,i<=2 and 'card_choice_pending'or i<=7 and 'selection_pending'or'discard_choice_pending')
end
check('turn before lookup',function(s)s.phase='enemy';s.hand={}end,'not_player_turn')
check('missing before definition',function(s)s.hand={}end,'card_not_in_hand')
check('unplayable before normality',function(s)card.cost=-2;flags.normality=true;s.player.statuses.entangled=1;flags.effects=true end,'unplayable_card')
check('normality before entangled',function(s)flags.normality=true;s.player.statuses.entangled=1;flags.effects=true end,'normality_limit')
check('entangled before effects',function(s)s.player.statuses.entangled=1;flags.effects=true end,'entangled')
check('effects before content',function()flags.effects=true;card.watcherFinal=true;flags.final=true end,'unsupported_effect:bad_op')
check('watcher content before colorless',function()card.watcherFinal=true;flags.final=true;flags.colorless=true end,'card_content_unavailable')
check('colorless before target',function()flags.colorless=true;card.color='colorless';card.target='ENEMY'end,'colorless_refusal')
check('colorless target before mode',function()card.color='colorless';card.target='ENEMY';card.condition='unknown'end,'invalid_target')
check('advanced before energy',function(s)card.condition='unknown';s.energy=0 end,'advanced_card_not_enabled')
check('bad condition experimental',function()card.condition='unknown';card.experimental=true end,'advanced_card_not_enabled')
check('bad mode experimental',function()card.costMode='bad';card.experimental=true end,'advanced_card_not_enabled')
check('bad X cost',function()card.costMode='all_energy';card.cost=1;card.experimental=true end,'advanced_card_not_enabled')
for _,energy in ipairs({-1,0.5,2147483648,'3'})do
    check('invalid X energy '..energy,function(s)card.costMode='all_energy';card.cost=-1;card.experimental=true;s.energy=energy;card.effects={{op='damage'}}end,'invalid_energy')
end
check('energy before target',function(s)s.energy=0;card.effects={{op='damage'}}end,'insufficient_energy')
local targets={'damage','damageEqualToBlock','applyStatus','multiplyPoison','barrageDamage','ftlDamage','bowlingBash','spotWeakness','heelHook','fiendFire','sunderDamage','removeBlock','applyLockOn','fearNoEvil','wallop','flowDamage','applyWatcherFlowPower','finisherDamage','flechettesDamage','skewer','glassKnife','malaise','feed','watcherFinalJudgment','watcherFinalExpungerHits','watcherFinalLessonLearned'}
for _,op in ipairs(targets)do
    check('target '..op,function()card.effects={{op='block'},{op=op}};card.originalV4=true;flags.original=true end,'invalid_target')
    check('live target '..op,function()card.effects={{op=op}}end,nil,1)
end
for _,op in ipairs({'damageAll','block','draw','heal','energy','unknown'})do check('untargeted '..op,function()card.effects={{op=op}}end)end
check('original before watcher',function()card.originalV4=true;flags.original=true;flags.watcher=true;card.experimental=true;card.condition='draw_pile_empty'end,'original_refusal')
check('watcher before hand',function(s)flags.watcher=true;card.experimental=true;card.condition='draw_pile_empty';s.draw={{uid=3}}end,'watcher_refusal')
check('draw requirement',function(s)card.experimental=true;card.condition='draw_pile_empty';s.draw={{uid=3}}end,'requires_empty_draw_pile')
check('hand requirement',function()card.experimental=true;card.condition='only_attacks_in_hand'end,'requires_only_attacks')
check('slimed exact empty shape',function()card={id='slimed',type='status',cost=1,exhaust=true,effects={}}end)
for _,field in ipairs({'ethereal','costMode','condition','upgrade'})do
    check('slimed invalid '..field,function()card={id='slimed',type='status',cost=1,exhaust=true,effects={}};card[field]=true end,'unsupported_effect:invalid_empty_status')
end
print('LUA_CAN_PLAY_CONTRACT_PASS '..count)
