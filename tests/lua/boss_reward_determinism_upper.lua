local fixture = dofile('tests/helpers/boss_rewards.lua')
fixture.deterministicSeeds(113, 128)
print('ok boss reward deterministic draws - seeds 113 through 128')
print('LUA_BOSS_REWARD_DETERMINISM_UPPER_PASS')
