local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
F.runFixture('parasite',nil,2,2)
F.finish('parasite_02')
