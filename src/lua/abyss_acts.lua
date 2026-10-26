-- STS1 PC A0 chapter coordinates. Behavior ledger: docs/rules/CROSS_ACT.md.
-- Global floors describe the run; local rows describe one chapter's map only.
local Seed = require('abyss_run_seed')
local M = {}
local definitions = {
    {id='Exordium',name='第一幕',first=1,last=17,rows=15,boss=16,treasure=9,camp=15,terminal='boss_treasure',seedOffset=1,upgradeChance=0},
    {id='TheCity',name='第二幕',first=18,last=34,rows=15,boss=33,treasure=26,camp=32,terminal='boss_treasure',seedOffset=200,upgradeChance=.25},
    {id='TheBeyond',name='第三幕',first=35,last=51,rows=15,boss=50,treasure=43,camp=49,terminal='ending',seedOffset=600,upgradeChance=.5},
    {id='TheEnding',name='隐藏第四幕',first=52,last=55,rows=0,boss=55,camp=52,terminal='true_victory',seedOffset=1200,upgradeChance=.5},
}
function M.get(act)
    assert(type(act)=='number' and act%1==0 and definitions[act],'invalid act')
    local result={act=act}
    for k,v in pairs(definitions[act]) do result[k]=v end
    return result
end
function M.forFloor(floor)
    assert(type(floor)=='number' and floor%1==0 and floor>=1 and floor<=55,'invalid global floor')
    for act,d in ipairs(definitions) do if floor<=d.last then return act,floor-d.first+1 end end
end
function M.globalFloor(act,row)
    local d=M.get(act)
    assert(type(row)=='number' and row%1==0 and row>=1 and row<=d.last-d.first+1,'invalid local floor')
    return d.first+row-1
end
function M.mapSeed(seed,act) return Seed.add(seed,M.get(act).seedOffset) end
return M
