
local Copy=require('abyss_combat').copy
local M = {}
local function sameValue(actual,expected,seen)
    if type(actual)~=type(expected)then return false end
    if type(actual)~='table'then return actual==expected end
    seen=seen or {}
    if seen[expected]then return seen[expected]==actual end
    seen[expected]=actual
    for key,value in pairs(expected)do if not sameValue(actual[key],value,seen)then return false end end
    for key in pairs(actual)do if expected[key]==nil then return false end end
    return true
end
local function deckOwner(run)
    local deck,owners=run.deck,{}
    for i,card in ipairs(deck)do owners[i]=card end
    local snapshot=Copy(deck)
    return function()
        if run.deck~=deck or #deck~=#owners then return false end
        for i,card in ipairs(owners)do if deck[i]~=card then return false end end
        return sameValue(deck,snapshot)
    end
end

-- Installs the event ownership responsibility on one node UI instance.
function M.install(ctx)
    function ctx.bindAct2Action(key, entry)
        local sourceRun, sourceMap, sourceFlow, sourceView = ctx.self.run, ctx.self.map, ctx.self.run.nodeFlow, ctx.self.view
        local sourceEvent = sourceFlow.event
        local gridGuard=ctx.eventCardsGuard and ctx.eventCardsGuard(sourceRun,sourceEvent.id)
        local generation, act, floor, phase = sourceRun.roomGeneration, sourceRun.act, sourceRun.floor, sourceRun.phase
        local stage, choice, complete = sourceEvent.stage, sourceEvent.choice, sourceFlow.complete
        local flowId, flowFloor, eventId = sourceFlow.id, sourceFlow.floor, sourceEvent.id
        local sameDeck=eventId=='duplicator' and deckOwner(sourceRun) or function()return true end
        local selected, mode, picker, page = ctx.self.selected, ctx.self.mode, ctx.self.picker, ctx.self.pickPage
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
        local box, owners = ctx.root, {}
        for part in key:gmatch("[^/]+") do
            local owner = box
            box = owner:GetChild(part)
            owners[#owners + 1] = { owner = owner, child = box, name = part }
        end
        local native = ctx.actionInputs[key]
        local hit = native.hit
        owners[#owners + 1] = { owner = box, child = hit, name = "hit" }
        local function owned()
            if retired then return false end
            local attached = box == native.box
            for _, link in ipairs(owners) do
                if link.owner:GetChild(link.name) ~= link.child then attached = false end
            end
            local hostAttached = not ctx.rootParent or ctx.rootParent:GetChild("nodePanel") == ctx.root
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
            local function sameAction() return ctx.self.view == sourceView and ctx.self.actions[key] == entry and entry.handler == handler and entry.enabled
                    and ctx.self.run.nodeFlow == sourceFlow and sourceFlow.event == sourceEvent end
            local function sameRoom() return sourceRun.roomGeneration == generation and sourceRun.act == act and sourceRun.floor == floor
                    and sourceRun.phase == phase and sourceFlow.complete == complete
                    and sourceFlow.id == flowId and sourceFlow.floor == flowFloor and sourceFlow.type == "event" end
            local function sameSelection() return sourceEvent.id == eventId and sourceEvent.stage == stage and sourceEvent.choice == choice
                    and ctx.self.selected == selected and ctx.self.mode == mode and ctx.self.picker == picker and ctx.self.pickPage == page
                    and sameOffers() and (not gridGuard or gridGuard()) and sameDeck() end
            local function sameHost() return attached and hostAttached and ctx.root.parent == ctx.rootParent and ctx.self.root == ctx.root
                    and ctx.self.visible and not ctx.self.busy and ctx.self.run == sourceRun and ctx.self.map == sourceMap end
            return sameHost()
                and sameAction()
                and sameRoom()
                and sameSelection()
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
end
return M
