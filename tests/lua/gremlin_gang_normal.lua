local H=dofile('tests/lua/support/gremlin_gang_fixture.lua')
H.frontierCases('normal')
H.failureCases('normal')
H.finish(5,'GREMLIN_GANG_NORMAL_PASS')
