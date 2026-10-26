-- Frozen V4 orchestration on the existing actors, native queue and pile ownership.
local Actors=require('abyss_actor')
local Events=require('abyss_events')
local Health=require('abyss_original_v4_health')
local M={}
local ops={absorb=true,block=true,block_spent=true,bloom=true,bonus=true,cash_bloom=true,cleanse=true,counter=true,
    damage=true,damage_spent=true,directive=true,draw=true,end_infuse=true,eye=true,eye_pulse=true,heal=true,heal_spent=true,
    infuse=true,mature=true,mode=true,musou=true,next_block=true,next_draw=true,next_energy=true,pay_hp=true,resolve=true,
    revelry=true,singer=true,soften=true,spend=true,summon=true,toggle=true,trigger=true,when=true}
local conditions={low=true,not_low=true,infused=true,bloom_target=true,has_bloom=true,enemy_low=true,bond0=true,bond1=true,
    bond2=true,bond4=true,not_bond4=true,directive_target=true,mature_target=true,has_directive=true,has_mature=true,
    ousia=true,pneuma=true,fan0=true,fan2=true,fan3=true,fan4=true,not_fan4=true,fan6=true,has_guest=true,has_singer=true,
    eye=true,musou=true,not_musou=true,resolve0=true,resolve2=true,resolve3=true,resolve4=true}
local function live(enemy)return Actors.isActive(enemy)end
local function active(value)return value.uses>0 and value.ends>0 end
local function integer(n)return type(n)=='number' and n>=0 and n%1==0 and n<=2147483647 end
local function validateEffects(effects)
    if type(effects)~='table' or #effects==0 then return false end
    local count=0;for k in pairs(effects)do if type(k)~='number' or k<1 or k%1~=0 then return false end;count=count+1 end
    if count~=#effects then return false end
    for _,e in ipairs(effects)do
        if type(e)~='table' or not ops[e.op] then return false end
        if e.op=='when' and (not conditions[e.condition] or not validateEffects(e.effects))then return false end
        if e.op=='spend' then
            if e.resource~='bond' and e.resource~='fan' and e.resource~='resolve' then return false end
            if e.n~='all' and not integer(e.n)then return false end
        elseif e.n~=nil and not integer(e.n)then return false end
        if e.target~=nil and e.target~='one' and e.target~='all'then return false end
        if e.hits~=nil and (not integer(e.hits) or e.hits==0)then return false end
        if e.coefficient~=nil and (type(e.coefficient)~='number' or e.coefficient<0 or e.coefficient~=e.coefficient)then return false end
    end
    return true
end
function M.supported(raw)
    if type(raw)~='table' or not ({HT=true,AR=true,FR=true,RD=true})[raw.role] then return false end
    if type(raw.requirements)~='table'then return false end
    for _,condition in ipairs(raw.requirements)do if not conditions[condition]then return false end end
    for _,key in ipairs({'base','upgrade'})do
        local version=raw[key]
        if type(version)~='table' or not integer(version.cost) or type(version.exhaust)~='boolean' or not validateEffects(version.effects)then return false end
    end
    return true
end
function M.init(state,role,rules)
    state.originalV4Rules=rules
    state.originalV4={role=role,healUsed=0,relicUsed=false,infuse=0,chargedUsed=0,bond=0,mode=rules.FR.initial_mode,
        fan=0,fanGained=0,guests={usher=0,chevalmarin=0,crabaletta=0},singer=0,revelry={uses=0,ends=0,bonus=0},
        resolve=0,resolveGained=0,eye={uses=0,ends=0},musou={uses=0,ends=0},musouRefunded=0,
        nextEnergy=0,nextDraw=0,nextBlock=0,bonus={n=0,tag='any'},counter=0,soften=0,commands={}}
