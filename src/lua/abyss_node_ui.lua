-- Native non-combat node adapter. Nodes owns every gameplay transaction; this module only
-- reads Nodes.view, draws the approved PR19 node screens and sends commands.
-- root is nodePanel from nodeLayout(); the host may replace self.run/self.map.
-- onChange(ok, reason, self) refreshes the host after an attempted command.
-- options.color/options.imageSource are the platform Color constructor and picture source;
-- without them states are still shown through visibility layers.
-- options.cursorEvents may inject Enum.CursorEventType; the native host defaults
-- to that documented global. Missing pointer events retain ordinary click input.
local Nodes = require("abyss_nodes")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local Narrative = require("abyss_narrative")
local Merchant = require("abyss_merchant")
local ShopUI = require("abyss_shop_ui")
local ShopSelection = require('abyss_shop_selection')
local RoomMotion = require('abyss_node_ui_motion')
local CampUI = require('abyss_node_ui_camp')
local RewardDetail = require('abyss_node_ui_reward_detail')
local M = {}
local Controller = require('abyss_controller')
local CardDisplay = require('abyss_card_display')
local Combat = require('abyss_combat')
local Act1Events = require('abyss_act1_events')
local Act2Events = require('abyss_act2_events')
local Act3Events = require('abyss_act3_events')
local EndingUI=require('abyss_node_ui_ending')
local number = require("abyss_numbers").integer
local C = Theme.color
local kinds = { camp = "营地", shop = "商店", event = "未知事件", treasure = "宝箱",ending_proceed='真结局' }
local typeNames = { attack = "攻击", skill = "技能", power = "能力", status = "状态", curse = "诅咒" }
local reasons = {
    card_content_unavailable='这张卡牌的效果尚未接齐，本次未改变资源',
    relic_content_unavailable='这件遗物的效果尚未接齐，本次未改变资源',
    neow_insufficient_selectable_cards='没有足够的可选卡牌，本次未改变资源',
    insufficient_gold = "金币不足", item_unavailable = "商品已售出或不可购买",
    shop_content_unavailable = "商店补货状态异常，本次未付款，请离店或重新开始",
    removal_unavailable = "本店删牌服务已使用",
    invalid_card = "这张卡牌已不在牌组中",
    card_not_upgradeable = "这张卡牌无法继续升级", potion_slots_full = "药水槽已满", potions_blocked = "遗物效果禁止获得药水",
    camp_choice_made = "本次营地已选择升级或休息", no_pending_node = "此节点已经完成",
    wrong_node_type = "当前节点不支持此操作", relic_already_owned = "已持有这件遗物",
    event_obtain_content_unavailable = "当前遗物的获牌效果尚未接齐，本次未改变资源", event_damage_content_unavailable = "当前遗物的事件伤害尚未接齐，本次未改变资源", stale_event_health = "生命上限已变化，请重新查看事件", stale_event_card = "候选卡牌已变化，请重新查看事件", invalid_event_choice = "此事件选项不可用", event_unavailable = "当前没有满足条件的已实现事件", stale_action = "界面已变化，请重新选择",
    event_content_unavailable = "事件所需卡牌数据不可用", invalid_deck_uid = "卡牌编号异常，未领取奖励",
    event_reward_content_unavailable = "当前遗物的无色奖励效果尚未接齐，本次未改变资源",
    panel_hidden = "节点界面未打开", unavailable_action = "此选项当前不可用",
}
-- Presentation copy only; every option and outcome below comes from Nodes and data/rules.json.
local function stagedEvent(id)return id=='neow' or id=='mysterious_sphere' or id=='mind_bloom' or Act2Events.ids[id]end
local events = {
    neow={name='高塔恩赐'},
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
    golden_idol={name='鎏金神像',body='一件遗物摆在古老的石台上。',leave='你离开了石台。'},
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
local triggers = { combat_start = "战斗开始时，", combat_end = "战斗结束时，" }
local layout = Theme.layout.nativeNode
local SHOP_PAGE, RELIC_PAGE, PICK_PAGE = #layout.shop.columns, #layout.shop.relics.columns, #layout.picker.columns
local OPTIONS = #layout.event.options.rows

local function find(entries, id, key)
    for _, item in ipairs(entries or {}) do if item[key or "id"] == id then return item end end
end
local function snapshotDeck(deck)
    local result = {}
    for _, card in ipairs(deck) do result[#result + 1] = { uid = card.uid, cardId = card.cardId, upgraded = card.upgraded } end
    return result
end
local function iconId(entry) return type(entry) == "table" and entry.id or entry end

function M.new(root, run, map, presentation, clickEvent, onChange, options)
    options = options or {}
    local rootParent = root.parent
    local self = { root = root, run = run, map = map, presentation = presentation or {},
        visible = run ~= nil and map ~= nil, page = 1, relicPage = 1, mode = "main", actions = {}, notice = "" }
    local function child(name) return assert(root:GetChild(name), "missing node UI control " .. name) end
    local function path(key)
        local control = root
        for part in key:gmatch("[^/]+") do control = assert(control:GetChild(part), "missing node UI control " .. key) end
        return control
    end
    local function show(control, value) control:SetVisible(value ~= nil and value ~= false) end
    local function tint(control, colour)
        if options.color then control.imageColor = options.color(colour.r, colour.g, colour.b, colour.a) end
    end
    local function ink(control, colour)
        if options.color then control.fontColor = options.color(colour.r, colour.g, colour.b, colour.a) end
    end
    local function picture(control, id)
        if options.imageSource and id then control:SetImage(options.imageSource, iconId(id)) end
    end
    local merchant = Merchant.new(child("merchant"), { color = options.color, sound = options.sound })
    child("merchant"):GetChild("talk"):GetChild("hit"):AddCursorEventListener(clickEvent, function() return merchant:tap() end)
    self.merchant = merchant
    local buttonLooks, buttonHover, buttonPress = {}, nil, nil
    local function paintButton(box)
        local look = buttonLooks[box]
        if not look then return end -- a never-shown view can still receive a late native exit
        local enabled = look.enabled and not look.selected
        local pressed = enabled and buttonPress and buttonPress.box == box
        local hover = enabled and buttonHover == box and not pressed
        box:GetChild("normal"):SetVisible(look.enabled and not look.selected and not pressed and not hover)
        box:GetChild("hover"):SetVisible(hover == true)
        box:GetChild("pressed"):SetVisible(pressed == true)
        box:GetChild("disabled"):SetVisible(not look.enabled)
        box:GetChild("selected"):SetVisible(look.selected == true)
        tint(box:GetChild("hover"), look.primary and C.goldBright or C.buttonHover)
        tint(box:GetChild("pressed"), C.goldDim)
        tint(box:GetChild("border"), look.selected and C.goldBright or not look.enabled and C.line
            or (pressed or hover or look.primary) and C.goldBright or C.gold)
        local label = box:GetChild("label")
        if label then ink(label, not look.enabled and C.textMuted or pressed and C.buttonPressedText
            or look.primary and C.textOnLight or C.goldBright) end
        local scale = pressed and layout.buttonStates.pressedScale or layout.buttonStates.normalScale
        box:SetLocalScale(scale, scale, 1)
    end
    local buttonInputs, actionInputs = {}, {}
    local function retireAction(entry)
        if not entry or not entry.observe then return end
        if entry.retire then entry.retire() end
        for _, input in pairs(buttonInputs) do
            for _, gesture in pairs(input.active) do if gesture.action == entry then gesture.action = nil end end
            if input.released and input.released.action == entry then input.released.action = nil end
        end
    end
    local function observeAction(entry)
        if not entry.observe or entry.observe() then return true end
        retireAction(entry)
        return false
    end
    local inspectCards={}
    local shopSelection = ShopSelection.new(self, child('shopView'), options)
    local roomMotion = RoomMotion.new(self,child,options)
    local rewardDetail=RewardDetail.new(self,child('treasureView'):GetChild('details'),options)
    -- One horizontal row drag at a time; swallow eats the Click that ends a swipe.
    local swipe, swallow = nil, nil
    local function resetButtons()
        rewardDetail:reset()
        buttonHover, buttonPress, swipe = nil, nil, nil
        self.inspectPress=nil
        for _, input in pairs(buttonInputs) do input.active, input.released = {}, nil end
        for box in pairs(buttonLooks) do paintButton(box) end
    end
    -- Selected/disabled presentation always takes priority over pointer feedback.
    local function state(box, enabled, selected, primary)
        buttonLooks[box] = {enabled=enabled == true, selected=selected == true, primary=primary == true}
        paintButton(box)
    end
    local function card(id) return find(self.run.data.cards.cards, id) end
    local function cardName(id, upgraded, upgrades)
        local display, definition = self.presentation[id], card(id)
        return (display and display.name or (definition and definition.name) or id)
            .. (upgraded and ('+'..(definition and definition.repeatable and number(upgrades or 1) or '')) or '')
    end
    local function relicName(id)
        local definition = find(self.run.data.relics.relics, id)
        return definition and definition.name or id
    end
    local function potionText(id) return require('abyss_potion_text').describe(self.run,id) end
    local function eventOptionText(option)
        if option.rewardCard then
            local definition=assert(card(option.cardId),'missing reward definition')
            local display=assert(self.presentation[option.cardId],'missing reward display')
            local cost=display.cost
            if option.upgraded and definition.upgrade and definition.upgrade.cost~=nil then cost=number(definition.upgrade.cost)end
            return '费用 '..cost..' · '..typeNames[definition.type]..' · '
                ..({rare='稀有',uncommon='罕见'})[definition.rarity]..'｜'
                ..CardDisplay.permanentText(display,definition,option)
        end
        return option.description..(option.potionId and '\n'..potionText(option.potionId)or'')
            ..(option.cardId and '\n「'..cardName(option.cardId,option.upgraded,option.upgrades)..'」'or'')
            ..(not option.enabled and '（当前条件不足）'or'')
    end
    -- Relic data has no prose; describe its sourced trigger and effects.
    local function relicText(id)
        if id=='membership_card' then return '所有商店商品半价。' end
        if id=='courier' then return '商店商品八折，购买后补货。' end
        if id=='smiling_mask' then return '商店删牌服务固定为50金币。' end
        local definition = find(self.run.data.relics.relics, id)
        if not definition then return "" end
        if definition.description then return definition.description end
        local parts = {}
        for _, effect in ipairs(definition.effects or {}) do
            local value = number(effect.value)
            if effect.op == "heal" then parts[#parts + 1] = "回复 " .. value .. " 点生命"
            elseif effect.op == "block" then parts[#parts + 1] = "获得 " .. value .. " 点格挡"
            elseif effect.op == "draw" then parts[#parts + 1] = "抽 " .. value .. " 张牌"
            elseif effect.op == "energy" then parts[#parts + 1] = "获得 " .. value .. " 点能量"
            elseif effect.op == "gainStatus" then
                local status = find(self.run.data.statuses.statuses, effect.status)
                parts[#parts + 1] = "获得 " .. value .. " 层" .. (status and status.name or effect.status)
            end
        end
        if #parts == 0 then return "" end
        return (triggers[definition.trigger] or "") .. table.concat(parts, "，") .. "。"
    end
    -- Approved card face. look: dim (greyed but readable), veil (sold/removed), selected (glow),
    -- stamp (overlay word), changed (cost highlight).
    local artFaces={};local function fillCard(box, id, upgraded, look)
        look = look or {}
        local definition, display = card(id) or {}, self.presentation[id] or {}
        local instance=look.instance or {cardId=id,upgraded=upgraded==true}
        definition=Combat.cardDefinition({catalog={cards={[id]=definition}}},instance)
        inspectCards[box]=definition.originalV4 and {definition=definition,upgraded=instance.upgraded} or nil
        if look.inspectOnly then box:GetChild('hit'):SetVisible(definition.originalV4~=nil) end
        local kind = Theme.icon.cardArt[definition.type] and definition.type or "status"
        CardDisplay.writeTitle(box:GetChild("name"),cardName(id,false),instance.upgraded,
            definition.repeatable and (instance.upgrades or 1) or nil,box:GetChild("type"),
            typeNames[definition.type] or "")
        ink(box:GetChild("name"), look.dim and C.textMuted or upgraded and C.positive or C.text)
        local text=CardDisplay.permanentText(display,definition,instance)
        CardDisplay.writeBody(box:GetChild("description"),type(text)=='string' and text or '')
        ink(box:GetChild("description"), look.dim and C.textDim or C.text)
        -- Presentation costs can be strings; format the numeric rule value.
        local cost = definition.cost
        if upgraded and definition.upgrade and definition.upgrade.cost ~= nil then cost = definition.upgrade.cost end
        box:GetChild("cost").text = definition.cost == -2 and "" or definition.costMode == "all_energy" and "X" or cost ~= nil and number(cost) or ""
        tint(box:GetChild("costDisc"), look.dim and C.energyEmpty or look.changed and C.positive or C.energy)
        for art in pairs(Theme.icon.cardArt) do box:GetChild("art_" .. art):SetVisible(art == kind) end
        CardDisplay.writeArt(box:GetChild("art_" .. kind), definition, picture);if CardDisplay.writeNativeArt(box,definition,display.nativeArt,options,box:GetChild('art_'..kind))then artFaces[box]=true end
        tint(box:GetChild("artPlate"), look.dim and C.panelSunken or C.cardType[kind] or C.panelRaised)
        tint(box:GetChild("border"), look.selected and C.goldBright or look.dim and C.line or C.rarity[definition.rarity] or C.line)
        tint(box:GetChild("nameBand"), C.rarityBand[definition.rarity] or C.rarityBand.basic)
        tint(box:GetChild("nameRule"), C.rarity[definition.rarity] or C.line)
        ink(box:GetChild("cost"), look.dim and C.textMuted or look.changed and C.positive or C.energy)
        show(box:GetChild("glow"), look.selected)
        show(box:GetChild("veil"), look.veil)
        show(box:GetChild("stampPlate"), look.stamp ~= nil)
        show(box:GetChild("stamp"), look.stamp ~= nil)
        box:GetChild("stamp").text = look.stamp or ""
    end
    -- poor marks an offer refused only for lack of gold, so the merchant can answer it.
    local function action(key, enabled, handler, reason, poor, observe)
        self.actions[key] = { enabled = enabled == true, handler = handler, reason = reason, poor = poor == true, observe = observe }
        return enabled == true
    end

    -- These event gestures keep their render-time meaning, including paid-stage
    -- and selected UID. Once observed invalid, repair cannot revive the gesture.
    local function bindAct2Action(key, entry)
        local sourceRun, sourceMap, sourceFlow, sourceView = self.run, self.map, self.run.nodeFlow, self.view
        local sourceEvent = sourceFlow.event
        local generation, act, floor, phase = sourceRun.roomGeneration, sourceRun.act, sourceRun.floor, sourceRun.phase
        local stage, choice, complete = sourceEvent.stage, sourceEvent.choice, sourceFlow.complete
        local flowId, flowFloor, eventId = sourceFlow.id, sourceFlow.floor, sourceEvent.id
        local selected, mode, picker, page = self.selected, self.mode, self.picker, self.pickPage
        local original, handler, retired = entry.handler, nil, false
        local offers, offerEpoch, offerSnapshot = sourceEvent.offers, sourceEvent.offerEpoch, {}
        if eventId=='the_library' then
            for i, offered in ipairs(offers or {}) do
                offerSnapshot[i]={owner=offered,cardId=offered.cardId,sourceCardId=offered.sourceCardId,
                    rarity=offered.rarity,upgraded=offered.upgraded,upgrades=offered.upgrades,offerToken=offered.offerToken}
            end
        end
        local function sameOffers()
            if eventId~='the_library' then return true end
            if sourceEvent.offers~=offers or sourceEvent.offerEpoch~=offerEpoch or #(offers or {})~=#offerSnapshot then return false end
            for i, expected in ipairs(offerSnapshot) do
                local offered=offers[i]
                if offered~=expected.owner then return false end
                for _, field in ipairs({'cardId','sourceCardId','rarity','upgraded','upgrades','offerToken'})do
                    if offered[field]~=expected[field]then return false end
                end
            end
            return true
        end
        local box, owners = root, {}
        for part in key:gmatch("[^/]+") do
            local owner = box
            box = owner:GetChild(part)
            owners[#owners + 1] = { owner = owner, child = box, name = part }
        end
        local native = actionInputs[key]
        local hit = native.hit
        owners[#owners + 1] = { owner = box, child = hit, name = "hit" }
        local function owned()
            if retired then return false end
            local attached = box == native.box
            for _, link in ipairs(owners) do
                if link.owner:GetChild(link.name) ~= link.child then attached = false end
            end
            local hostAttached = not rootParent or rootParent:GetChild("nodePanel") == root
            -- Native reads may reenter: validate every captured link and owner
            -- only after the final GetChild, never adopt a replacement control.
            for _, link in ipairs(owners) do
                if link.child.parent ~= link.owner then attached = false end
            end
            local parent = hit
            while parent do
                if not parent.visible then attached = false end
                parent = parent.parent
            end
            return attached and hostAttached and root.parent == rootParent and self.root == root
                and self.visible and not self.busy and self.run == sourceRun and self.map == sourceMap
                and self.view == sourceView and self.actions[key] == entry and entry.handler == handler and entry.enabled
                and self.run.nodeFlow == sourceFlow and sourceFlow.event == sourceEvent
                and sourceRun.roomGeneration == generation and sourceRun.act == act and sourceRun.floor == floor
                and sourceRun.phase == phase and sourceFlow.complete == complete
                and sourceFlow.id == flowId and sourceFlow.floor == flowFloor and sourceFlow.type == "event"
                and sourceEvent.id == eventId and sourceEvent.stage == stage and sourceEvent.choice == choice
                and self.selected == selected and self.mode == mode and self.picker == picker and self.pickPage == page
                and sameOffers()
        end
        local function observe()
            if owned() then return true end
            retired = true
            return false
        end
        handler = function()
            if not observe() then return false, "stale_action" end
            return original()
        end
        entry.handler, entry.observe = handler, observe
        entry.retire = function() retired = true end
    end

    local commit -- forward declaration; renders and notifies
    local function pageArrows(view, prefix, page, count)
        local previous = view:GetChild(prefix == "" and "previous" or prefix .. "Previous")
        local next = view:GetChild(prefix == "" and "next" or prefix .. "Next")
        show(previous, count > 1) show(next, count > 1)
        state(previous, page > 1) state(next, page < count)
        -- Paging is secondary to the goods: keep the arrows' frames quiet.
        if page > 1 then tint(previous:GetChild("border"), C.goldDim) end
        if page < count then tint(next:GetChild("border"), C.goldDim) end
    end

    local function renderTopBar(node)
        EndingUI.header(self,child,node and node.type=='ending_proceed')
        child("title").text = node and ("第 " .. node.floor .. " 层 · " ..
            (node.roomKind == "boss_treasure" and "首领宝箱" or kinds[node.type] or "节点")) or "路线"
        child("hp").text = number(self.run.hp) .. "/" .. number(self.run.maxHp)
        child("gold").text = number(self.run.gold)
        child("deck").text = tostring(#self.run.deck)
        child("relics").text = "遗物 " .. #self.run.relics
        child("potions").text = "药水 " .. Run.potionCount(self.run) .. "/" .. Run.potionCapacity(self.run)
    end

    local campUI=CampUI.new(self,{child=child,show=show,state=state,fillCard=fillCard,action=action})
    local function enhancedForge(node)return options.enhancedRooms and node.type=='camp' and self.picker=='upgrade'end
    local renderShop = ShopUI.new(self, {
        selection = shopSelection,
        child = child, show = show, state = state, ink = ink, picture = picture,
        fillCard = fillCard, cardName = cardName, relicName = relicName, relicText = relicText,
        action = action, pageArrows = pageArrows,
        commit = function(...) return commit(...) end,
    })

    local function renderCamp(view, node, result)
        local camp = child("campView")
        local rest, forge = camp:GetChild("rest"), camp:GetChild("forge")
        local outcome=options.enhancedRooms and result~=nil
        show(rest,not outcome);show(forge,not outcome);show(camp:GetChild('result'),outcome)
        if result then
            state(rest, false, result.choice == "rest") state(forge, false, result.choice == "upgrade")
            rest:GetChild("description").text = result.choice == "rest" and
                ("已回复 " .. number(result.healed) .. " 点生命\n生命 " .. number(self.run.hp) .. "/" .. number(self.run.maxHp)
                    ..(result.rewardText and '\n'..result.rewardText or '')) or "未选择"
            forge:GetChild("description").text = result.choice == "upgrade" and "已升级" or "未选择"
            camp:GetChild('result'):GetChild('description').text=rest:GetChild('description').text
            return
        end
        local forgeable = #node.upgradeCards > 0
        -- Full-health rest remains available for Dream Catcher's real reward,
        -- or when the camp has no forgeable card and needs an exit.
        local restOpen = node.heal > 0 or node.dreamCatcher or not forgeable
        state(rest, restOpen) state(forge, forgeable)
        rest:GetChild("description").text = node.heal > 0 and
            ("回复 " .. number(node.heal) .. " 点生命\n生命 " .. number(self.run.hp) .. " → " .. number(self.run.hp + node.heal)) or
            (node.dreamCatcher and "生命已满\n捕梦网：可选一张牌" or forgeable and "生命已满" or "生命已满 · 休息后继续前进")
        if node.dreamCatcher and node.heal>0 then rest:GetChild('description').text=rest:GetChild('description').text..'\n捕梦网：可选一张牌' end
        forge:GetChild("description").text = forgeable and
            ("升级一张卡牌\n可升级 " .. #node.upgradeCards .. " 张") or "没有可升级的卡牌"
        action("campView/rest", restOpen, function()
            return commit("rest", nil, function(before)
                local healed = self.run.hp - before.hp
                if self.run.nodeFlow.restReward and not self.run.nodeFlow.restReward.resolved then
                    self.mode,self.picker,self.pickPage,self.selected='picker','dream_catcher',1,nil
                    return '休息完成 · 回复 '..number(healed)..' 点生命；请选择卡牌或跳过'
                end
                return "休息完成 · 回复 " .. number(healed) .. " 点生命", { choice = "rest", healed = healed }
            end)
        end, "生命已满，休息不会回复；可以选择锻造")
        action("campView/forge", forgeable, function()
            self.mode, self.picker, self.pickPage, self.selected, self.notice = "picker", "upgrade", 1, nil, ""
            self:render() return true
        end, "牌组中没有可升级的卡牌")
        -- Recall is the last action: reuse the existing footer, never derive eligibility here.
        local source = type(Nodes.recallSource) == "function" and type(Nodes.recall) == "function"
            and Nodes.recallSource(self.run, self.map) or nil
        if type(source) ~= "table" then source = nil end
        return source and "篝火旁 · 休息、锻造或 Recall，只能选一项"
            or "篝火旁，旅行者稍作停留 · 休息或锻造，只能选一项", source
    end

    local function renderPicker(view, node, result)
        if enhancedForge(node) then return campUI:render(node,result) end
        local picker = child("pickerView")
        show(picker:GetChild('forgeGrid'),false)
        show(picker:GetChild('forgePrevious'),false);show(picker:GetChild('forgeNext'),false)
        for _,name in ipairs({'before','after'})do
            picker:GetChild(name):SetLocalScale(1,1,1)
            picker:GetChild(name):SetAnchoredPosition(layout.picker[name],layout.picker.previewY)
        end
        for _,name in ipairs({'label','hint','page','arrow'})do
            local values=layout.picker[name]
            picker:GetChild(name):SetAnchoredPosition(values[1],values[2])
        end
        local before, after, target = picker:GetChild("before"), picker:GetChild("after"), picker:GetChild("target")
        local upgrade = self.picker == "upgrade" or self.picker=='living_grow' or self.picker=='act1_forge'
            or self.picker=='neow_card' and node.event.selection.forUpgrade
        local transform = self.picker=='living_change' or self.picker=='act1_change'
            or self.picker=='neow_card' and node.event.selectedType:match('^TRANSFORM')~=nil
        local dream=self.picker=='dream_catcher'
        local library=self.picker=='library_offer'
        local acquiring=dream or library
        local rows = library and self.offerRows or dream and self.restRows or upgrade and self.upgradeRows or self.removeRows
        local selected = result and result.card or self.selected and find(rows, self.selected, library and 'offerToken' or 'uid')
        local pageCount = math.max(1, math.ceil(#rows / PICK_PAGE))
        self.pickPage = math.max(1, math.min(self.pickPage or 1, pageCount))
        self.pageCount = pageCount
        for i = 1, PICK_PAGE do
            local instance = not result and rows[(self.pickPage - 1) * PICK_PAGE + i]
            local box = picker:GetChild("card" .. i)
            show(box, instance)
            if instance then
                local owned = not acquiring and find(self.run.deck, instance.uid, "uid") or nil
                local ambiguous = false
                if self.picker=='beggar_purge' or self.picker=='basics_purge' then
                    local matches=0
                    for _, candidate in ipairs(self.run.deck) do if candidate.uid==instance.uid then matches=matches+1 end end
                    ambiguous=matches~=1
                    if ambiguous then owned=nil end
                end
                local available = not ambiguous and (acquiring or owned ~= nil and (not upgrade or find(node.upgradeCards, instance.uid, "uid") ~= nil))
                local stamp = ambiguous and "编号异常" or not acquiring and (not owned and "已移除" or (upgrade and owned.upgraded and not card(instance.cardId).repeatable and "已升级")) or nil
                fillCard(box, instance.cardId, owned and owned.upgraded or instance.upgraded,
                    { dim = not available, veil = stamp ~= nil, stamp = stamp, selected = self.selected == (library and instance.offerToken or instance.uid),instance=owned or instance })
                local uid = library and instance.offerToken or instance.uid
                action("pickerView/card" .. i, available, function()
                    self.selected, self.notice = uid, "" self:render() return true
                end, stamp and ("这张卡牌" .. stamp) or "这张卡牌无法升级")
            end
        end
        pageArrows(picker, "", self.pickPage, result and 1 or pageCount)
        action("pickerView/previous", self.pickPage > 1, function()
            self.pickPage, self.notice = self.pickPage - 1, "" self:render() return true end)
        action("pickerView/next", self.pickPage < pageCount, function()
            self.pickPage, self.notice = self.pickPage + 1, "" self:render() return true end)
        picker:GetChild("page").text = not result and pageCount > 1 and ("第 " .. self.pickPage .. "/" .. pageCount .. " 页 · 共 " .. #rows .. " 张"
            .. (self.swipeEnabled and " · 左右拖动翻页" or "")) or ""
        show(before, upgrade and selected) show(after, upgrade and selected)
        show(picker:GetChild("arrow"), upgrade and selected) show(target, not upgrade and selected)
        picker:GetChild("empty").text = selected and "" or (library and '点选一张卡牌加入牌组，不能跳过' or dream and '点选一张卡牌加入牌组，也可以跳过' or upgrade and "点选上方卡牌，查看升级前后对比" or transform and '点选上方要变换的卡牌' or "点选上方要移除的卡牌")
        picker:GetChild("label").text, picker:GetChild("hint").text = "", ""
        if selected and upgrade then
            local display = self.presentation[selected.cardId] or {}
            local changed = display.cost ~= nil and display.upgradeCost ~= nil and display.cost ~= display.upgradeCost
            local nextInstance=Combat.copy(selected)
            nextInstance.upgrades=(selected.upgrades or (selected.upgraded and 1 or 0))+1
            nextInstance.upgraded=true
            fillCard(before, selected.cardId, selected.upgraded,{instance=selected,inspectOnly=true})
            fillCard(after, selected.cardId, true, { changed = changed,instance=nextInstance,inspectOnly=true })
            picker:GetChild("label").text = result and "已升级" or "升级预览"
            picker:GetChild("hint").text = changed and ("费用 " .. display.cost .. " → " .. display.upgradeCost) or "效果增强"
        elseif selected then
            fillCard(target, selected.cardId, selected.upgraded, { stamp = result and "已移除" or nil, dim = result ~= nil, veil = result ~= nil,instance=selected })
            picker:GetChild("label").text = acquiring and '将加入牌组' or transform and "将变换为随机的新卡牌" or result and "已移除" or "将从牌组移除"
            picker:GetChild("hint").text = acquiring and ('牌组 '..#self.run.deck..' → '..(#self.run.deck+1)..' 张') or transform and "新卡牌不会保留原来的升级" or "牌组 " .. (#self.run.deck + (result and 1 or 0)) .. " → " ..
                (#self.run.deck - (result and 0 or 1)) .. " 张"
        end
        if self.picker=='neow_card'then return '开局恩赐 · 还需选择 '..node.event.selection.count..' 张卡牌，不能取消' end
        if self.picker=='basics_purge' then return '优雅 · 免费移除一张非瓶装、可清除的永久牌' end
        if self.picker=='beggar_purge' then
            if node.event.pendingBoundary then
                picker:GetChild("empty").text='没有可清除的卡牌；强制选牌保持待处理，不能跳过或退款。'
            end
            return '已支付75金币 · 必须移除一张非瓶装、可清除的永久牌，不能取消'
        end
        if library then return '图书馆 · 从20张不同的卡牌中选择一张，不能跳过' end
        if dream then return '捕梦网 · 选择一张卡牌加入牌组，或跳过奖励' end
        if upgrade then return "选择一张卡牌升级 · 剩余 " .. (result and 0 or node.upgradesLeft) .. " 次" end
        if transform then return '选择一张卡牌变换' end
        if self.picker == "remove" then return "选择要移除的卡牌 · 本店删牌服务限一次" end
        return "选择要净化的卡牌"
    end

    local function renderEvent(view, node, result)
        local event = child("eventView")
        local id = node.event and node.event.id or (result and result.eventId)
        local copy = events[id] or { name = kinds.event, body = "", leave = "你离开了。" }
        event:GetChild("name").text = copy.name
        local mode=self.run.unknown and self.run.unknown.pools and self.run.unknown.pools.mode or self.run.data.rules.events.poolMode
        event:GetChild("caption").text = (stagedEvent(id) or Act3Events.ids[id]) and kinds.event or mode=='restricted-seven' and "未知事件 · 受限事件池（7种）"
            or mode=='restricted-six' and "未知事件 · 受限事件池（6种）" or kinds.event
        local body=result and result.text or node.event and node.event.body or copy.body
        if not result and node.event and node.event.stage=='result' and node.event.obtainedRelicId then
            body=body..'\n获得遗物：'..relicName(node.event.obtainedRelicId)..'。'
        end
        if not result and node.event.stage=='relic_reward' and node.event.relicOffer then
            body=body..'\n可领取遗物：'..relicName(node.event.relicOffer.id)..'。'
        end
        if not result and id=='transmogrifier' and node.event.obtainedCardUid then
            local obtained=find(self.run.deck,node.event.obtainedCardUid,'uid')
            body=body..'\n已变换为：'..cardName(obtained.cardId,obtained.upgraded)..'。'
        end
        event:GetChild("body").text = body
        local rows = {}
        if not result then
            local info, gold, deckOk = node.event, self.run.gold, #node.purgeCards > 0
            local function need(cost) return "金币不足（需要 " .. cost .. "，现有 " .. gold .. "）" end
            local function purify(cost)
                return function()
                    self.mode, self.picker, self.pickPage, self.selected, self.notice = "picker", "purify", 1, nil, ""
                    self:render() return true
                end
            end
            if id ~= 'cleric' and id ~= 'purifier' then
                for _,option in ipairs(info.options) do
                    local selected=option
                    rows[#rows+1]={title='［'..(selected.rewardCard and cardName(selected.cardId,selected.upgraded)or selected.title)..'］',
                        description=eventOptionText(selected),enabled=selected.enabled,handler=function()
                        -- Repeated-search events retain the same command after
                        -- rendering new odds. An old callback is still stale.
                        if self.view~=view or self.renderRun~=self.run or self.renderMap~=self.map then return false,'stale_action' end
                        if Act1Events.ids[id] or (stagedEvent(id) or Act3Events.ids[id]) then
                            return commit('chooseEvent',selected.choice,function()
                                local outcome=self.run.nodeFlow.event
                                local text=outcome.body or '请选择一张卡牌。'
                                -- These state machines already keep their result
                                -- screen until Leave; completion needs no extra hold.
                                return text
                            end)
                        end
                        if id=='living_wall' then
                            return commit('chooseEvent',selected.choice,function()
                                local info=self.run.nodeFlow.event
                                if info.stage=='choose_card' then
                                    self.mode,self.picker,self.pickPage,self.selected='picker','living_'..selected.choice,1,nil
                                    return '请选择一张卡牌'
                                end
                                local text='没有符合条件的卡牌。墙上的面孔渐渐沉寂。'
                                return text,{text=text}
                            end)
                        end
                        if selected.picker then
                            self.mode,self.picker,self.pickPage,self.selected,self.notice='picker',
                                selected.picker=='event_upgrade' and 'upgrade' or selected.picker,1,nil,''
                            self:render();return true
                        end
                        return commit('chooseEvent',selected.choice,function(before)
                            local outcome=self.run.nodeFlow.event
                            -- 只列出实际变化的资源，未变化的生命/金币不显示
                            local lines,changes={},{}
                            if self.run.hp~=before.hp then changes[#changes+1]='生命 '..number(before.hp)..' → '..number(self.run.hp) end
                            if self.run.gold~=before.gold then changes[#changes+1]='金币 '..number(before.gold)..' → '..number(self.run.gold) end
                            if #changes>0 then lines[1]=table.concat(changes,'；') end
                            if outcome.upgradedUids and #outcome.upgradedUids>0 then
                                local names={}
                                for _,uid in ipairs(outcome.upgradedUids) do
                                    local card=find(self.run.deck,uid,'uid');names[#names+1]=cardName(card.cardId,true,card.upgrades)
                                end
                                lines[#lines+1]='已升级：'..table.concat(names,'、')
                            end
                            if outcome.obtainedCardUid then
                                local obtained=find(self.run.deck,outcome.obtainedCardUid,'uid')
                                lines[#lines+1]='已获得诅咒：'..cardName(obtained.cardId,false)
                            end
                            if outcome.removedUids then
                                lines[#lines+1]='已移除诅咒：'..#outcome.removedUids..' 张'
                            end
                            local text=#lines>0 and table.concat(lines,'\n') or '什么也没有发生。'
                            return text,{text=text}
                        end)
                    end}
                end
            elseif id == "cleric" then
                local healOk = gold >= info.healCost
                rows[1] = { title = "［治疗］", enabled = healOk, handler = function()
                        return commit("chooseEvent", "heal", function(before)
                            local healed = self.run.hp - before.hp
                            return "治疗完成 · 回复 " .. number(healed) .. " 点生命", { text = "圣职者的祝祷落在你身上，伤口渐渐愈合。\n支付 " ..
                                number(before.gold - self.run.gold) .. " 金币，回复 " .. number(healed) .. " 点生命（生命 " .. number(before.hp) .. " → " .. number(self.run.hp) .. "）。" }
                        end)
                    end,
                    description = not healOk and need(info.healCost) or (info.heal > 0 and
                        ("支付 " .. number(info.healCost) .. " 金币，回复 " .. number(info.heal) .. " 点生命（生命 " .. number(self.run.hp) .. " → " .. number(self.run.hp + info.heal) .. "）")
                        or ("支付 " .. info.healCost .. " 金币；生命已满，不会回复")) }
                local purifyOk = gold >= info.removeCost and deckOk
                rows[2] = { title = "［净化］", enabled = purifyOk, handler = purify(info.removeCost),
                    description = gold < info.removeCost and need(info.removeCost) or
                        (deckOk and ("支付 " .. info.removeCost .. " 金币，从牌组移除一张卡牌") or "没有可移除的卡牌") }
            else
                rows[1] = { title = "［祈祷］", enabled = deckOk, handler = purify(info.removeCost),
                    description = deckOk and (info.removeCost > 0 and ("支付 " .. info.removeCost .. " 金币，从牌组移除一张卡牌")
                        or "免费从牌组移除一张卡牌") or "没有可移除的卡牌" }
            end
            if id=='cleric' or id=='purifier' then rows[#rows + 1] = { title = "［离开］", enabled = true, description = "什么也不会发生。", handler = function()
                return commit("chooseEvent", "leave", function() return "已离开" .. copy.name, { text = copy.leave } end)
            end } end
        end
        for i = 1, OPTIONS do
            local row, box = rows[i], event:GetChild("option" .. i)
            show(box, row)
            if row then
                state(box, row.enabled)
                box:GetChild("title").text = row.title
                box:GetChild("description").text = row.description
                ink(box:GetChild("title"), row.enabled and C.goldBright or C.textMuted)
                ink(box:GetChild("description"), row.enabled and C.textDim or C.textMuted)
                action("eventView/option" .. i, row.enabled, row.handler, row.description)
            end
        end
        if (stagedEvent(id) or Act3Events.ids[id]) then return copy.name .. ' · 请选择上方选项' end
        return result and copy.name or (copy.name .. " · 选择一项，或直接离开")
    end

    -- A linked choice owns its render-time token and meaning, never the current footer.
    local function bindTreasureChoice(key, box, source, choice, name)
        local sourceRun, sourceMap, sourceFlow, sourceView = self.run, self.map, self.run.nodeFlow, self.view
        local sourceReward, sourceParent = sourceFlow.reward, box.parent
        local sourceLink, sourceItems = sourceReward.sapphireKey, sourceReward.items
        local handler
        local function owned()
            local control, links = root, {}
            for part in key:gmatch("[^/]+") do
                local owner = control
                control = owner and owner:GetChild(part)
                links[#links + 1] = { child = control, owner = owner }
            end
            local hostAttached = not rootParent or rootParent:GetChild("nodePanel") == root
            -- Revalidate the entire captured ancestry AFTER the final native read.
            for _, link in ipairs(links) do
                if not link.child or link.child.parent ~= link.owner then return false end
            end
            local look, parent = buttonLooks[box], box
            if control ~= box or box.parent ~= sourceParent or not look or not look.enabled or look.selected then return false end
            while parent do
                if not parent.visible then return false end
                parent = parent.parent
            end
            -- GetChild may reenter a host render. All owner/action tests follow its last read.
            local entry = self.actions[key]
            return hostAttached and root.parent == rootParent and self.root == root and self.visible and not self.busy
                and self.run == sourceRun and self.map == sourceMap and self.view == sourceView
                and self.mode == "main" and self.opened == true and self.run.nodeFlow == sourceFlow
                and self.run.roomGeneration == source.roomGeneration and self.run.act == source.act
                and sourceFlow.reward == sourceReward and sourceReward.sapphireKey == sourceLink and sourceReward.items == sourceItems
                and sourceReward.relicId == source.relicId and sourceLink and sourceLink.relicId == source.relicId
                and entry and entry.enabled and entry.handler == handler
        end
        local function observe()
            if not owned() or type(Nodes.treasureSource) ~= "function" or type(Nodes.chooseTreasure) ~= "function" then return false end
            local currentSource = Nodes.treasureSource(sourceRun, sourceMap)
            if type(currentSource) ~= "table" then return false end
            for field, value in pairs(source) do if currentSource[field] ~= value then return false end end
            return owned()
        end
        handler = function()
            if not owned() or type(Nodes.chooseTreasure) ~= "function" then return false, "stale_action" end
            return commit("chooseTreasure", source, function()
                return choice == "sapphire" and ("已获得蓝钥匙 · 已放弃遗物「" .. name .. "」") or ("已获得遗物「" .. name .. "」")
            end, choice)
        end
        return handler, observe
    end

    local function renderTreasure(view, node)
        if node.chest then return require('abyss_treasure_ui').render({self=self,node=node,child=child,
            show=show,tint=tint,state=state,picture=picture,action=action,commit=commit,relicName=relicName,relicText=relicText,
            list=options.enhancedRooms==true,details=rewardDetail}) end
        local chest = child("treasureView")
        local reward = node.reward
        local boss = node.roomKind == "boss_treasure"
        local choices = boss and reward.relics or nil
        self.treasureChoice = math.min(self.treasureChoice or 1, choices and #choices or 1)
        local relicId = boss and choices[self.treasureChoice] or reward.relicId
        local opened = self.opened == true
        local source = opened and not boss and type(Nodes.treasureSource) == "function" and type(Nodes.chooseTreasure) == "function"
            and Nodes.treasureSource(self.run, self.map) or nil
        if type(source) ~= "table" or source.relicId ~= relicId then source = nil end
        show(chest:GetChild("closed"), not opened) show(chest:GetChild("open"), opened)
        show(chest:GetChild("hint"), not opened)
        tint(chest:GetChild("glow"), opened and C.gold or C.goldDim)
        local row, take = chest:GetChild("reward"), chest:GetChild("take")
        local hasReward = not boss or #choices > 0
        show(row, opened and hasReward) show(take, opened and hasReward)
        local name = relicId and relicName(relicId) or (not boss and (number(reward.gold) .. " 金币") or "")
        for _, key in ipairs({"previous", "next", "page", "bossDescription"}) do show(chest:GetChild(key), opened and boss) end
        take:GetChild("label").text = source and "领取遗物" or boss and "领取这件遗物" or "拿取并离开"
        if opened and hasReward then
            state(row, true) state(take, true, false, true)
            picture(row:GetChild("icon"), relicId and (Theme.icon.relic[relicId] or Theme.icon.node.treasure) or Theme.icon.gold)
            row:GetChild("name").text = relicId and ("遗物 · " .. name) or name
            row:GetChild("description").text = boss and "使用左右按钮查看，领取其中一件" or relicId and relicText(relicId) or "遗物已全部持有，改为金币"
            if boss then
                chest:GetChild("page").text = "首领遗物 · " .. self.treasureChoice .. " / " .. #choices .. " · 选择一件"
                chest:GetChild("bossDescription").text = relicText(relicId)
                state(chest:GetChild("previous"), self.treasureChoice > 1)
                state(chest:GetChild("next"), self.treasureChoice < #choices)
            end
        end
        if boss and not hasReward then
            show(chest:GetChild("previous"), false) show(chest:GetChild("next"), false)
            chest:GetChild("page").text = "没有可领取的首领遗物"
            chest:GetChild("bossDescription").text = "可用遗物已持有或不满足领取条件，请跳过奖励。"
        end
        for _, step in ipairs({{key="previous", delta=-1}, {key="next", delta=1}}) do
            local choice = self.treasureChoice + step.delta
            action("treasureView/" .. step.key, opened and boss and choice >= 1 and choice <= #choices, function()
                self.treasureChoice, self.notice = choice, "" self:render() return true
            end)
        end
        action("treasureView/chest", not opened, function()
            self.opened, self.notice = true, ""
            if options.sound then pcall(options.sound, "treasure_open") end
            self:render() return true
        end)
        local takeFn, takeObserve
        if source then takeFn, takeObserve = bindTreasureChoice("treasureView/take", take, source, "relic", name)
        else takeFn = function()
            return commit(boss and "claimBossTreasure" or "claimTreasure", boss and self.treasureChoice or nil,
                function() return "已获得" .. (relicId and ("遗物「" .. name .. "」") or name) end)
        end end
        action("treasureView/take", opened and hasReward, takeFn, nil, nil, takeObserve)
        if source then return "遗物与蓝钥匙只能选一项 · 选择蓝钥匙将放弃遗物「" .. name .. "」", source end
        return opened and (boss and "选择一件首领遗物，或跳过奖励后完成本局" or
            ("宝箱已打开 · 获得" .. (relicId and "遗物" or "金币"))) or "宝箱就在眼前"
    end

    function self:holding()
        local result = self.result
        return result ~= nil and result.run == self.run and result.map == self.map and
            self.run.nodeFlow ~= nil and self.run.nodeFlow.id == result.nodeId and self.run.nodeFlow.complete == true
    end

    local function syncNodeIdentity(node)
        if self.renderRun ~= self.run or self.renderMap ~= self.map or self.nodeId ~= (node and node.id) then
            self.page, self.relicPage, self.pickPage, self.mode, self.picker = 1, 1, 1, "main", nil
            self.selected, self.opened, self.notice, self.result, self.treasureChoice = nil, false, "", nil, 1
            self.upgradeRows = node and node.upgradeCards or {}
            self.removeRows = snapshotDeck(node and node.purgeCards or {})
        end
    end
    local function syncLivingPicker(node,active)
        if active and node.type=='event' and node.event.id=='living_wall' and node.event.stage=='choose_card' then
            self.mode,self.picker='picker','living_'..node.event.choice
            self.removeRows=snapshotDeck(node.event.purgeCards)
            self.upgradeRows=node.upgradeCards
        end
    end
    local function syncLibraryPicker(node)
        self.mode,self.picker='picker','library_offer'
        self.offerRows=Combat.copy(node.event.offers)
        if not find(self.offerRows,self.selected,'offerToken')then self.selected=nil end
    end
    local function syncAct2PurgePicker(node)
        self.mode,self.picker='picker',node.event.id=='beggar' and 'beggar_purge' or 'basics_purge'
        self.removeRows=Combat.copy(node.event.purgeCards)
        local matches=0
        for _, instance in ipairs(self.run.deck) do if instance.uid==self.selected then matches=matches+1 end end
        if matches~=1 or not find(self.removeRows,self.selected,'uid') then self.selected=nil end
    end
    local function syncAct2Picker(node,active)
        if active and node.type=='event' and Act2Events.ids[node.event.id] then
            if node.event.id=='the_library' and node.event.stage=='choose_offer' then
                syncLibraryPicker(node)
            elseif (node.event.id=='beggar' or node.event.id=='back_to_basics') and node.event.stage=='choose_card' then
                syncAct2PurgePicker(node)
            else self.mode,self.picker,self.selected='main',nil,nil end
        end
    end
    local function syncNeowPicker(node,active)
        if active and node.type=='event' and node.event.id=='neow'then
            if node.event.stage=='neow_choose_card'then
                self.mode,self.picker='picker','neow_card'
                self.removeRows,self.upgradeRows=Combat.copy(node.event.purgeCards),Combat.copy(node.event.purgeCards)
                if not find(self.removeRows,self.selected,'uid')then self.selected=nil end
            else self.mode,self.picker,self.selected='main',nil,nil end
        end
    end
    local function syncRestPicker(node,active)
        if active and node.type=='camp' and node.restReward and not node.restReward.resolved then
            self.mode,self.picker='picker','dream_catcher';self.restRows={}
            for i,id in ipairs(node.restReward.cards)do self.restRows[i]={uid=i,cardId=id,upgraded=node.restReward.cardUpgrades and node.restReward.cardUpgrades[i]==true}end
        end
    end
    local function syncAct1Picker(node,active)
        if active and node.type=='event' and (node.event.id=='accursed_blacksmith' or node.event.id=='bonfire' or node.event.id=='transmogrifier' or node.event.id=='wheel') then
            if node.event.stage=='choose_card' then
                self.mode,self.picker='picker','act1_'..node.event.choice
                self.removeRows=snapshotDeck(node.event.purgeCards or {})
                self.upgradeRows=node.upgradeCards
            else self.mode,self.picker,self.selected='main',nil,nil end
        end
    end
    local function syncNodePicker(node,active)
        syncLivingPicker(node,active)
        syncAct2Picker(node,active)
        syncNeowPicker(node,active)
        syncRestPicker(node,active)
        syncAct1Picker(node,active)
    end
    local function nodeScreen(_view,node,result,active)
        if node and node.type=='ending_proceed' then return 'eventView','确认继续后进入真结局。' end
        local screen, hint = nil, node and "请完成当前节点。" or "请在路线中选择下一个节点。"
        if node and node.complete then hint = "本节点已完成，可以返回路线。" end
        if active and self.mode == "picker" then screen = "pickerView"
        elseif active then screen = node.type .. "View"
        elseif result then screen = result.view end
        if active and node.type == "camp" and node.campChoice == "upgrade" then self.mode, self.picker, screen = "picker", "upgrade", "pickerView" end
        return screen,hint
    end
    local function renderNodePage(view,node,result,active)
        local screen,hint=nodeScreen(view,node,result,active)
        local recallSource,treasureSource
        for _, name in ipairs({ "shopView", "campView", "pickerView", "eventView", "treasureView" }) do show(child(name), name == screen) end
        if screen == "shopView" then hint = renderShop(view, node)
        elseif screen == "campView" then hint, recallSource = renderCamp(view, node, result)
        elseif screen == "pickerView" then hint = renderPicker(view, node, result)
        elseif screen == "eventView" then
            if node.type=='ending_proceed' then hint=EndingUI.render(child('eventView'),OPTIONS)
            else hint = renderEvent(view, node, result) end
        elseif screen == "treasureView" then hint, treasureSource = renderTreasure(view, node) end
        return screen,hint,recallSource,treasureSource
    end
    local function refreshNodeNotice(node,active,hint)
        -- The merchant speaks in his own dialogue box; the notice keeps only shop facts.
        if node and node.type == "shop" and (self.merchantNode ~= node.id or self.merchantRun ~= self.run) then
            self.merchantNode, self.merchantRun = node.id, self.run
            merchant:enter(self.run)
        end
        merchant:setVisible(node ~= nil and node.type == "shop" and self.mode == "main" and (active or node.complete))
        child("notice").text = self.notice ~= "" and self.notice or hint
        ink(child("notice"), self.failed and self.notice ~= "" and C.danger or C.text)

    end
    local function eventPickerLabel(living,act1)
        local confirmLabel
        if act1 then
            confirmLabel=self.picker=='act1_forge' and '确认升级' or self.picker=='act1_change' and '确认变换' or self.picker=='act1_purge' and '确认移除' or '确认献祭'
        elseif living then
            confirmLabel=self.picker=='living_grow' and '确认升级' or self.picker=='living_change' and '确认变换' or '确认移除'
        end
        return confirmLabel
    end
    local function pickerLabels(node,living,act1,dream,restReward)
        if enhancedForge(node) then return CampUI.labels(self.selected,node,self.run) end
        local backLabel,confirmLabel,skipRestReward
        if dream then
            confirmLabel,backLabel='选择此牌','跳过卡牌'
            skipRestReward=function()return restReward(0)end
        elseif self.picker=='neow_card' or self.picker=='library_offer'then
            confirmLabel='确认选择'
        elseif self.picker=='beggar_purge' or self.picker=='basics_purge' then
            confirmLabel='确认移除'
        elseif act1 or living then
            confirmLabel=eventPickerLabel(living,act1)
        elseif self.picker == "upgrade" then
            confirmLabel = "确认升级"
            if not node.campChoice then backLabel = "返回" end
        elseif self.picker == "remove" then
            confirmLabel, backLabel = "删除 · " .. node.removePrice .. " 金币", "返回"
        else
            confirmLabel, backLabel = node.event.removeCost > 0 and ("净化 · " .. node.event.removeCost .. " 金币") or "祈祷 · 移除", "返回"
        end
        return backLabel,confirmLabel,skipRestReward
    end
    local function pickerCommand(node,act1,living)
        local command = act1 and 'chooseAct1EventCard' or living and "chooseLivingWallCard" or self.picker == "upgrade" and (node.type=="event" and "upgradeEvent" or "upgrade")
            or self.picker=='wing_purge' and 'purgeWing' or self.picker == "remove" and "removeCard" or "purifyEvent"
        return command
    end
    local function pickerFooter(node)
        local backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward
        local selected = self.selected
        local living=node.type=='event' and node.event.id=='living_wall'
        local act1=node.type=='event' and (node.event.id=='accursed_blacksmith' or node.event.id=='bonfire' or node.event.id=='transmogrifier' or node.event.id=='wheel')
        local dream=self.picker=='dream_catcher'
        local function restReward(choice)
            local id=node.restReward.cards[choice]
            return commit('claimRestReward',choice,function()
                local obtained=self.run.deck[#self.run.deck]
                local text=choice==0 and '已跳过卡牌奖励' or ('已获得「'..cardName(id,obtained.upgraded,obtained.upgrades)..'」')
                self.mode,self.picker,self.selected='main',nil,nil
                return text,{choice='rest',healed=self.run.nodeFlow.restHealed,rewardText=text}
            end)
        end
        backLabel,confirmLabel,skipRestReward=pickerLabels(node,living,act1,dream,restReward)
        confirmOk = selected ~= nil
        confirmFn = function()
            if dream then return restReward(selected) end
            if self.picker=='neow_card' or self.picker=='library_offer'then
                return commit('chooseEvent','select',function()
                    self.selected=nil;return self.run.nodeFlow.event.body
                end,selected)
            end
            if self.picker=='beggar_purge' or self.picker=='basics_purge' then
                return commit('chooseEvent','purge',function()return '已移除所选卡牌' end,selected)
            end
            local instance = find(self.upgradeRows, selected, "uid") or find(self.removeRows, selected, "uid")
            local name = instance and cardName(instance.cardId, instance.upgraded,instance.upgrades) or ""
            local command=pickerCommand(node,act1,living)
            return commit(command, selected, function(before)
                if act1 then
                    local text=self.run.nodeFlow.event.body or '选择完成。'
                    return text,{text=text}
                end
                if living then
                    local event=self.run.nodeFlow.event
                    local text
                    if event.choice=='grow' then text='已升级「'..name..'」'
                    elseif event.choice=='forget' then text='已移除「'..name..'」'
                    else
                        local obtainedCard=find(self.run.deck,event.obtainedCardUid,'uid')
                        text='「'..name..'」已变换为「'..cardName(obtainedCard.cardId,obtainedCard.upgraded)..'」'
                    end
                    return text,{text=text}
                end
                if command == "upgrade" or command=='upgradeEvent' then
                    local upgraded=find(self.run.deck,selected,'uid')
                    local text="已升级「"..name.."」→「"..cardName(instance.cardId,true,upgraded.upgrades).."」"
                    return text, { choice = "upgrade", card = instance, text=text }
                end
                local paid = before.gold - self.run.gold
                local text = "已移除「" .. name .. "」" .. (paid > 0 and (" · 支付 " .. number(paid) .. " 金币") or "")
                return text, { card = instance, text = "「" .. name .. "」已从牌组中移除" ..
                    (paid > 0 and ("，支付 " .. number(paid) .. " 金币。") or "。") .. "\n牌组现有 " .. #self.run.deck .. " 张。" }
            end)
        end
        return backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,nil
    end
    local function treasureFooter(treasureSource, confirm)
        local confirmLabel,confirmOk,confirmFn,recallObserve
        confirmLabel, confirmOk = "蓝钥匙", true
        confirmFn, recallObserve = bindTreasureChoice("confirm", confirm, treasureSource, "sapphire", relicName(treasureSource.relicId))
        return nil,confirmLabel,confirmOk,confirmFn,nil,recallObserve
    end
    local function recallFooter(recallSource, confirm)
        local confirmLabel,confirmOk,confirmFn,recallObserve
        local sourceRun, sourceMap, sourceFlow = self.run, self.map, self.run.nodeFlow
        confirmLabel, confirmOk = "Recall", true
        local function attachedControls()
            local attached = root:GetChild("confirm") == confirm
            local hostAttached = not rootParent or rootParent:GetChild("nodePanel") == root
            local look, parent = buttonLooks[confirm], confirm
            if not attached or confirm.parent ~= root or not look or not look.enabled or look.selected then return false end
            while parent do
                if not parent.visible then return false end
                parent = parent.parent
            end
            return true,hostAttached
        end
        local function owned()
            local valid,hostAttached=attachedControls()
            if not valid then return false end
            -- Final ownership check follows the last native read: GetChild can reenter a host render.
            local entry = self.actions.confirm
            return hostAttached and root.parent == rootParent and self.root == root and self.visible and not self.busy
                and self.run == sourceRun and self.map == sourceMap
                and self.run.nodeFlow == sourceFlow and self.run.roomGeneration == recallSource.roomGeneration
                and self.run.act == recallSource.act and entry and entry.enabled and entry.handler == confirmFn
        end
        recallObserve = function()
            if not owned() or type(Nodes.recallSource) ~= "function" or type(Nodes.recall) ~= "function" then return false end
            local currentSource = Nodes.recallSource(sourceRun, sourceMap)
            if type(currentSource) ~= "table" then return false end
            for key, value in pairs(recallSource) do if currentSource[key] ~= value then return false end end
            return owned()
        end
        confirmFn = function()
            -- Never adopt a fresh token at Click, even after a repaired context.
            if not owned() or type(Nodes.recall) ~= "function" then return false, "stale_action" end
            return commit("recall", recallSource, function() return "Recall · Ruby", { choice = "recall" } end)
        end
        return nil,confirmLabel,confirmOk,confirmFn,nil,recallObserve
    end
    local function shopFooter()
        if shopSelection.selected then return shopSelection:footer() end
        local confirmLabel,confirmOk,confirmFn
        confirmLabel, confirmOk = "离开商店", true
        confirmFn = function()
            -- The farewell stays on screen like a camp/event result, so it is actually seen.
            return commit("leaveShop", nil, function() return "", {} end)
        end
        return nil,confirmLabel,confirmOk,confirmFn,nil,nil
    end
    local function completedFooter(view)
        local confirmLabel,confirmOk,confirmFn
        confirmLabel, confirmOk = view.phase == 'act_transition' and "前往下一幕" or "返回路线", true
        confirmFn = function() if onChange then onChange(true, "complete", self) end return true, "complete" end
        return nil,confirmLabel,confirmOk,confirmFn,nil,nil
    end
    local function resultFooter()
        local confirmLabel,confirmOk,confirmFn
        confirmLabel, confirmOk = "继续", true
        confirmFn = function()
            self.result, self.notice = nil, ""
            self:render() if onChange then onChange(true, "continue", self) end
            return true, "continue"
        end
        return nil,confirmLabel,confirmOk,confirmFn,nil,nil
    end
    local function chooseFooter(result,node,view,screen,recallSource,treasureSource,confirm)
        local backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve
        if view.phase=='ending_proceed' and node and node.type=='ending_proceed' then
            return EndingUI.footer(self,confirm,commit)
        elseif result then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=resultFooter()
        elseif node and node.complete then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=completedFooter(view)
        elseif screen == "shopView" then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=shopFooter()
        elseif screen == "campView" and recallSource then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=recallFooter(recallSource, confirm)
        elseif screen == "treasureView" and treasureSource then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=treasureFooter(treasureSource, confirm)
        elseif screen == "pickerView" then
            backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=pickerFooter(node)
        end
        return backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve
    end
    local function bindFooter(back,confirm,backLabel,confirmLabel,confirmOk,skipRestReward)
        local position = shopSelection.selected and layout.shop.cancel or layout.back
        back:SetAnchoredPosition(position[1],position[2])
        show(back, backLabel ~= nil) show(confirm, confirmLabel ~= nil)
        if backLabel then back:GetChild("label").text = backLabel state(back, true) end
        if confirmLabel then confirm:GetChild("label").text = confirmLabel state(confirm, confirmOk, false, true) end
        action("back", backLabel ~= nil, function()
            if shopSelection:cancel() then return true end
            if options.enhancedRooms and self.picker=='upgrade' and self.selected then
                self.selected=nil;self:render();return true
            end
            if skipRestReward then return skipRestReward() end
            self.mode, self.picker, self.selected, self.notice = "main", nil, nil, "" self:render() return true
        end)
    end
    local function bindTreasureBack(back,node,active)
        if active and node.type=='treasure' and node.chest then
            show(back,true);back:GetChild('label').text=node.roomKind=='boss_treasure' and '跳过遗物' or '离开宝箱';state(back,true)
            action('back',true,function()return commit('leaveTreasure',nil,function()return '已离开宝箱' end)end)
        elseif active and node.roomKind == "boss_treasure" and self.opened then
            show(back, true) back:GetChild("label").text = "跳过遗物" state(back, true)
            action("back", true, function()
                return commit("claimBossTreasure", 0, function() return "已跳过首领遗物" end)
            end)
        end
    end
    local function bindStagedEventActions(node)
        if node and node.type=='event' and stagedEvent(node.event.id) then
            for key, entry in pairs(self.actions) do
                if key=='confirm' or key=='back' or key:match('^eventView/') or key:match('^pickerView/') then
                    bindAct2Action(key,entry)
                end
            end
        end
    end
    local function clearUnusedNativeArt(previous)
        for box in pairs(previous)do if not artFaces[box]then CardDisplay.clearNativeArt(box)end end
    end
    function self:render()
        if not self.run then root:SetVisible(false);return false, "node_unbound" end
        resetButtons();local previousArt=artFaces;artFaces={}
        inspectCards={}
        local view = Nodes.view(self.run, self.map)
        local node = view.node
        syncNodeIdentity(node)
        self.renderRun, self.renderMap, self.nodeId = self.run, self.map, node and node.id
        self.view, self.actions = view, {}
        local result = self:holding() and self.result or nil
        local active = node and kinds[node.type] and not node.complete and view.phase == "node"
        if active then self.removeRows=snapshotDeck(node.purgeCards) end
        syncNodePicker(node,active)
        if not active or node.type ~= 'shop' or self.mode ~= 'main' then shopSelection:clear() end
        renderTopBar(node)
        local screen,hint,recallSource,treasureSource=renderNodePage(view,node,result,active)
        refreshNodeNotice(node,active,hint)
        local back, confirm = child("back"), child("confirm")
        local backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve
        backLabel,confirmLabel,confirmOk,confirmFn,skipRestReward,recallObserve=chooseFooter(result,node,view,screen,recallSource,treasureSource,confirm)
        bindFooter(back,confirm,backLabel,confirmLabel,confirmOk,skipRestReward)
        bindTreasureBack(back,node,active)
        action("confirm", confirmOk, confirmFn, screen == "pickerView" and "请先在上方选择一张卡牌" or nil, nil, recallObserve)
        bindStagedEventActions(node);clearUnusedNativeArt(previousArt)
        self.failed = false
        roomMotion:paint()
    end

    -- Actual canvas pixels; swipe distances are converted back to design units.
    function self:resize(width, height)
        resetButtons()
        shopSelection:clear()
        roomMotion:cancel()
        self.canvasWidth, self.canvasHeight = width, height
        if self.view and self.view.node and (self.view.node.type=='shop' or options.enhancedRooms) then self:render() end
        if self.view and self.view.node and self.view.node.type=='event' and stagedEvent(self.view.node.event.id) then self:render() end
    end
    function self:update(dt)
        roomMotion:update(dt)
        rewardDetail:update(dt)
        shopSelection:update(dt)
        if self.visible then merchant:update(dt) end
        for _, input in pairs(buttonInputs) do
            for _, gesture in pairs(input.active) do
                if gesture.action and gesture.action.observe and not observeAction(gesture.action) then gesture.action = nil end
            end
            local released = input.released
            if released and released.action and released.action.observe and not observeAction(released.action) then released.action = nil end
        end
        local held=self.inspectPress
        if held then
            if not self.visible or held.run~=self.run or held.flow~=self.run.nodeFlow
                or held.card~=inspectCards[held.box] or held.action~=self.actions[held.name] then self.inspectPress=nil
            else
                held.time=held.time+dt
                if held.time>=Theme.layout.statusInfo.delay then
                    self.inspectPress=nil;swipe=nil;swallow={touch=held.touch}
                    if options.onInspectCard then options.onInspectCard(held.card.definition,held.card.upgraded) end
                end
            end
        end
    end
    function self:setVisible(value)
        assert(type(value) == "boolean", "node visibility must be boolean")
        if value and not self.run then return false, "node_unbound" end
        if not value then resetButtons();shopSelection:clear();roomMotion:cancel();for box in pairs(artFaces)do CardDisplay.clearNativeArt(box)end;artFaces={} end
        local wasVisible = self.visible
        self.visible = value root:SetVisible(value)
        if not value and self.view and self.view.node and self.view.node.type=='event' and stagedEvent(self.view.node.event.id) then
            for _, entry in pairs(self.actions) do if entry.observe then entry.observe() end end
        elseif value and not wasVisible and self.view and self.view.node and (options.enhancedRooms or self.view.node.type=='shop'
            or self.view.node.type=='event' and stagedEvent(self.view.node.event.id)) then
            self:render()
        end
    end
    local function current()
        if not self.visible then return false, "panel_hidden" end
        if self.busy or self.presentationBusy then return false, "unavailable_action" end
        local view = Nodes.view(self.run, self.map)
        if self.renderRun ~= self.run or self.renderMap ~= self.map or not view.node or view.node.id ~= self.nodeId then
            return false, "stale_action"
        end
        return true, view
    end
    local function notify(ok, reason)
        if onChange then onChange(ok, reason, self) end
        return ok, reason
    end
    -- describe(before) returns the success notice and, for camp/event, the result screen to hold.
    commit = function(command, argument, describe, choice)
        local node = self.view.node
        local before = { hp = self.run.hp, gold = self.run.gold }
        self.busy = true
        local called, accepted, reason
        if command == "recall" then called, accepted, reason = pcall(Nodes.recall, self.run, self.map, argument)
        elseif command == 'proceedEnding' then called, accepted, reason = pcall(Nodes.proceedEnding,self.run,self.map,argument)
        elseif command == "chooseTreasure" then called, accepted, reason = pcall(Nodes.chooseTreasure, self.run, self.map, argument, choice)
        elseif command == "chooseEvent" then called, accepted, reason = pcall(Nodes.chooseEvent, self.run, argument, choice)
        else called, accepted, reason = pcall(Nodes[command], self.run, argument) end
        self.busy = false
        if not called then error(accepted) end
        if accepted then
            -- Sound confirms a committed action, never a preview or a refresh.
            local cue = command == "upgrade" and "forge"
                or command == "openTreasure" and "treasure_open"
                or command == "upgradeEvent" and "reward"
                or command == "rest" and "rest"
                or (command == "claimTreasure" or command == "claimBossTreasure" or command == "chooseTreasure" or command=="claimTreasureReward") and argument ~= 0 and "reward"
                or (command == "removeCard" or command == "purifyEvent" or command == "purgeWing") and "card_remove"
            if cue and options.sound and not (options.enhancedRooms and
                (command=='openTreasure' or command=='rest' or command=='upgrade')) then pcall(options.sound, cue) end
            local notice, hold = describe(before)
            if command == "buyCardSlot" or command == "buyRelic" or command == "buyPotion" or command == "removeCard" then
                merchant:react("buy")
            elseif command == "leaveShop" then merchant:react("leave") end
            self.notice, self.failed = notice, false
            if command == "removeCard" then self.mode, self.picker, self.selected = "main", nil, nil end
            local flow = self.run.nodeFlow
            if hold and flow and flow.complete and (node.type == "camp" or node.type == "event" or node.type == "shop") then
                hold.run, hold.map, hold.nodeId = self.run, self.map, flow.id
                -- A shop farewell shows no shelf: only the merchant and 继续 remain.
                hold.view = node.type == "event" and "eventView" or node.type == "shop" and "farewell"
                    or (hold.choice == "upgrade" and "pickerView" or "campView")
                hold.eventId = node.event and node.event.id
                self.result = hold
            end
        else
            self.notice, self.failed = reasons[reason] or "操作未完成，请重新选择", true
        end
        self:render()
        if accepted then roomMotion:start(command,before) end
        self.failed = false
        return notify(accepted, reason)
    end

    -- Every clickable control is addressed by its path, e.g. "shopView/card1".
    function self:press(key)
        local ok, view = current()
        if not ok then
            local entry = self.actions[key]
            if entry and entry.retire then entry.retire() end
            return false, view
        end
        local entry = self.actions[key]
        if not entry then return false, "unavailable_action" end
        if not entry.enabled then
            if entry.poor then merchant:react("poor") end
            if entry.reason then self.notice, self.failed = entry.reason, true self:render() end
            return false, "unavailable_action"
        end
        return entry.handler()
    end
    function self:setPage(page)
        local ok, reason = current() if not ok then return false, reason end
        if type(page) ~= "number" or page % 1 ~= 0 or page < 1 or page > (self.pageCount or 1) then return false, "invalid_page" end
        if self.mode == "picker" then self.pickPage = page else self.page = page end
        self.notice = "" self:render() return true
    end

    local targets = { "back", "confirm", "shopView/previous", "shopView/next", "shopView/removal",
        "shopView/relicPrevious", "shopView/relicNext", "campView/rest", "campView/forge",
        "pickerView/previous", "pickerView/next", "treasureView/chest", "treasureView/take",
        "treasureView/previous", "treasureView/next" }
    for i=1,4 do targets[#targets+1]='treasureView/rewardItem'..i end
    for i=1,12 do targets[#targets+1]='pickerView/forgeGrid/card'..i end
    targets[#targets+1]='pickerView/forgePrevious';targets[#targets+1]='pickerView/forgeNext'
    for i = 1, SHOP_PAGE do targets[#targets + 1] = "shopView/card" .. i end
    for i = 1, RELIC_PAGE do targets[#targets + 1] = "shopView/relic" .. i end
    for i = 1, 3 do targets[#targets+1]='shopView/potion'..i end
    for i = 1, PICK_PAGE do targets[#targets + 1] = "pickerView/card" .. i end
    targets[#targets+1]='pickerView/before';targets[#targets+1]='pickerView/after'
    for i = 1, OPTIONS do targets[#targets + 1] = "eventView/option" .. i end
    local cursor = options.cursorEvents or (Enum and Enum.CursorEventType)
    -- Native hits accept one listener per event; framed feedback and row swipes share it.
    local dispatch = {}
    local function listen(hit, event, fn)
        local byEvent = dispatch[hit] or {}
        dispatch[hit] = byEvent
        local list = byEvent[event]
        if not list then
            list = {}
            byEvent[event] = list
            hit:AddCursorEventListener(event, function(e) for _, f in ipairs(list) do f(e) end end)
        end
        list[#list + 1] = fn
    end
    -- A row swipe presses that row's existing arrow, so paging rules stay in one place.
    local rows = {}
    for i = 1, SHOP_PAGE do rows["shopView/card" .. i] = "shopView/" end
    for i = 1, RELIC_PAGE do rows["shopView/relic" .. i] = "shopView/relic" end
    for i = 1, PICK_PAGE do rows["pickerView/card" .. i] = "pickerView/" end
    self.swipeEnabled = cursor ~= nil and cursor.CursorDown ~= nil and cursor.CursorUp ~= nil
    local function point(event)
        if not event or type(event.GetUIPos) ~= "function" then return end
        local x, y = event:GetUIPos()
        if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y
            or math.abs(x) == math.huge or math.abs(y) == math.huge then return end
        local width, height = self.canvasWidth or Theme.canvas.base[1], self.canvasHeight or Theme.canvas.base[2]
        local k = math.min(width / Theme.canvas.base[1], height / Theme.canvas.base[2])
        return x / k, y / k
    end
    local function swipeDown(row, event)
        swallow = nil -- a new physical sequence
        local x, y = point(event)
        swipe = x and { row = row, touch = event.touchId, x = x, y = y } or nil
    end
    local function swipeUp(event)
        local g = swipe
        if not g or (event and event.touchId) ~= g.touch then return end
        swipe = nil
        local x, y = point(event)
        if not x then return end
        local dx, dy = x - g.x, y - g.y
        local limit = layout.swipe.threshold
        if math.abs(dx) < limit and math.abs(dy) < limit then return end
        -- Past the threshold it is a drag, never a purchase; only a horizontal one pages.
        -- Finger moves left to reveal the next page, as on a touch carousel.
        if math.abs(dx) > math.abs(dy) then
            local arrow = (g.row == "shopView/relic") and (dx < 0 and "Next" or "Previous") or (dx < 0 and "next" or "previous")
            self:press(g.row .. arrow)
        end
        swallow = { touch = g.touch }
    end

    for _, key in ipairs(targets) do
        local name = key
        local box = path(name)
        local hit = box:GetChild("hit")
        actionInputs[name] = {box=box,hit=hit}
        local input
        Controller.bind(options.controller,hit,'node',function()return self:press(name)end,function()
            local entry=self.actions[name]
            return self.visible and not self.busy and entry and entry.enabled
        end,name=='confirm' and 90 or name=='back' and 100 or 10)
        hit:AddCursorEventListener(clickEvent, function(event)
            if rewardDetail:consume(name,event)then return false,'inspected' end
            if Controller.pointerBlocked(options.controller)then return false end
            if swallow and (event == nil or event.touchId == nil or event.touchId == swallow.touch) then
                swallow = nil
                return false, "swiped"
            end
            if input and input.observed then
                local gesture = input.released
                local touch = event and event.touchId
                -- Click follows Up. Keep its original action until consumption, not
                -- the action currently rebound to this hit area after a render.
                if not gesture or touch ~= nil and touch ~= gesture.touch
                    or touch == nil and next(input.active) ~= nil then return false, "stale_action" end
                input.released = nil
                if not gesture.action or gesture.action ~= self.actions[name] then return false, "stale_action" end
            end
            -- Hosts that never send Down retain the click-only/accessibility path.
            return self:press(name)
        end)
        -- A framed button keeps its dynamic children at their existing paths.
        -- Documented pointer events + SetLocalScale scale the complete face;
        -- Shop/picker cards share gesture ownership without framed-button visuals.
        if (box:GetChild("normal") or name:match("^shopView/card%d+$") or name:match('^pickerView/forgeGrid/card%d+$')
            or name:match("^pickerView/card%d+$")) and cursor and cursor.CursorEnter and cursor.CursorExit
            and cursor.CursorDown and cursor.CursorUp and cursor.CursorEndDrag then
            -- Retain only active touches and the next released click, never a
            -- history of touch IDs. Render/hide and terminal events clear them.
            input = {active={}}
            buttonInputs[box] = input
            local noTouch = {} -- supports a complete pointer sequence without IDs
            local function touchKey(event) return event and event.touchId or noTouch end
            local function cancelInput(event)
                input.active[touchKey(event)] = nil
                if input.released and input.released.touch == (event and event.touchId) then input.released = nil end
            end
            local function visibleAction()
                local entry = self.actions[name]
                local ok, view = current()
                if not ok or self.view.phase ~= view.phase or self.view.node.complete ~= view.node.complete then
                    retireAction(entry) return nil
                end
                local parent = box
                while parent do
                    if not parent.visible then retireAction(entry) return nil end
                    parent = parent.parent
                end
                if entry and not observeAction(entry) then return nil end
                return entry
            end
            local function available()
                local entry, look = visibleAction(), buttonLooks[box]
                -- Guarded mandatory-picker cards have no framed-button look.
                -- Keep the legacy feedback path for all other controls unchanged.
                local plainPicker = not look and entry and entry.retire and name:match("^pickerView/card%d+$") ~= nil
                local shopCard = not look and (name:match('^shopView/card%d+$') or name:match('^pickerView/forgeGrid/card%d+$')) ~= nil
                return entry and entry.enabled and (plainPicker or shopCard or look and look.enabled and not look.selected)
            end
            local function owned(event)
                return buttonPress and buttonPress.box == box and buttonPress.touch == (event and event.touchId)
            end
            local function release(event)
                if not owned(event) then return end
                buttonPress = nil
                if not available() then buttonHover = nil end
                paintButton(box)
            end
            listen(hit, cursor.CursorEnter, function()
                if not available() or buttonPress and buttonPress.box ~= box then return end
                local previous = buttonHover
                buttonHover = box
                if previous and previous ~= box then paintButton(previous) end
                paintButton(box)
            end)
            listen(hit, cursor.CursorDown, function(event)
                input.observed, input.released = true, nil
                local gesture = {touch=event and event.touchId, action=visibleAction()}
                input.active[touchKey(event)] = gesture
                if not available() or buttonPress then
                    if gesture.action and gesture.action.observe then gesture.action = nil end
                    return
                end
                buttonPress = {box=box,touch=event and event.touchId}
                paintButton(box)
            end)
            listen(hit, cursor.CursorExit, function(event)
                cancelInput(event)
                if buttonPress and not owned(event) then return end
                if buttonHover == box then buttonHover = nil end
                if owned(event) then buttonPress = nil end
                paintButton(box)
            end)
            listen(hit, cursor.CursorUp, function(event)
                local touchId = touchKey(event)
                local gesture = input.active[touchId]
                input.active[touchId] = nil
                if gesture and gesture.action and gesture.action.observe and not observeAction(gesture.action) then gesture.action = nil end
                if gesture then input.released = gesture end
                release(event)
            end)
            listen(hit, cursor.CursorEndDrag, function(event)
                cancelInput(event)
                if not owned(event) then return end
                buttonPress, buttonHover = nil, nil
                paintButton(box)
            end)
        end
        if self.swipeEnabled and rows[name] then
            local row = rows[name]
            listen(hit, cursor.CursorDown, function(event) swipeDown(row, event) end)
            listen(hit, cursor.CursorUp, swipeUp)
            if cursor.CursorEndDrag then listen(hit, cursor.CursorEndDrag, swipeUp) end
        end
        if name:match('^shopView/card%d+$') or name:match('^shopView/relic%d+$') or name:match('^shopView/potion%d+$') then
            if cursor and cursor.CursorEnter then listen(hit,cursor.CursorEnter,function()shopSelection:enter(name)end) end
            if cursor and cursor.CursorExit then listen(hit,cursor.CursorExit,function()shopSelection:exit(name)end) end
        end
        if name:match('^pickerView/forgeGrid/card%d+$') and cursor then
            if cursor.CursorEnter then listen(hit,cursor.CursorEnter,function()campUI:hover(box,true)end)end
            if cursor.CursorExit then listen(hit,cursor.CursorExit,function()campUI:hover(box,false)end)end
        end
        if name:match('^treasureView/rewardItem%d+$') and cursor then
            if cursor.CursorEnter then listen(hit,cursor.CursorEnter,function()rewardDetail:enter(name)end)end
            if cursor.CursorExit then listen(hit,cursor.CursorExit,function()rewardDetail:exit(name)end)end
            if cursor.CursorDown then listen(hit,cursor.CursorDown,function(event)rewardDetail:down(name,event)end)end
            if cursor.CursorUp then listen(hit,cursor.CursorUp,function(event)rewardDetail:up(event)end)end
            if cursor.CursorEndDrag then listen(hit,cursor.CursorEndDrag,function()rewardDetail:exit(name)end)end
        end
        if options.onInspectCard and cursor and cursor.CursorDown and cursor.CursorUp
            and (name:match('^shopView/card%d+$') or name:match('^pickerView/card%d+$')
                or name=='pickerView/before' or name=='pickerView/after') then
            listen(hit,cursor.CursorDown,function(event)
                self.inspectPress=nil
                if not self.visible or not inspectCards[box] or not box.visible then return end
                local parent=box
                while parent do if not parent.visible then return end;parent=parent.parent end
                local x,y=point(event)
                self.inspectPress={box=box,name=name,card=inspectCards[box],run=self.run,flow=self.run.nodeFlow,
                    action=self.actions[name],touch=event and event.touchId,time=0,x=x,y=y}
            end)
            local function cancelInspect(event)
                if self.inspectPress and self.inspectPress.touch==(event and event.touchId) then self.inspectPress=nil end
            end
            listen(hit,cursor.CursorUp,cancelInspect)
            if cursor.CursorExit then listen(hit,cursor.CursorExit,cancelInspect) end
            if cursor.CursorEndDrag then listen(hit,cursor.CursorEndDrag,cancelInspect) end
            if cursor.CursorDrag then listen(hit,cursor.CursorDrag,function(event)
                local held=self.inspectPress;local x,y=point(event)
                if held and (not x or not held.x or (x-held.x)^2+(y-held.y)^2>=Theme.layout.cardDrag.threshold^2) then
                    self.inspectPress=nil
                end
            end) end
        end
    end
    self:render()
    return self
end
return M
