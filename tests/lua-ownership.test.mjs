import test from 'node:test';
import assert from 'node:assert/strict';
import { auditOwnership, read } from './helpers/lua-ownership.mjs';
import childProcess from 'node:child_process';
import { syncBuiltinESMExports } from 'node:module';
import { runLua } from '../scripts/test-lua.mjs';

test('every original Lua entry and affected assertion survives the raw/JS ownership partition',()=>{
  const manifest=JSON.parse(read('tests/fixtures/lua-ownership.json'));
  auditOwnership(manifest);
});

test('relocation preserves every runner environment, deadline and injected battle layout',()=>{
  const manifest=JSON.parse(read('tests/fixtures/lua-ownership.json'));
  const original=childProcess.spawnSync;
  const calls=[];
  childProcess.spawnSync=(command,args,options)=>{
    const injected=args[2].includes('abyss-ui-test-');
    const temporary=args[2].slice('dofile('.length+1,-2).replace(/\\(\d{3})/g,(_,n)=>String.fromCharCode(Number(n)));
    const layout=injected?read(temporary).split('\n')[0]:null;
    calls.push({command,cli:args[0],mode:args[1],options,layout});
    return {status:0,stdout:'',stderr:''};
  };
  syncBuiltinESMExports();
  try {
    for (const move of manifest.moved) {
      calls.length=0;
      runLua(move.from);
      runLua(move.to);
      assert.equal(calls.length,2);
      assert.deepEqual(calls[1],calls[0],`same runner configuration and layout: ${move.from}`);
    }
  } finally {
    childProcess.spawnSync=original;
    syncBuiltinESMExports();
  }
});

test('ownership inventory rejects a missing original, an extra transfer and a lost assertion',()=>{
  const original=JSON.parse(read('tests/fixtures/lua-ownership.json'));
  const missing=structuredClone(original);
  missing.originals[0].path='tests/lua/missing-original.lua';
  assert.throws(()=>auditOwnership(missing),/original fixture still exists/);
  const duplicate=structuredClone(original);
  duplicate.moved.push(duplicate.moved[0]);
  assert.throws(()=>auditOwnership(duplicate),/unique ownership transfers/);
  const assertion=structuredClone(original);
  assertion.wrappers[0].sha256LF='0'.repeat(64);
  assert.throws(()=>auditOwnership(assertion),/all original JS assertions/);
});
