# Reproduction

Use the existing native liblua5.4 runner, assigned to LUA54_RUNNER. No dependency installation or full npm command is needed.

In snapshot or candidate, the builds used were:

    node scripts/build-lua-data.mjs
    node scripts/build-ui.mjs

The targeted suite on unchanged snapshot was run using the same new test file from candidate:

    LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;' python "$LUA54_RUNNER" ../candidate/tests/lua/potion_target_input_ownership.lua

On candidate:

    LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;' python "$LUA54_RUNNER" tests/lua/potion_target_input_ownership.lua
    LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;' python "$LUA54_RUNNER" ../probe.lua
    LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;' python "$LUA54_RUNNER" ../mutation-no-enemy-observed.lua
    LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;' python "$LUA54_RUNNER" ../mutation-no-action-cancel.lua

The two mutation commands must exit 1 with exactly the two corresponding failures. They load separate mutated source copies with package.preload and never alter candidate source.

Existing suites were run individually with the same LUA_PATH and runner. battle_ui uses battle-ui-wrapper.lua, generated from the current battleLayout via the repository's own toLua serializer. The Node command was:

    node --test tests/ui-layout.test.mjs tests/potion-help-layout.test.mjs tests/potion-discard-layout.test.mjs

No assertion reduction or runner-timeout change was made.
