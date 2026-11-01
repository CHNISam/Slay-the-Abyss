import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync, rmSync, rmdirSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import {historicalPresentationFixtures,runHistoricalPresentation} from './helpers/historical-presentation-runner.mjs';

const cli = fileURLToPath(new URL('../scripts/test-lua.mjs', import.meta.url));
const artifactRoot = resolve('.artifacts/lua-runner-cli-tests');

function withWorkspace(first, action) {
  mkdirSync(artifactRoot, { recursive: true });
  const cwd = mkdtempSync(join(artifactRoot, 'case-'));
  mkdirSync(join(cwd, 'tests/lua'), { recursive: true });
  writeFileSync(join(cwd, 'tests/lua/a_fail.lua'), first);
  writeFileSync(join(cwd, 'tests/lua/b_pass.lua'), "print('B_REAL_FENGARI_PASS')\n");
  try { action(cwd); }
  finally {
    // Only these explicit files and now-empty directories; never recursive deletion.
    for (const file of ['tests/lua/a_fail.lua', 'tests/lua/b_pass.lua', 'timeout-once.mjs'])
      rmSync(join(cwd, file), { force: true });
    for (const dir of ['tests/lua', 'tests', '']) rmdirSync(join(cwd, dir));
  }
}

const invoke = (cwd, args = []) => spawnSync(process.execPath, [...args, cli],
  { cwd, encoding: 'utf8', timeout: 5000, maxBuffer: 1024 * 1024 });

test('a same-named fixture in another workspace remains an ordinary real Lua script',()=>{
  withWorkspace("print('OTHER_WORKSPACE')\n",cwd=>{
    for(const name of historicalPresentationFixtures){
    writeFileSync(join(cwd,name),"print('INDEPENDENT_TRACE_FIXTURE_PASS')\n");
    try{
      const result=spawnSync(process.execPath,[cli,name],{cwd,encoding:'utf8',timeout:5000});
      assert.ifError(result.error);assert.equal(result.status,0,result.stderr);
      assert.match(result.stdout,/INDEPENDENT_TRACE_FIXTURE_PASS/);
      assert.doesNotMatch(result.stdout,/Historical presentation replay/);
    }finally{rmSync(join(cwd,name));}
    }
  });
});

test('historical routing permits only two presentation and four frozen Sapphire fixtures without case selection',()=>{
  assert.deepEqual(historicalPresentationFixtures,[
    'tests/lua/presentation_responsibilities_trace.lua',
    'tests/lua/presentation_responsibilities_text.lua',
    'tests/lua/sapphire_treasure.lua',
    'tests/lua/sapphire_treasure_slice_2.lua',
    'tests/lua/sapphire_treasure_slice_3.lua',
    'tests/lua/sapphire_treasure_slice_4.lua',
  ]);
  for(const name of ['presentation_responsibilities_text.lua','tests/lua/presentation_responsibilities_text.lua.extra',
    'other/presentation_responsibilities_trace.lua','tests/lua/sapphire_treasure.lua.extra',
    'other/sapphire_treasure.lua','tests/lua/sapphire_treasure_ui.lua','tests/lua/sapphire_current_relics.lua'])
    assert.throws(()=>runHistoricalPresentation(null,name),/only exact historical presentation fixtures/);
  for(const name of historicalPresentationFixtures)
    assert.throws(()=>runHistoricalPresentation(null,name,{caseName:'one case'}),/complete historical scenario/);
});

test('actual CLI continues after ordinary Lua failure and retains failure after later success', () => {
  withWorkspace("print('A_BEFORE_FAILURE'); error('A_EXPECTED_FAILURE')\n", cwd => {
    const result = invoke(cwd);
    assert.ifError(result.error);
    assert.notEqual(result.status, 0, result.stderr);
    assert.match(result.stdout, /A_BEFORE_FAILURE/);
    assert.match(result.stderr, /A_EXPECTED_FAILURE/);
    assert.match(result.stdout, /B_REAL_FENGARI_PASS/);
    assert.match(result.stdout, /Lua fixture tests\/lua\/a_fail.lua: \d+ ms/);
    assert.match(result.stdout, /Lua fixture tests\/lua\/b_pass.lua: \d+ ms/);
  });
});

test('actual CLI continues after one injected spawn timeout and executes the next real Fengari fixture', () => {
  withWorkspace("error('first fixture must be intercepted')\n", cwd => {
    const bootstrap = join(cwd, 'timeout-once.mjs');
    writeFileSync(bootstrap, `import childProcess from 'node:child_process';
import { syncBuiltinESMExports } from 'node:module';
const original = childProcess.spawnSync;
let first = true;
childProcess.spawnSync = (...args) => {
  if (!first) return original(...args);
  first = false;
  return { error: Object.assign(new Error('spawnSync node ETIMEDOUT'), { code: 'ETIMEDOUT' }),
    status: null, signal: 'SIGTERM', stdout: 'A_TIMEOUT_PARTIAL_OUTPUT\\n', stderr: 'A_TIMEOUT_DIAGNOSTIC\\n' };
};
syncBuiltinESMExports();
`);
    const result = invoke(cwd, ['--import', pathToFileURL(bootstrap).href]);
    assert.ifError(result.error);
    assert.notEqual(result.status, 0, result.stderr);
    assert.match(result.stderr, /Lua runner failed \(tests\/lua\/a_fail.lua, 30000 ms\).*ETIMEDOUT/);
    assert.match(result.stderr, /A_TIMEOUT_PARTIAL_OUTPUT/);
    assert.match(result.stderr, /A_TIMEOUT_DIAGNOSTIC/);
    assert.match(result.stdout, /B_REAL_FENGARI_PASS/);
    assert.match(result.stdout, /Lua fixture tests\/lua\/a_fail.lua: \d+ ms/);
    assert.match(result.stdout, /Lua fixture tests\/lua\/b_pass.lua: \d+ ms/);
  });
});

test('actual CLI exits zero when every discovered real Lua fixture succeeds', () => {
  withWorkspace("print('A_REAL_FENGARI_PASS'); io.stderr:write('A_SUCCESS_DIAGNOSTIC\\n')\n", cwd => {
    const result = invoke(cwd);
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /A_REAL_FENGARI_PASS/);
    assert.match(result.stdout, /B_REAL_FENGARI_PASS/);
    assert.match(result.stderr, /A_SUCCESS_DIAGNOSTIC/);
    assert.match(result.stdout, /Lua fixture tests\/lua\/a_fail.lua: \d+ ms/);
    assert.match(result.stdout, /Lua fixture tests\/lua\/b_pass.lua: \d+ ms/);
  });
});
