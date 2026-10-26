local Copy = require('abyss_copy')
local Combat = require('abyss_combat')
local shared = { value = 7 }
local original = { first = shared, second = shared, scalar = false }
original.self = original
original[shared] = 'table key'
local cloned = Copy.copy(original)
assert(cloned ~= original and cloned.first ~= shared)
assert(cloned.first == cloned.second and cloned.self == cloned)
assert(cloned[shared] == 'table key' and cloned.scalar == false)
cloned.first.value = 9
assert(original.first.value == 7)
assert(Combat.copy == Copy.copy, 'legacy public copy API remains identical')
local memo = {}
assert(Copy.copy(original, memo) == memo[original])
assert(Copy.copy(assert(shared, 'legacy assert message')).value == 7)
assert(Copy.copy(42) == 42 and Copy.copy(nil) == nil)
print('COPY_GRAPH_PASS identity/cycles/keys/isolation/memo/legacy API')
