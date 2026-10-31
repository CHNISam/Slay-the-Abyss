local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local Act1Events = require('abyss_act1_events')
local Act2Events = require('abyss_act2_events')
local Act3Events = require('abyss_act3_events')
local number = require("abyss_numbers").integer
local C = Theme.color
local kinds = { camp = "营地", shop = "商店", event = "未知事件", treasure = "宝箱",ending_proceed='真结局' }
-- Keep legacy Act1 pointer ownership unchanged; only the new state machines join.
local addedStaged={dead_adventurer=true,designer=true,face_trader=true,knowing_skull=true,nloth=true}
local function stagedEvent(id)return addedStaged[id] or id=='match_game' or id=='neow' or id=='mysterious_sphere' or id=='mind_bloom' or Act2Events.ids[id]end
local events = {
    designer={name='设计师'},face_trader={name='换脸商'},knowing_skull={name='智者头骨'},nloth={name="N'loth"},
    dead_adventurer={name='冒险者遗骸'},colosseum={name='竞技场'},masked_bandits={name='蒙面强盗'},
    cursed_tome={name='诅咒书本'},forgotten_altar={name='遗忘祭坛'},drug_dealer={name='增幅师'},vampires={name='吸血鬼'},
    neow={name='高塔恩赐'},
    duplicator={name='映光石龛'},
    match_game={name='留影牌局'},
    joust={name='决斗'},
    beggar={name='乞丐'},
    mausoleum={name='古墓'},
    addict={name='瘾君子'},
    back_to_basics={name='古老文字'},
    the_library={name='图书馆'},
    tomb_red_mask={name='红面具领主之墓',body='面具守护着陵墓中的财宝。',leave='你离开了陵墓。'},
    sensory_stone={name='追忆石碑',body='石中封存着记忆。',leave='你离开了石头。'},
    mind_bloom={name='心灵绽放',body='意识在高塔深处展开。',leave='你离开了这片意识。'},
    mysterious_sphere={name='神秘球体',body='密闭的球形容器中传来机关运转声。',leave='你离开了容器。'},
    winding_halls={name='迷途回廊',body='曲折通道等待着你的选择。',leave='你离开了通道。'},
    moai_head={name='巨像之首',body='石像等待着你的献祭。',leave='你离开了巨像。'},
    falling={name='坠落',body='落石正在崩塌。你必须在手中的卡牌之间作出取舍。',leave='你重新站稳，继续赶路。'},
    mushrooms={name='蘑菇',body='发光的蘑菇覆盖了通道。',leave='你离开了蘑菇群。'},golden_idol={name='鎏金神像',body='一件遗物摆在古老的石台上。',leave='你离开了石台。'},
    ghosts={name='幽灵'},

    sssserpent={name='长蛇的交易',body='一条长蛇许诺金币，代价是一张诅咒。',leave='你离开了长蛇。'},
    big_fish={name='大鱼',body='三件礼物悬在面前。你只能选取一件。',leave='你带着选择的礼物离开。'},
    accursed_blacksmith={name='诅咒铁匠',body='古旧的铁砧尚有余温，旁边散落着可疑的器具。',leave='你离开了铁砧。'},
    bonfire={name='篝火精灵',body='篝火中的精灵向你招手。',leave='你告别了篝火。'},
    transmogrifier={name='变换神龛',body='神龛的微光能将一张卡牌化为新的形态。',leave='你离开了变换神龛。'},
    scrap_ooze={name='废料黏液',body='黏液深处似乎埋着一件遗物。伸手探索会受到伤害。',leave='你停止了探索。'},
    wheel={name='变化转轮',body='转轮等待你转动。它的六种结果无法自行挑选。',leave='你离开了转轮。'},
    lab={name='实验室',body='实验台上留着三瓶药水。',leave='你离开了实验室。'},
    woman_in_blue={name='蓝衣女子',body='一位蓝衣女子出售药水，瓶中的内容要付钱后才能知晓。',leave='你告别了蓝衣女子。'},
    we_meet_again={name='又见面了',body='一位熟人提出三笔交易。每笔交易的代价已经选定。',leave='你告别了这位熟人。'},
    fountain = { name='净化之泉', body='清澈的泉水在石隙间流淌。你可以借它洗去随身的诅咒。', leave='你离开了泉水。' },
    living_wall = { name='活墙', body=Narrative.eventCopy.living_wall.intro, leave='墙上的面孔渐渐沉寂。' },
    purifier = { name = "净化神龛", body = Narrative.eventCopy.purifier.intro:gsub("\n\n", "\n"),
        leave = "你向神龛行了一礼，转身继续赶路。" },
    cleric = { name = "圣职者", body = Narrative.eventCopy.cleric.intro:gsub("\n\n", "\n"),
        leave = "你婉拒了圣职者的服务，继续赶路。" },
    goop = {name="黏液金币",body="湿滑的泥潭中露出几枚金币。要取回它们，就得忍受黏液的侵蚀；绕道离开也会丢失部分盘缠。",leave="你收好剩下的盘缠，绕过泥潭。"},
    upgrade_shrine = {name="升级神龛",body="一道微光停在石龛上。你可以在此精进一式招数。",leave="你将这次机会留在身后。"},
    golden_wing = {name="金翼雕像",body="残破的金翼守着山道。献出生命可以舍弃一式招数；足够强的攻击也能击碎外壳，取出金币。",leave="你绕过了雕像。"},
    shining_light = {name="闪耀之光",body="石隙间涌出耀眼的光。靠近它会灼伤身体，也会让尚未精进的招数获得提升。",leave="你避开了光芒。"},
    golden_shrine = {name="鎏金石龛",body="石龛中存着一份馈赠。你可以收下少量金币，也可以取走更多，但未散的执念会随你同行。",leave="你没有取走石龛中的金币。"},
}
local layout = Theme.layout.nativeNode
local OPTIONS = #layout.event.options.rows
local function find(entries, id, key)
    for _, item in ipairs(entries or {}) do if item[key or "id"] == id then return item end end