end
local function selected(state,e,target)
    if e.target=='all'then
        local list={};for _,enemy in ipairs(state.enemies)do if live(enemy)then list[#list+1]=enemy end end;return list
    end
    return live(target) and {target} or {}
end
function M.snapshot(state,target)
    local v,p=state.originalV4,state.player
    local valid=live(target);local bloom=valid and target.v4Bloom;local directive=valid and target.v4Directive
    local s={low=2*p.hp<=p.maxHp,not_low=2*p.hp>p.maxHp,infused=v.infuse>0,bloom_target=bloom and bloom.ticks>0 or false,
        enemy_low=valid and 2*target.hp<=target.maxHp or false,bond0=v.bond==0,bond1=v.bond>=1,bond2=v.bond>=2,bond4=v.bond>=4,not_bond4=v.bond<4,
        directive_target=directive~=nil and directive~=false,mature_target=directive and directive.mature or false,
        has_bloom=false,has_directive=false,has_mature=false,ousia=v.mode=='ousia',pneuma=v.mode=='pneuma',fan0=v.fan==0,
        fan2=v.fan>=2,fan3=v.fan>=3,fan4=v.fan>=4,not_fan4=v.fan<4,fan6=v.fan>=6,has_guest=false,has_singer=v.singer>0,
        eye=active(v.eye),musou=active(v.musou),not_musou=not active(v.musou),resolve0=v.resolve==0,resolve2=v.resolve>=2,resolve3=v.resolve>=3,resolve4=v.resolve>=4}
    for _,enemy in ipairs(state.enemies)do if live(enemy)then
        s.has_bloom=s.has_bloom or enemy.v4Bloom~=nil and enemy.v4Bloom.ticks>0
        s.has_directive=s.has_directive or enemy.v4Directive~=nil
        s.has_mature=s.has_mature or enemy.v4Directive~=nil and enemy.v4Directive.mature
    end end
    for _,n in pairs(v.guests)do if n>0 then s.has_guest=true end end
    return s
end
local function direct(effects)
    for _,e in ipairs(effects)do if e.op=='damage' or e.op=='damage_spent' or e.op=='when' and direct(e.effects)then return true end end
    return false
end
local function needsTarget(effects)
    for _,e in ipairs(effects)do
        if e.target~='all' and (e.op=='damage' or e.op=='damage_spent' or e.op=='bloom' or e.op=='cash_bloom'
            or e.op=='directive' or e.op=='mature' or e.op=='absorb' or e.op=='eye_pulse')then return true end
        if e.op=='when' and (e.condition:match('_target$') or e.condition=='enemy_low' or needsTarget(e.effects))then return true end
    end
    return false
end
function M.needsTarget(state,card)
    if card.originalV4==nil then return card.target=='ENEMY'end
    local raw=card.originalV4;local effects=raw[card.originalV4Upgraded and 'upgrade' or 'base'].effects
    return needsTarget(effects) or state.originalV4 and state.originalV4.role=='HT' and raw.category=='charged'
        and state.originalV4.infuse>0 and state.originalV4.chargedUsed<state.originalV4Rules.HT.charged_eligible_cards_per_turn and direct(effects)
end
function M.preflight(state,card,targetIndex)
    if not state.originalV4 then return false,'original_role_required'end
    if not M.supported(card.originalV4)then return false,'unsupported_original_effect'end
    local target=state.enemies[targetIndex]
    if M.needsTarget(state,card) and not live(target)then return false,'invalid_target'end
    local snap=M.snapshot(state,target)
    for _,condition in ipairs(card.originalV4.requirements)do if not snap[condition]then return false,'requires_'..condition end end
    local cost=0
    for _,e in ipairs(card.originalV4[card.originalV4Upgraded and 'upgrade' or 'base'].effects)do if e.op=='pay_hp'then cost=cost+e.n end end
    -- Native Pain actions run before the using card's queued effects.
    for _,held in ipairs(state.hand)do if held.cardId=='pain' then
        cost=cost+(state.catalog.cards.pain.onOtherCardHpLoss or 0)
    end end
    if state.player.hp<=cost then return false,'insufficient_hp'end
    return true
end
function M.block(state,n,fixed)
    if state.player.hp>0 and math.min(999-state.player.block,Actors.blockAmount(state,state.player,n,fixed))>0 then
        local before=state.player.block;Actors.block(state,state.player,n,fixed)
        if state.originalV4Preview then state.originalV4Preview[#state.originalV4Preview+1]={op='block',low=state.player.block-before,high=state.player.block-before}end
    end
end
local function pay(combat,state,n)
    if n<=0 then return end
    assert(state.player.hp>n,'original_v4 insufficient hp')
    combat.applyEffects(state,{{op='loseHp',value=n}},state.player,state.player)
    local v=state.originalV4
    if v.role=='HT' and not v.relicUsed and state.player.hp>0 then v.relicUsed=true;M.block(state,4,true)end
end
local function bond(state,n,mature)
    local v=state.originalV4;v.bond=math.min(state.originalV4Rules.AR.bond_max,v.bond+n)
    if v.role=='AR' and mature and not v.relicUsed then v.relicUsed=true;M.block(state,3,true)end
end
function M.enemyDied(state,enemy,before)
    if not state.originalV4 or before<=0 or enemy.hp>0 or enemy==state.player then return end
    if state.originalV4.role=='AR' and enemy.v4Directive then enemy.v4Directive=nil;bond(state,state.originalV4Rules.AR.marked_target_death_gain,false)end
    enemy.v4Bloom=nil;enemy.v4Directive=nil
end
local function resolve(state,n)
    local v,r=state.originalV4,state.originalV4Rules.RD
    if v.role~='RD'then return end
    local gain=math.max(0,math.min(n,r.resolve_gain_per_turn_max-v.resolveGained,r.resolve_max-v.resolve))
    v.resolve=v.resolve+gain;v.resolveGained=v.resolveGained+gain
end
local function batch(combat,state,n,list,hits,ctx,extra,derived)
    if #list==0 or state.player.hp<=0 then return 0 end
    local v=state.originalV4;local bonus=0
    if active(v.revelry)then bonus=v.revelry.bonus;v.revelry.uses=v.revelry.uses-1 end
    local first,total=true,0
    local previous=state.resolvingEffects;state.resolvingEffects=true
    for _=1,hits do
        local reactions={}
        for _,enemy in ipairs(list)do if live(enemy) and state.player.hp>0 then
            local amount=n
            if first then amount=amount+bonus+(extra or 0);first=false end
            if ctx and not ctx.directSeen then amount=amount+ctx.firstBonus;ctx.directSeen=true end
            if state.originalV4Preview then
                local output=Actors.attackAmount(state,state.player,enemy,amount,derived)
                state.originalV4Preview[#state.originalV4Preview+1]={op=derived and 'derived' or 'damage',target=enemy.id,low=output,high=output}
            end
            total=total+combat.damage(state,state.player,enemy,amount,derived,reactions)
        end end
        Actors.resolveDamageReactions(state,reactions,combat.retaliate)
        if state.player.hp<=0 then break end
    end
    state.resolvingEffects=previous
    if not previous then
        local ai=require('abyss_enemy_ai');ai.afterEffects(state,state.player);ai.flush(state,state.player)
    end
    if ctx then ctx.actualDirect=ctx.actualDirect+total end
    return total
end
local function switch(combat,state,mode)
    local v=state.originalV4
    if v.mode==mode then return end
    v.mode=mode
    if v.role=='FR' and not v.relicUsed then v.relicUsed=true;combat.draw(state,1)end
end
local trigger
trigger=function(combat,state,member)
    local v,r=state.originalV4,state.originalV4Rules.FR
    local living=selected(state,{target='all'})
    if #living==0 or state.player.hp<=0 then return end
    if member=='all'then
        if v.mode=='ousia'then for _,name in ipairs(r.guest_order)do trigger(combat,state,name)end
        else trigger(combat,state,'singer')end
        return
    end
    if member=='singer'then
        if v.mode=='pneuma' and v.singer>0 then v.singer=v.singer-1;Health.heal(state,state.player,r.singer_heal,'singer')end
        return
    end
    if v.mode~='ousia' or (v.guests[member] or 0)<=0 then return end
    v.guests[member]=v.guests[member]-1
    local extra=0
    if 2*state.player.hp>state.player.maxHp and state.player.hp>1 then pay(combat,state,1);extra=1 end
    local targets=living
    if member~='chevalmarin'then
        local target=living[1]
        for _,enemy in ipairs(living)do
            if member=='usher' and enemy.hp>target.hp or member=='crabaletta' and enemy.hp<target.hp then target=enemy end
        end
        targets={target}
    end
    batch(combat,state,assert(r.guest_base_damage[member]),targets,1,nil,extra,true)
end
local apply
apply=function(combat,state,e,target,ctx)
    if state.player.hp<=0 then return end
    local v,r,n=state.originalV4,state.originalV4Rules,e.n or 0
    local op=e.op
    if op=='when'then
        assert(conditions[e.condition],'unknown original condition')
        if ctx.snapshot[e.condition]then for _,part in ipairs(e.effects)do apply(combat,state,part,target,ctx)end end
    elseif op=='pay_hp'then
        -- Mandatory payments were aggregated and paid before the only snapshot.
    elseif op=='damage' or op=='damage_spent'then
        batch(combat,state,n+(op=='damage_spent' and e.coefficient*ctx.spent or 0),selected(state,e,target),e.hits or 1,ctx,0,false)
    elseif op=='block' or op=='block_spent'then M.block(state,n+(op=='block_spent' and e.coefficient*ctx.spent or 0),false)
    elseif op=='heal' or op=='heal_spent'then Health.heal(state,state.player,n+(op=='heal_spent' and e.coefficient*ctx.spent or 0),ctx.tag)
    elseif op=='draw'then if not combat.outcome(state)then combat.draw(state,n)end
    elseif op=='next_block'then v.nextBlock=math.min(r.common.next_block_cap,v.nextBlock+n)
    elseif op=='next_draw'then v.nextDraw=math.min(r.common.next_draw_cap,v.nextDraw+n)
    elseif op=='next_energy'then v.nextEnergy=math.min(r.common.next_energy_cap,v.nextEnergy+n)
    elseif op=='infuse'then v.infuse=math.max(v.infuse,math.min(r.HT.window_end_phases,n))
    elseif op=='end_infuse'then v.infuse=0
    elseif op=='bloom'then
        for _,enemy in ipairs(selected(state,e,target))do local old=enemy.v4Bloom
            enemy.v4Bloom={strength=math.max(old and old.strength or 0,math.min(r.HT.bloom_max,n)),ticks=r.HT.bloom_ticks}
        end
    elseif op=='cash_bloom'then
        for _,enemy in ipairs(selected(state,e,target))do local b=enemy.v4Bloom;enemy.v4Bloom=nil
            if b then combat.damage(state,state.player,enemy,2*b.strength*b.ticks,true)end
        end
    elseif op=='bonus'then local value=math.min(6,n);if value>=v.bonus.n then v.bonus={n=value,tag=e.tag}end
    elseif op=='soften'then v.soften=math.min(6,v.soften+n)
    elseif op=='counter'then v.counter=math.max(v.counter,math.min(8,n))
    elseif op=='directive'then for _,enemy in ipairs(selected(state,e,target))do enemy.v4Directive=enemy.v4Directive or {mature=false}end
    elseif op=='mature'then for _,enemy in ipairs(selected(state,e,target))do if enemy.v4Directive then enemy.v4Directive.mature=true end end
    elseif op=='absorb'then for _,enemy in ipairs(selected(state,e,target))do local mark=enemy.v4Directive
        if mark then enemy.v4Directive=nil;bond(state,mark.mature and r.AR.ripe_absorb or r.AR.unripe_absorb,mark.mature)end
    end
    elseif op=='spend'then local amount=n=='all' and v[e.resource] or n
        assert(v[e.resource]>=amount,'original_v4 insufficient '..e.resource);v[e.resource]=v[e.resource]-amount;ctx.spent=amount
    elseif op=='mode'then switch(combat,state,e.mode)
    elseif op=='toggle'then switch(combat,state,v.mode=='ousia' and 'pneuma' or 'ousia')
    elseif op=='summon'then v.guests[e.member]=math.max(v.guests[e.member],math.min(r.FR.guest_charges_max,n))
    elseif op=='singer'then v.singer=math.max(v.singer,math.min(r.FR.singer_charges_max,n))
    elseif op=='trigger'then trigger(combat,state,e.member)
    elseif op=='revelry'then v.revelry={uses=math.min(r.FR.revelry_batches,n),ends=r.FR.revelry_end_phases,bonus=math.min(4,math.floor(ctx.spent/3))}
    elseif op=='resolve'then resolve(state,n)
    elseif op=='eye'then v.eye={uses=math.max(v.eye.uses,math.min(r.RD.eye_uses_max,n)),ends=r.RD.eye_end_phases}
    elseif op=='eye_pulse'then if active(v.eye) and live(target)then v.eye.uses=v.eye.uses-1;combat.damage(state,state.player,target,r.RD.eye_damage,true)end
    elseif op=='musou'then v.musou={uses=math.max(v.musou.uses,math.min(r.RD.musou_uses_max,n)),ends=r.RD.musou_end_phases}
    elseif op=='cleanse'then for _,id in ipairs(r.production_mapping.cleanse_status_ids)do
        local before=state.player.statuses[id]
        if before then state.player.statuses[id]=nil;Events.emit(state,'status',{source=state.player.id,target=state.player.id,status=id,amount=-before})end
    end
    else error('unsupported original op '..tostring(op))end
end
local function executeRoot(combat,state,item)
    local raw=item.effect.raw;assert(M.supported(raw),'unsupported original card')
    local v,r=state.originalV4,state.originalV4Rules
    local version=raw[item.effect.upgraded and 'upgrade' or 'base'];local paid=0
    for _,e in ipairs(version.effects)do if e.op=='pay_hp'then paid=paid+e.n end end
    pay(combat,state,paid)
    local ctx={snapshot=M.snapshot(state,item.target),spent=0,tag=raw.category,firstBonus=0,directSeen=false,actualDirect=0}
    if direct(version.effects)then
        if v.bonus.n>0 and (v.bonus.tag=='any' or v.bonus.tag==raw.category)then ctx.firstBonus=v.bonus.n;v.bonus={n=0,tag='any'}end
        if v.role=='HT' and v.infuse>0 then
            local low=ctx.snapshot.low and r.HT.low_hp_extra or 0
            if raw.category=='normal'then ctx.firstBonus=ctx.firstBonus+r.HT.normal_first_hit_bonus+low
            elseif raw.category=='charged' and v.chargedUsed<r.HT.charged_eligible_cards_per_turn then
                ctx.firstBonus=ctx.firstBonus+r.HT.charged_first_hit_bonus+low;v.chargedUsed=v.chargedUsed+1;ctx.htMark=true
            end
        elseif v.role=='AR' and raw.category=='normal' and v.bond>=2 then ctx.firstBonus=ctx.firstBonus+v.bond;v.bond=v.bond-1
        elseif v.role=='RD' and raw.category=='normal' and active(v.musou)then
            v.musou.uses=v.musou.uses-1;ctx.firstBonus=ctx.firstBonus+r.RD.musou_first_hit_bonus;ctx.musouPaid=true
        end
    end
    for _,e in ipairs(version.effects)do apply(combat,state,e,item.target,ctx)end
    if state.player.hp<=0 then return end
    if ctx.htMark and live(item.target)then apply(combat,state,{op='bloom',n=1},item.target,ctx)end
    if v.role=='RD'then
        local actualPaid=item.effect.paidEnergy or version.cost
        if raw.category=='command' and actualPaid>=1 then resolve(state,r.RD.paid_command_resolve_gain)
            if not v.relicUsed then v.relicUsed=true;M.block(state,2,true)end
        end
        if ctx.musouPaid and ctx.actualDirect>0 and v.musouRefunded<r.RD.musou_energy_refunds_per_turn_max then
            v.nextEnergy=math.min(r.common.next_energy_cap,v.nextEnergy+1);v.musouRefunded=v.musouRefunded+1
        end
        if ctx.snapshot.eye and ctx.actualDirect>0 and active(v.eye)then
            local target=live(item.target) and item.target or selected(state,{target='all'})[1]
            if target then v.eye.uses=v.eye.uses-1;combat.damage(state,state.player,target,r.RD.eye_damage,true)end
        end
    end
end
function M.execute(combat,state,item)
    local previous=state.resolvingEffects;state.resolvingEffects=true
    local called,result=pcall(executeRoot,combat,state,item)
    state.resolvingEffects=previous
    if not called then error(result,0)end
    if not previous then
        local ai=require('abyss_enemy_ai');ai.afterEffects(state,state.player);ai.flush(state,state.player)
    end
    return result
end
function M.endPhase(combat,state)
    for _,enemy in ipairs(state.enemies)do local b=enemy.v4Bloom
        if live(enemy) and b and b.ticks>0 then
            local damage=2*b.strength;b.ticks=b.ticks-1;if b.ticks==0 then enemy.v4Bloom=nil end
            combat.damage(state,state.player,enemy,damage,true)
        end
    end
    trigger(combat,state,'all')
end
function M.cleanup(state)
    local v=state.originalV4;v.bonus={n=0,tag='any'};v.counter=0;v.soften=0;v.enemyAction=nil
    v.infuse=math.max(0,v.infuse-1)
    for _,key in ipairs({'eye','musou','revelry'})do local value=v[key];value.ends=math.max(0,value.ends-1);if value.ends==0 then value.uses=0 end end
end
function M.startTurn(state)
    local v=state.originalV4
    state.energy=state.energy+v.nextEnergy;M.block(state,v.nextBlock,true)
    local extra=v.nextDraw;v.nextEnergy=0;v.nextDraw=0;v.nextBlock=0
    v.chargedUsed=0;v.fanGained=0;v.resolveGained=0;v.musouRefunded=0
    for _,enemy in ipairs(state.enemies)do if live(enemy) and enemy.v4Directive then enemy.v4Directive.mature=true end end
    return extra
end
function M.beginEnemyAction(state,enemy,intent)
    local v=state.originalV4;local attacking=false
    for _,e in ipairs(intent.effects or {})do if (e.op=='damage' or e.op=='damageAll') and (e.value or 0)>0 then attacking=true end end
    v.enemyAction={enemy=enemy,attacking=attacking,soften=attacking and v.soften or 0}
    if attacking then v.soften=0 end
end
function M.reduceAttack(state,source,target,base,fixed,normalAmount)
    local v=state.originalV4;local action=v and v.enemyAction
    if not action or not action.attacking or action.enemy~=source or target~=state.player then return base,normalAmount end
    local amount=normalAmount or Actors.attackAmount(state,source,target,base,fixed)
    local cut=math.min(amount,action.soften);action.soften=action.soften-cut
    if fixed then return math.max(0,base-cut),normalAmount end
    return base,amount-cut
end
function M.endEnemyAction(combat,state)
    local v=state.originalV4;local action=v.enemyAction;v.enemyAction=nil
    if action and action.attacking and state.player.hp>0 then local counter=v.counter;v.counter=0
        if counter>0 and live(action.enemy)then combat.retaliate(state,state.player,action.enemy,counter)end
    end
end
function M.preview(combat,state,instance,targetIndex)
    local seen={[state.catalog]=state.catalog,[state.rules]=state.rules,[state.originalV4Rules]=state.originalV4Rules,[state.events]={}}
    local staged=combat.copy(state,seen);staged.originalV4Preview={}
    local card=combat.cardDefinition(staged,instance)
    staged.energy=math.max(staged.energy,card.cost)
    local ok,why=combat.play(staged,instance.uid,targetIndex)
    local entries=staged.originalV4Preview;entries.originalV4=true;entries.reason=not ok and why or nil
    local texts={}
    for _,entry in ipairs(entries)do
        if entry.op=='block'then texts[#texts+1]='格挡 '..entry.low
        else local target='目标'
            for i,enemy in ipairs(staged.enemies)do if enemy.id==entry.target then target='敌'..i;break end end
            texts[#texts+1]=target..' '..entry.low..(entry.op=='derived' and '（追击）' or '')
        end
    end
    for _,event in ipairs(staged.events)do
        if event.kind=='heal' and event.detail.target=='player'then texts[#texts+1]='实际治疗 '..event.detail.amount end
    end
    entries.text=#texts>0 and ('本次预览：'..table.concat(texts,'；')) or ''
    return entries
end
function M.replay(state,id,uid,targetIndex)
    if not id then return nil end
    local saved=state.originalV4.commands[id]
    if not saved then return nil end
    if saved.uid~=uid or saved.target~=targetIndex then return false,'command_conflict'end
    return true
end
function M.record(state,id,uid,targetIndex)
    if id then state.originalV4.commands[id]={uid=uid,target=targetIndex}end
end
return M
