local F=dofile('tests/helpers/relic-lifecycle-baseline-support.lua')
F.runFixture('shop',nil,8,99)
F.finish('shop_late')