end
local M = {}
-- STS NeowEvent staging (port): Neow stands right, InfiniteSpeechBubble carries name/body,
-- LargeDialogOptionButtons stack on the left; the generic event plate/caption is not shown.
local NEOW = layout.event.neow
local function place(control, rect)
    control:SetAnchoredPosition(rect[1], rect[2])
    if rect[3] then control:SetSizeDelta(rect[3], rect[4]) end
end
local function renderEventFigure(event, id)
    local neow = id == 'neow' and NEOW ~= nil
    local figure, art = event:GetChild('neowFigure'), event:GetChild('art')
    if figure then figure:SetVisible(neow) end
    if art then art:SetVisible(not neow) end
    for _, name in ipairs({ 'plate', 'plateBorder', 'glow', 'caption' }) do
        local c = event:GetChild(name); if c then c:SetVisible(not neow) end
    end
    if neow then event:GetChild('caption').text = '七天神像' end
    local bubble = event:GetChild('bubble'); if bubble then bubble:SetVisible(neow) end
    if not NEOW then return end
    local name, body = event:GetChild('name'), event:GetChild('body')
    name:SetVisible(not neow)
    -- talk(): Neow's line lives in the InfiniteSpeechBubble, dark ink on the light bubble.
    place(body, neow and NEOW.bubbleText or layout.event.body)
end
-- LargeDialogOptionButton.calculateY (ROOM): bottom-aligned stack, -82px per slot, x = 620.
local function placeOptions(event, neow, count)
    local o = layout.event.options
    for i = 1, OPTIONS do
        local box = event:GetChild('option' .. i)
        if box then
            local w, h = o.size[1], o.size[2]
            if neow then
                local n = NEOW.options
                w, h = n.size[1], n.size[2]
                box:SetAnchoredPosition(n.x, n.bottom + (count - i) * n.spacing)
                place(box:GetChild('title'), n.title)
                place(box:GetChild('description'), n.description)
            elseif o.rows[i] then
                box:SetAnchoredPosition(o.x, o.rows[i])
                place(box:GetChild('title'), o.title)
                place(box:GetChild('description'), o.description)
            end
            box:SetSizeDelta(w, h)
            for _, part in ipairs({ 'border', 'hit' }) do
                local c = box:GetChild(part); if c then c:SetSizeDelta(w, h) end
            end
            for _, part in ipairs({ 'normal', 'disabled', 'hover', 'pressed', 'selected' }) do
                local c = box:GetChild(part); if c then c:SetSizeDelta(w - 4, h - 4) end
            end
            box:GetChild('description'):SetVisible(true)
        end
    end
end

local function eventNotice(id, copy, result)
    if id == 'neow' then return '' end
    if (stagedEvent(id) or Act3Events.ids[id]) then return copy.name .. ' · 请选择上方选项' end
    return result and copy.name or (copy.name .. " · 选择一项，或直接离开")
end

