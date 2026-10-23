-- Independent source-contract probe; pending shared Combat scheduling fix.
-- Run explicitly; deliberately red until that fix is integrated.
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat=require("abyss_combat")
local Data=require("abyss_data")
local failures=0
for _,teammate in ipairs({false,true}) do
    local old=Combat.random;local rolls=0
    Combat.random=function(state,n) if n==100 then rolls=rolls+1 end;return 1 end
    local ok,err=pcall(function()
        local s=Combat.new(Data,{enemies=teammate and {"blue_slaver","cultist"} or {"blue_slaver"},deck={"defend"},seed=42})
        s.enemies[1].hp=1;s.enemies[1].intentIndex=1 -- isolated lethal-retaliation fixture, Stab
        Combat.addStatus(s.player,"thorns",1)
        local before=rolls;assert(Combat.endTurn(s));assert(s.enemies[1].hp==0)
        local actual,expected=rolls-before,teammate and 1 or 0
        assert(actual==expected,"source queued roll: teammate="..tostring(teammate).." expected="..expected.." actual="..actual)
    end)
    Combat.random=old
    if not ok then failures=failures+1 end
    print((ok and "ok " or "not ok ").."queued roll after lethal retaliation, teammate="..tostring(teammate)..(ok and "" or ": "..tostring(err)))
end
assert(failures==0,tostring(failures).." source-contract paths still differ")
