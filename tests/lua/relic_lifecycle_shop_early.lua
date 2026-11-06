local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
F.runFixture('shop',nil,1,7)
F.finish('shop_early')
