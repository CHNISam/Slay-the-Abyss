local integer=require("abyss_numbers").integer
for _,row in ipairs({{68.0,"68"},{80.0,"80"},{0.0,"0"},{-2.0,"-2"},{2147483647.0,"2147483647"}}) do
    assert(integer(row[1])==row[2])
end
for _,value in ipairs({68.5,0/0,math.huge,-math.huge,"68"}) do
    local ok,reason=pcall(integer,value)
    assert(not ok and tostring(reason):find("finite integer",1,true))
end
print("LUA_NUMBER_DISPLAY_PASS 10")