-- Installs the events responsibility on one node UI instance.
function M.install(ctx)
    function ctx.renderEvent(view, node, result)
        local event = ctx.child("eventView")
        local id = node.event and node.event.id or (result and result.eventId)
        local copy = events[id] or { name = kinds.event, body = "", leave = "你离开了。" }
        local function writeEventHeading()
            event:GetChild("name").text = copy.name
            local mode=ctx.self.run.unknown and ctx.self.run.unknown.pools and ctx.self.run.unknown.pools.mode or ctx.self.run.data.rules.events.poolMode
            event:GetChild("caption").text = (stagedEvent(id) or Act3Events.ids[id]) and kinds.event or mode=='restricted-seven' and "未知事件 · 受限事件池（7种）"
                or mode=='restricted-six' and "未知事件 · 受限事件池（6种）" or kinds.event
        end
        writeEventHeading()
        renderEventFigure(event, id)
        local body
        local function eventOutcomeBody()
            body=result and result.text or node.event and node.event.body or copy.body
            if not result and node.event and node.event.stage=='result' and node.event.obtainedRelicId then
                body=body..'\n获得遗物：'..ctx.relicName(node.event.obtainedRelicId)..'。'
            end
            if not result and node.event.stage=='relic_reward' and node.event.relicOffer then
                body=body..'\n可领取遗物：'..ctx.relicName(node.event.relicOffer.id)..'。'
            end
            local function describeTransformedCard()
                if not result and id=='transmogrifier' and node.event.obtainedCardUid then
                    local obtained=find(ctx.self.run.deck,node.event.obtainedCardUid,'uid')
                    body=body..'\n已变换为：'..ctx.cardName(obtained.cardId,obtained.upgraded)..'。'
                end
            end
            describeTransformedCard()

        end
        eventOutcomeBody()
        event:GetChild("body").text = body
        ctx.ink(event:GetChild("body"), id == 'neow' and C.panelSunken or C.text)
        local rows = {}
        local function buildEventRows()
            if not result then
                local info, gold, deckOk = node.event, ctx.self.run.gold, #node.purgeCards > 0
                local function need(cost) return "金币不足（需要 " .. cost .. "，现有 " .. gold .. "）" end
                local function purify(_cost)
                    return function()
                        ctx.self.mode, ctx.self.picker, ctx.self.pickPage, ctx.self.selected, ctx.self.notice = "picker", "purify", 1, nil, ""
                        ctx.self:render() return true
                    end
                end
                if id ~= 'cleric' and id ~= 'purifier' then
                    local function buildEventOptions()
                        for _,option in ipairs(info.options) do
                            local selected=option
                            rows[#rows+1]={title='［'..(selected.rewardCard and ctx.cardName(selected.cardId,selected.upgraded)or selected.title)..'］',
                                description=ctx.eventOptionText(selected),enabled=selected.enabled,handler=function()
                                    -- Repeated-search events retain the same command after
                                    -- rendering new odds. An old callback is still stale.
                                    if ctx.self.view~=view or ctx.self.renderRun~=ctx.self.run or ctx.self.renderMap~=ctx.self.map then return false,'stale_action' end
                                    if Act1Events.ids[id] or (stagedEvent(id) or Act3Events.ids[id]) then
                                        return ctx.commit('chooseEvent',selected.choice,function()
                                            local outcome=ctx.self.run.nodeFlow.event
                                            local text=outcome.body or '请选择一张卡牌。'
                                            -- These state machines already keep their result
                                            -- screen until Leave; completion needs no extra hold.
                                            return text
                                        end)
                                    end
                                    if id=='living_wall' then
                                        return ctx.commit('chooseEvent',selected.choice,function()
                                            local outcome=ctx.self.run.nodeFlow.event
                                            if outcome.stage=='choose_card' then
                                                ctx.self.mode,ctx.self.picker,ctx.self.pickPage,ctx.self.selected='picker','living_'..selected.choice,1,nil
                                                return '请选择一张卡牌'
                                            end
                                            local text='没有符合条件的卡牌。墙上的面孔渐渐沉寂。'
                                            return text,{text=text}
                                        end)
                                    end
                                    if selected.picker then
                                        ctx.self.mode,ctx.self.picker,ctx.self.pickPage,ctx.self.selected,ctx.self.notice='picker',
                                        selected.picker=='event_upgrade' and 'upgrade' or selected.picker,1,nil,''
                                        ctx.self:render();return true
                                    end
                                    return ctx.commit('chooseEvent',selected.choice,function(before)
                                        local outcome=ctx.self.run.nodeFlow.event
                                        -- 只列出实际变化的资源，未变化的生命/金币不显示
                                        local lines,changes={},{}
                                        if ctx.self.run.hp~=before.hp then changes[#changes+1]='生命 '..number(before.hp)..' → '..number(ctx.self.run.hp) end
                                        if ctx.self.run.gold~=before.gold then changes[#changes+1]='金币 '..number(before.gold)..' → '..number(ctx.self.run.gold) end
                                        if #changes>0 then lines[1]=table.concat(changes,'；') end
                                        if outcome.upgradedUids and #outcome.upgradedUids>0 then
                                            local names={}
                                            for _,uid in ipairs(outcome.upgradedUids) do
                                                local card=find(ctx.self.run.deck,uid,'uid');names[#names+1]=ctx.cardName(card.cardId,true,card.upgrades)
                                            end
                                            lines[#lines+1]='已升级：'..table.concat(names,'、')
                                        end
                                        if outcome.obtainedCardUid then
                                            local obtained=find(ctx.self.run.deck,outcome.obtainedCardUid,'uid')
                                            lines[#lines+1]='已获得诅咒：'..ctx.cardName(obtained.cardId,false)
                                        end
                                        if outcome.removedUids then
                                            lines[#lines+1]='已移除诅咒：'..#outcome.removedUids..' 张'
                                        end
                                        local text=#lines>0 and table.concat(lines,'\n') or '什么也没有发生。'
                                        return text,{text=text}
                                    end)
                                end}
                        end
                    end
                    buildEventOptions()

                elseif id == "cleric" then
                    local function buildClericOptions()
                        local healOk = gold >= info.healCost
                        rows[1] = { title = "［治疗］", enabled = healOk, handler = function()
                                return ctx.commit("chooseEvent", "heal", function(before)
                                    local healed = ctx.self.run.hp - before.hp
                                    return "治疗完成 · 回复 " .. number(healed) .. " 点生命", { text = "圣职者的祝祷落在你身上，伤口渐渐愈合。\n支付 " ..
                                        number(before.gold - ctx.self.run.gold) .. " 金币，回复 " .. number(healed) .. " 点生命（生命 " .. number(before.hp) .. " → " .. number(ctx.self.run.hp) .. "）。" }
                                end)
                            end,
                            description = not healOk and need(info.healCost) or (info.heal > 0 and
                            ("支付 " .. number(info.healCost) .. " 金币，回复 " .. number(info.heal) .. " 点生命（生命 " .. number(ctx.self.run.hp) .. " → " .. number(ctx.self.run.hp + info.heal) .. "）")
                                or ("支付 " .. info.healCost .. " 金币；生命已满，不会回复")) }
                        local purifyOk = gold >= info.removeCost and deckOk
                        rows[2] = { title = "［净化］", enabled = purifyOk, handler = purify(info.removeCost),
                            description = gold < info.removeCost and need(info.removeCost) or
                            (deckOk and ("支付 " .. info.removeCost .. " 金币，从牌组移除一张卡牌") or "没有可移除的卡牌") }
                    end
                    buildClericOptions()

                else
                    rows[1] = { title = "［祈祷］", enabled = deckOk, handler = purify(info.removeCost),
                        description = deckOk and (info.removeCost > 0 and ("支付 " .. info.removeCost .. " 金币，从牌组移除一张卡牌")
                            or "免费从牌组移除一张卡牌") or "没有可移除的卡牌" }
                end
                if id=='cleric' or id=='purifier' then rows[#rows + 1] = { title = "［离开］", enabled = true, description = "什么也不会发生。", handler = function()
                            return ctx.commit("chooseEvent", "leave", function() return "已离开" .. copy.name, { text = copy.leave } end)
                        end } end
            end
        end
        buildEventRows()
        if NEOW then placeOptions(event, id == 'neow', math.min(#rows, OPTIONS)) end
        for i = 1, OPTIONS do
            local row, box = rows[i], event:GetChild("option" .. i)
            ctx.show(box, row)
            if row then
                ctx.state(box, row.enabled)
                box:GetChild("title").text = row.title
                box:GetChild("description").text = row.description
                ctx.ink(box:GetChild("title"), row.enabled and C.goldBright or C.textMuted)
                ctx.ink(box:GetChild("description"), row.enabled and C.textDim or C.textMuted)
                ctx.action("eventView/option" .. i, row.enabled, row.handler, row.description)
            end
        end
        return eventNotice(id, copy, result)
    end

    function ctx.bindStagedEventActions(node)
        if node and node.type=='event' and stagedEvent(node.event.id) then
            for key, entry in pairs(ctx.self.actions) do
                if key=='confirm' or key=='back' or key:match('^eventView/') or key:match('^pickerView/') then
                    ctx.bindAct2Action(key,entry)
                end
            end
        end
    end
end
return M
