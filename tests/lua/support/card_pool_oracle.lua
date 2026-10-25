-- Independent expected outcomes, rather than calculating answers from effects.
-- Each pair is base/upgraded. All actors have no modifiers except Dropkick's
-- declared vulnerable fixture; damage numbers below are actual HP lost.
local cases = {
    {id="strike", cost={1,1}, damage={6,9}},
    {id="defend", cost={1,1}, block={5,8}},
    {id="bash", cost={2,2}, damage={8,10}, enemyStatus="vulnerable", stacks={2,3}},
    {id="cleave", cost={1,1}, damage={8,11}, area=true},
    {id="clothesline", cost={2,2}, damage={12,14}, enemyStatus="weak", stacks={2,3}},
    {id="iron_wave", cost={1,1}, damage={5,7}, block={5,7}},
    {id="anger", cost={0,0}, damage={6,8}, copies=true},
    {id="body_slam", cost={1,0}, damage={12,12}},
    {id="flex", cost={0,0}, ownStatus="strength", stacks={2,4}, temporary=true},
    {id="twin_strike", cost={1,1}, damage={10,14}},
    {id="pommel_strike", cost={1,1}, damage={9,10}, draw={1,2}},
    {id="shrug_it_off", cost={1,1}, block={8,11}, draw={1,1}},
    {id="thunderclap", cost={1,1}, damage={4,7}, area=true, enemyStatus="vulnerable", stacks={1,1}},
    {id="uppercut", cost={2,2}, damage={13,13}, enemyStatus="weak", secondStatus="vulnerable", stacks={1,2}},
    {id="inflame", cost={1,1}, ownStatus="strength", stacks={2,3}, power=true},
    {id="battle_trance", cost={0,0}, draw={3,4}, noDraw=true},
    {id="bloodletting", cost={0,0}, hpLoss=3, energy={2,3}},
    {id="barricade", cost={3,2}, ownStatus="barricade", stacks={1,1}, power=true},
    {id="carnage", cost={2,2}, damage={20,28}},
    {id="disarm", cost={1,1}, enemyStatus="strength", stacks={-2,-3}, exhaust=true},
    {id="dropkick", cost={1,1}, damage={7,12}, draw={1,1}, energy={1,1}, vulnerable=true},
    {id="entrench", cost={2,1}, block={12,12}},
    {id="ghostly_armor", cost={1,1}, block={10,13}},
    {id="hemokinesis", cost={1,1}, damage={15,20}, hpLoss=2},
    {id="rampage", cost={1,1}, damage={8,8}, growth={5,8}},
    {id="seeing_red", cost={1,0}, energy={2,2}, exhaust=true},
    {id="shockwave", cost={2,2}, area=true, enemyStatus="weak", secondStatus="vulnerable", stacks={3,5}, exhaust=true},
    {id="offering", cost={0,0}, hpLoss=6, energy={2,2}, draw={3,5}, exhaust=true},
    {id="impervious", cost={2,2}, block={30,40}, exhaust=true},
    {id="bludgeon", cost={3,3}, damage={32,42}},
}
local blocked = {"clash", "true_grit", "warcry", "metallicize", "whirlwind", "demon_form", "reaper"}
return {cases=cases, blocked=blocked}
