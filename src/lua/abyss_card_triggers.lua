-- Fixed319009 card/power hooks. Plans are data; Combat owns phase/transactions.
local Actors=require("abyss_actor")
local Events=require("abyss_events")
local M={}
local MAX=2147483647
local ids={"after_image","thousand_cuts","envenom","rage","heat_sinks","storm"}
local specs={
    after_image={name="余像",priority=5,description="每打出一张牌，获得等同层数的固定格挡。"},
    thousand_cuts={name="凌迟",priority=5,description="每打出一张牌，在该牌清理后对所有敌人造成等同层数的固定伤害。"},
    envenom={name="涂毒",priority=5,description="普通攻击造成未被格挡的正数伤害时，对目标施加等同层数的中毒。"},
    rage={name="狂怒",priority=5,description="本回合每打出一张攻击牌，获得等同层数的固定格挡。"},
    heat_sinks={name="散热片",priority=5,description="每打出一张能力牌，在其原生效果前抽等同层数的牌。"},
    storm={name="雷暴",priority=5,description="每打出一张能力牌，依次生成等同层数的闪电球。"},
}
local classCards={silent={"after_image","thousand_cuts","envenom"},ironclad={"rage"},defect={"heat_sinks","storm"}}
local function integer(n,lo,hi) return type(n)=="number" and n==n and n%1==0 and n>=lo and n<=hi end
local function plain(t,why) assert(type(t)=="table" and getmetatable(t)==nil,why) end
local function dense(t)
    plain(t,"invalid card-trigger list")
    local n=0
    for k in next,t do assert(integer(k,1,MAX),"invalid card-trigger index");n=n+1 end
    for i=1,n do assert(rawget(t,i)~=nil,"sparse card-trigger list") end
    return n
