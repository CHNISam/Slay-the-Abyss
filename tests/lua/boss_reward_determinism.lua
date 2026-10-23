local fixture = dofile('tests/helpers/boss_rewards.lua')
fixture.deterministicSeeds(1, 64)
print('ok boss reward deterministic draws - seeds 1 through 64')
print('LUA_BOSS_REWARD_DETERMINISM_PASS')
