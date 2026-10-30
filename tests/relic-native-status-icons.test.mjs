import test from 'node:test';
import assert from 'node:assert/strict';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {buildUiTheme} from '../scripts/build-ui-theme.mjs';
import {runLua} from '../scripts/test-lua.mjs';

test('real acquired Helix and Clay render native numeric status icons through full Battle UI without state changes',()=>{
 buildLuaData();buildUiTheme();buildUI();
 const result=runLua('tests/lua/relic_native_status_icons.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/RELIC_NATIVE_STATUS_ICONS_PASS/);
 assert.match(result.stdout,/RELIC_NATIVE_STATUS_FEEDBACK_PASS/);
});