end
local function copy(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function powers(s)
    plain(s,"invalid card-trigger state");plain(s.player,"missing card-trigger player")
    plain(s.player.statuses,"missing card-trigger powers")
    return s.player.statuses
end
local function amount(s,id)
    local n=powers(s)[id] or 0
    assert(integer(n,0,MAX),"invalid card-trigger amount: "..id);return n
end
local function live(s)
    if not Actors.isActive(s.player) then return false end
    dense(s.enemies)
    for _,enemy in ipairs(s.enemies) do if Actors.isActive(enemy) then return true end end
    return false
end
local function order(s)
    local out,seen={},{}
    local list=s.cardTriggerPowerOrder or {}
    dense(list)
    local serial=s.cardTriggerPowerSerial or 0
    assert(integer(serial,0,MAX),"invalid card-trigger acquisition serial")
    local previous=0
    for _,entry in ipairs(list) do
        plain(entry,"invalid card-trigger acquisition entry")
        local spec=specs[entry.id]
        assert(spec and not seen[entry.id] and entry.priority==spec.priority
            and integer(entry.order,1,serial) and entry.order>previous,"invalid card-trigger acquisition order")
        seen[entry.id]=true;previous=entry.order;out[#out+1]=entry
    end
    return out,seen,serial
end
function M.definition(id)
    local spec=assert(specs[id],"unknown card-trigger power")
    return {id=id,name=spec.name,description=spec.description,kind="buff",stack="intensity",decay="none",priority=spec.priority}
end
local function gain(id,n) return {{op="gainCardTriggerPower",status=id,value=n}} end
local cards={
    after_image={id="after_image",sourceId="After Image",name="余像",color="green",type="power",rarity="rare",cost=1,
        effects=gain("after_image",1),upgrade={innate=true},
        text="每打出一张牌，获得1点格挡。",upgradeText="固有。每打出一张牌，获得1点格挡。"},
    thousand_cuts={id="thousand_cuts",sourceId="A Thousand Cuts",name="凌迟",color="green",type="power",rarity="rare",cost=2,
        effects=gain("thousand_cuts",1),upgrade={effects=gain("thousand_cuts",2)},
        text="每打出一张牌，对所有敌人造成1点伤害。",upgradeText="每打出一张牌，对所有敌人造成2点伤害。"},
    envenom={id="envenom",sourceId="Envenom",name="涂毒",color="green",type="power",rarity="rare",cost=2,
        effects=gain("envenom",1),upgrade={cost=1},
        text="每当普通攻击造成未被格挡的伤害，给予目标1层中毒。",upgradeText="每当普通攻击造成未被格挡的伤害，给予目标1层中毒。"},
    rage={id="rage",sourceId="Rage",name="狂怒",color="red",type="skill",rarity="uncommon",cost=0,
        effects=gain("rage",3),upgrade={effects=gain("rage",5)},
        text="本回合每打出一张攻击牌，获得3点格挡。",upgradeText="本回合每打出一张攻击牌，获得5点格挡。"},
    heat_sinks={id="heat_sinks",sourceId="Heatsinks",name="散热片",color="blue",type="power",rarity="uncommon",cost=1,
        effects=gain("heat_sinks",1),upgrade={effects=gain("heat_sinks",2)},
        text="每打出一张能力牌，抽1张牌。",upgradeText="每打出一张能力牌，抽2张牌。"},
    storm={id="storm",sourceId="Storm",name="雷暴",color="blue",type="power",rarity="uncommon",cost=1,
        effects=gain("storm",1),upgrade={innate=true},
        text="每打出一张能力牌，生成1个闪电球。",upgradeText="固有。每打出一张能力牌，生成1个闪电球。"},
}
function M.withCards(data,classId)
    local group=assert(classCards[classId],"unknown card-trigger character")
    plain(data,"missing card-trigger data")
    local out=copy(data)
    assert(out.cards and out.statuses,"missing card-trigger content")
    dense(out.cards.cards);dense(out.statuses.statuses)
    local existing,statusIds={},{}
    for index,card in ipairs(out.cards.cards) do assert(not existing[card.id],"duplicate source card");existing[card.id]=index end
    for index,def in ipairs(out.statuses.statuses) do assert(not statusIds[def.id],"duplicate source status");statusIds[def.id]=index end
    for _,id in ipairs(group) do
        local cardIndex,statusIndex=existing[id],statusIds[id]
        if cardIndex then
            -- Replace only this helper's known native definition in the copy.
            -- Our prepared cards have no target metadata, so a second call is
            -- a genuine duplicate rather than another native replacement.
            local native=out.cards.cards[cardIndex]
            assert(native.target~=nil and native.experimental~=true and native.sourceId==cards[id].sourceId
                and native.type==cards[id].type and native.cost==cards[id].cost,
                "card-trigger definition already exists or is incompatible: "..id)
        end
        if statusIndex then
            local native=out.statuses.statuses[statusIndex]
            assert(cardIndex and native.kind=="buff" and native.stack=="intensity" and native.decay=="none",
                "card-trigger status already exists or is incompatible: "..id)
        end
        out.cards.cards[cardIndex or #out.cards.cards+1]=copy(cards[id])
        out.statuses.statuses[statusIndex or #out.statuses.statuses+1]=M.definition(id)
    end
    out.experimentalMechanics=true
    return out
end
-- Call only AFTER a Power really applied. Amount stacking keeps the same slot.
function M.recordApplied(s,id)
    assert(specs[id],"unknown card-trigger power")
    assert(amount(s,id)>0,"record requires an applied card-trigger power")
    local list,seen,serial=order(s)
    if seen[id] then return false end
    assert(serial<MAX,"card-trigger acquisition serial overflow")
    list[#list+1]={id=id,priority=specs[id].priority,order=serial+1}
    s.cardTriggerPowerOrder=list;s.cardTriggerPowerSerial=serial+1
    return true
end
function M.apply(s,id,n)
    assert(specs[id] and integer(n,1,MAX),"invalid card-trigger application")
    if not live(s) then return false end
    local old=amount(s,id);assert(old+0.0+n<=MAX,"card-trigger stack overflow")
    local _,seen,serial=order(s)
    assert(seen[id] or serial<MAX,"card-trigger acquisition serial overflow")
    local def=assert(s.catalog and s.catalog.statuses and s.catalog.statuses[id],"register card-trigger status first")
    assert(def.id==id and def.kind=="buff" and def.stack=="intensity" and def.decay=="none","incompatible card-trigger status")
    if old>0 then assert(seen[id],"missing card-trigger acquisition history") end
    Events.frame(s) -- predictable invalid frame must fail before Actor mutates.
    local applied=Actors.applyPower(s,s.player,id,n,s.player)
    if applied then M.recordApplied(s,id) end
    return applied
end
local function action(id,effect)
    return {kind="effect",effect=effect,triggerPower=id}
end
-- Call before native effects execute, while only old Powers exist. Arrays are
-- SOURCE ENQUEUE ORDER, including TOP calls (root pushes them one at a time).
function M.prepareUse(s,card,nativeRageHandled)
    powers(s);plain(card,"invalid played trigger card")
    assert(card.type=="attack" or card.type=="skill" or card.type=="power" or card.type=="status" or card.type=="curse","invalid played card type")
    assert(card.dontTriggerOnUseCard==nil or type(card.dontTriggerOnUseCard)=="boolean","invalid played card trigger flag")
    local plan={top={},beforeUse={},afterUse={}}
    if card.dontTriggerOnUseCard or not live(s) then return plan end
    local list,seen=order(s)
    for _,id in ipairs(ids) do assert(id=='rage'and nativeRageHandled or amount(s,id)==0 or seen[id],"missing card-trigger acquisition history") end
    for _,entry in ipairs(list) do
        local id,n=entry.id,amount(s,entry.id)
        if n>0 then
            if id=="after_image" or id=="rage" and not nativeRageHandled and card.type=="attack" then
                plan.beforeUse[#plan.beforeUse+1]=action(id,{op="block",value=n,fixed=true})
            elseif id=="heat_sinks" and card.type=="power" then
                plan.top[#plan.top+1]=action(id,{op="draw",value=n})
            elseif id=="storm" and card.type=="power" then
                assert(s.orbs,"Storm requires enabled orb support")
                plan.beforeUse[#plan.beforeUse+1]=action(id,{op="cardTriggerStorm",remaining=n})
            elseif id=="thousand_cuts" then
                local matrix={};local targetIds={}
                dense(s.enemies)
                for _,enemy in ipairs(s.enemies) do
                    assert(type(enemy.id)=="string" and not targetIds[enemy.id],"invalid trigger damage target identity")
                    targetIds[enemy.id]=true;matrix[#matrix+1]={targetId=enemy.id,amount=n}
                end
                plan.afterUse[#plan.afterUse+1]=action(id,{op="cardTriggerDamageAll",matrix=matrix})
            end
        end
    end
    return plan
end
-- A compact substitute for the source loop of separate ChannelAction objects.
-- Push these TOP entries in returned order: Channel runs before continuation.
function M.expandStorm(s,effect)
    powers(s);plain(effect,"invalid Storm action")
    assert(effect.op=="cardTriggerStorm" and integer(effect.remaining,1,MAX),"invalid Storm count")
    if not live(s) then return {} end
    assert(s.orbs,"Storm requires enabled orb support")
    local out={}
    if effect.remaining>1 then out[1]=action("storm",{op="cardTriggerStorm",remaining=effect.remaining-1}) end
    out[#out+1]=action("storm",{op="channelOrb",orb="lightning",value=1})
    return out
end
-- At source owner.onAttack the amount is post-Block and ToChangeDamage hooks,
-- but BEFORE target.onAttacked/final HP subtraction. Core's current finite
-- targets have no later damage-changing hook; do not generalize that equivalence.
function M.onAttack(s,source,target,damageAmount,damageType)
    powers(s);assert(integer(damageAmount,0,MAX),"invalid Envenom attack damage")
    if source~=s.player or target==source or damageType~="NORMAL" or damageAmount==0 or not live(s) then return nil end
    local n=amount(s,"envenom")
    if n==0 or not Actors.isActive(target) then return nil end
    local found=false
    for _,enemy in ipairs(s.enemies) do if enemy==target then found=true;break end end
    assert(found and type(target.id)=="string","invalid Envenom target")
    return action("envenom",{op="cardTriggerPoison",targetId=target.id,value=n})
end
function M.resolveEnvenom(s,effect)
    powers(s);plain(effect,"invalid Envenom action")
    assert(effect.op=="cardTriggerPoison" and type(effect.targetId)=="string" and integer(effect.value,1,MAX),"invalid Envenom action")
    if not live(s) then return false end
    local target
    for _,enemy in ipairs(s.enemies) do if enemy.id==effect.targetId then assert(not target,"duplicate Envenom target");target=enemy end end
    if not target or not Actors.isActive(target) then return false end
    local old=target.statuses.poison or 0
    assert(integer(old,0,MAX),"invalid existing Envenom poison")
    -- PoisonPower's constructor caps a NEW Power, while an existing Power's
    -- stack uses the uncapped action amount. Snake Skull is not supported here.
    local value=old>0 and effect.value or math.min(9999,effect.value)
    return Actors.applyPower(s,target,"poison",value,s.player)
end
function M.resolveDamageAll(s,effect,api)
    powers(s);plain(effect,"invalid Thousand Cuts action")
    assert(effect.op=="cardTriggerDamageAll","invalid Thousand Cuts operation")
    dense(effect.matrix)
    assert(type(api)=="table" and type(api.damage)=="function","missing trigger damage API")
    local targets,seen={},{ }
    for _,entry in ipairs(effect.matrix) do
        plain(entry,"invalid Thousand Cuts matrix entry")
        assert(type(entry.targetId)=="string" and not seen[entry.targetId] and integer(entry.amount,0,MAX),"invalid Thousand Cuts matrix")
        seen[entry.targetId]=true
        local found
        for _,enemy in ipairs(s.enemies) do if enemy.id==entry.targetId then assert(not found,"duplicate Thousand Cuts target");found=enemy end end
        targets[#targets+1]={target=found,amount=entry.amount}
    end
    if not Actors.isActive(s.player) then return 0 end
    local total,reactions=0,{}
    for _,entry in ipairs(targets) do
        if Actors.isActive(entry.target) then total=total+0.0+api.damage(s,s.player,entry.target,entry.amount,true,reactions) end
    end
    Actors.resolveDamageReactions(s,reactions,api.retaliate)
    return total
end
-- Apply at the queued RemoveSpecificPowerAction boundary, not at play time.
function M.removePower(s,id)
    assert(specs[id],"unknown removed card-trigger power")
    local n=amount(s,id);local list=order(s)
    if n==0 then return false end
    Events.frame(s)
    local keep={};for _,entry in ipairs(list) do if entry.id~=id then keep[#keep+1]=entry end end
    require('abyss_power_schedule').remove(s,s.player,id)
    s.player.statuses[id]=nil;s.cardTriggerPowerOrder=keep
    Events.emit(s,"status_removed",{source=s.player.id,target=s.player.id,status=id,amount=-n})
    return true
end
function M.prepareEndTurn(s)
    powers(s)
    local list,seen=order(s);local out={}
    assert(amount(s,"rage")==0 or seen.rage,"missing Rage acquisition history")
    for _,entry in ipairs(list) do
        if entry.id=="rage" and amount(s,"rage")>0 then
            out[#out+1]=action("rage",{op="removeCardTriggerPower",status="rage"})
        end
    end
    return out
end
return M
