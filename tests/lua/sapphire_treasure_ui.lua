-- Original groups 1-8; independent process and unchanged per-file deadline.
dofile('tests/lua/support/sapphire_exhausted_pool_fixture.lua')(function()
dofile("tests/lua/support/sapphire_treasure_ui_cases.lua")(1,8)
end)
