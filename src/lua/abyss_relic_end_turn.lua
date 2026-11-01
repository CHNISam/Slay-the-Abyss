-- One source onPlayerEndTurn construction pass, in held-relic order. The
-- existing Combat actionQueue owns execution, optional choice pause and resume.
local M={}
local aliases={Orichalcum='orichalcum',["Nilry's Codex"]='nilrys_codex',StoneCalendar='stone_calendar'}
-- Legacy Orichalcum/Calendar-only runs keep their existing PR357 path.
-- Their held positions join this pass only when Codex can pause the queue.
local relevant={nilrys_codex=true}
function M.needed(state)
    if state.relicEndTurnResolved==state.turn then return false end
    for _,held in ipairs(state.relics or {})do if relevant[aliases[held]or held]then return true end end
    return false
end
function M.prepare(state)
    local actions={}
    for _,held in ipairs(state.relics or {})do
        local id=aliases[held]or held
        if id=='orichalcum'and state.player.block==0 then
            actions[#actions+1]={kind='effect',effect={op='block',value=6,fixed=true,gainBlockAction=true}}
        elseif id=='nilrys_codex'then
            actions[#actions+1]={kind='effect',effect={op='act2RelicCodex'}}
        elseif id=='stone_calendar'then
            if state.relicCounters.stone_calendar==7 then
                actions[#actions+1]={kind='effect',effect={op='rareRelicDamageAll',value=52,relic='stone_calendar'}}
            end
        end
    end
    state.relicEndTurnResolved=state.turn
    return actions
end
return M
