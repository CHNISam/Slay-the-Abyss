import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';

test('dynamic monster controls retain actor ownership and precisely retire stale input', () => {
  const result=runLua('tests/lua/dynamic_monster_input_bindings.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/DYNAMIC_MONSTER_INPUT_BINDINGS_PASS/);
  assert.match(result.stdout,/REENTRANT_RETIRE_SITES=15/);
  assert.match(result.stdout,/PARTIAL_BIND_FAILURE_SITES=15/);
});

test('retired controller callback regression rejects a replaced record without its generation fence', async () => {
  const {readFileSync,mkdtempSync,writeFileSync,rmSync}=await import('node:fs');
  const {join}=await import('node:path');
  const {tmpdir}=await import('node:os');
  const {luaString}=await import('../scripts/build-lua-data.mjs');
  const source=readFileSync('src/lua/abyss_controller.lua','utf8').replaceAll('\r\n','\n');
  const fence='if expected and expected~=record then return false end';
  assert.equal(source.split(fence).length,2);
  const directory=mkdtempSync(join(tmpdir(),'abyss-dynamic-input-mutation-'));
  try {
    const script=join(directory,'controller.lua');
    writeFileSync(script,`package.preload.abyss_controller=function()return assert(load(${luaString(source.replace(fence,'-- mutation: lose retired callback generation'))},'@controller-mutation'))()end\ndofile('tests/lua/dynamic_monster_input_bindings.lua')\n`);
    const result=runLua(script);
    assert.notEqual(result.status,0);
    assert.match(result.stderr,/old controller closure used replacement record/);
  } finally {rmSync(directory,{recursive:true,force:true});}
});

test('partial-bind injection rejects late ownership of the intent controller record', async () => {
  const {readFileSync,mkdtempSync,writeFileSync,rmSync}=await import('node:fs');
  const {join}=await import('node:path');
  const {tmpdir}=await import('node:os');
  const {luaString}=await import('../scripts/build-lua-data.mjs');
  const source=readFileSync('src/lua/abyss_battle_detail_bindings.lua','utf8').replaceAll('\r\n','\n');
  const registration='if cleanups then cleanups[#cleanups+1]={control=control,cancel=cancel} end';
  const bindEnd='end,80)';
  assert.equal(source.split(registration).length,2);
  assert.equal(source.split(bindEnd).length,2);
  assert.ok(source.indexOf(registration)<source.indexOf(bindEnd));
  const mutation=source.replace(registration,'-- mutation: register cleanup too late').replace(bindEnd,bindEnd+'\n        '+registration);
  const directory=mkdtempSync(join(tmpdir(),'abyss-partial-bind-mutation-'));
  try {
    const script=join(directory,'detail.lua');
    writeFileSync(script,`package.preload.abyss_battle_detail_bindings=function()return assert(load(${luaString(mutation)},'@detail-mutation'))()end\ndofile('tests/lua/dynamic_monster_input_bindings.lua')\n`);
    const result=runLua(script);
    assert.notEqual(result.status,0);
    assert.match(result.stderr,/partial bind leaked controller records at registration 10/);
  } finally {rmSync(directory,{recursive:true,force:true});}
});

test('reentrant retirement regression rejects continuation after intent cursor registration', async () => {
  const {readFileSync,mkdtempSync,writeFileSync,rmSync}=await import('node:fs');
  const {join}=await import('node:path');
  const {tmpdir}=await import('node:os');
  const {luaString}=await import('../scripts/build-lua-data.mjs');
  const source=readFileSync('src/lua/abyss_battle_detail_bindings.lua','utf8').replaceAll('\r\n','\n');
  const fence='if not current() then return end\n            control:AddCursorEventListener(host.cursor.CursorExit,cancel)';
  assert.equal(source.split(fence).length,2);
  const mutation=source.replace(fence,'control:AddCursorEventListener(host.cursor.CursorExit,cancel)');
  const directory=mkdtempSync(join(tmpdir(),'abyss-reentrant-bind-mutation-'));
  try {
    const script=join(directory,'detail.lua');
    writeFileSync(script,`package.preload.abyss_battle_detail_bindings=function()return assert(load(${luaString(mutation)},'@detail-mutation'))()end\ndofile('tests/lua/dynamic_monster_input_bindings.lua')\n`);
    const result=runLua(script);
    assert.notEqual(result.status,0);
    assert.match(result.stderr,/registration continued after retirement at 8/);
  } finally {rmSync(directory,{recursive:true,force:true});}
});
