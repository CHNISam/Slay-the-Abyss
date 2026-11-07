-- Source phase membership only; no actor, action or queue execution dependencies.
-- scheduledIds is the initialization-time union, not a live view of phase edits.
local M={}
M.phases={
    turn_start={nightmare=true,phantasmal=true,hello_world=true,creative_ai=true,magnetism=true,mayhem=true,berserk=true,infinite_blades=true,bias=true,loop=true,flame_barrier=true,
        next_turn_block=true,battle_hymn=true,energy_down=true,wrath_next_turn=true,end_turn_death=true,foresight=true},
    energy_recharge={energized=true,energized_blue=true,collect=true,deva_form=true},
    turn_start_post_draw={tools_of_the_trade=true,demon_form=true,noxious_fumes=true,devotion=true,brutality=true,
        draw_next_turn=true,draw_card_next_turn=true},
}
M.scheduledIds={}
for _,filter in pairs(M.phases)do for id in pairs(filter)do M.scheduledIds[id]=true end end
return M
