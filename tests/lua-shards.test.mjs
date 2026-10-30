import { partition, jsShard, jsPlanningWeights, discoverJs, timings as runtimeTimings } from '../scripts/ci-shards.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { preCiLuaCalibrationSource } from './helpers/ci-lua-calibration-inverse.mjs';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { shardLuaScripts } from '../scripts/test-lua.mjs';
import {historicalTest,readHistoricalBaselineSource} from './helpers/historical-baseline-inputs.mjs';
import {qualityShardMatrices} from '../scripts/ci-quality-shape.mjs';

test('sorted shards partition every fixture without omission or duplication and reject invalid bounds', () => {
  const scripts = ['d.lua', 'b.lua', 'a.lua', 'e.lua', 'c.lua'];
  assert.deepEqual(shardLuaScripts(scripts, '1/2', {lua:{},unknownLuaMs:10000}), ['a.lua', 'c.lua', 'e.lua']);
  for (const count of [1, 2, 4, 64]) {
    const combined = Array.from({ length: count }, (_, index) => shardLuaScripts(scripts, `${index + 1}/${count}`)).flat();
    assert.equal(combined.length, scripts.length);
    assert.equal(new Set(combined).size, scripts.length);
    assert.deepEqual(combined.sort(), [...scripts].sort());
  }
  for (const value of ['', undefined, '0/1', '1/0', '2/1', '1/65', '-1/2', '1.5/2', '1/2/3', '01/2', 'Infinity/2']) {
    assert.throws(() => shardLuaScripts(scripts, value), /1 <= i <= n <= 64/);
  }
});

test('longest fixtures fill the least loaded combined JS/Lua shard deterministically', () => {
  const scripts = ['a.lua', 'b.lua', 'c.lua', 'd.lua', 'new.lua'];
  const timings = { lua: { 'a.lua': 80, 'b.lua': 70, 'c.lua': 20, 'd.lua': 10 }, unknownLuaMs: 30,
    windowsJsShardMs: [100, 0] };
  assert.deepEqual(shardLuaScripts(scripts, '1/2', timings), ['c.lua', 'd.lua', 'new.lua']);
  assert.deepEqual(shardLuaScripts(scripts, '2/2', timings), ['a.lua', 'b.lua']);
  assert.deepEqual(shardLuaScripts(scripts, '1/2', timings, 2), ['d.lua']);
  assert.deepEqual(shardLuaScripts(scripts, '2/2', timings, 2), ['a.lua', 'b.lua', 'c.lua', 'new.lua']);
  for (const workers of [0, 3, '2', NaN]) assert.throws(() => shardLuaScripts(scripts, '1/2', timings, workers), /workers must be/);
  assert.deepEqual(shardLuaScripts([...scripts].reverse(), '1/2', timings), shardLuaScripts(scripts, '1/2', timings));
  assert.deepEqual(shardLuaScripts(scripts, '1/1', timings), [...scripts].sort());
  for (const bad of [0, -1, NaN, Infinity, '10']) {
    assert.throws(() => shardLuaScripts(['a.lua'], '1/2', { lua: { 'a.lua': bad }, unknownLuaMs: 1 }), /positive finite/);
    assert.throws(() => shardLuaScripts(['new.lua'], '1/2', { lua: {}, unknownLuaMs: bad }), /positive finite/);
  }
  assert.throws(() => shardLuaScripts(['a.lua'], '1/2', { ...timings, windowsJsShardMs: [0, -1] }), /initial shard/);
  assert.throws(() => shardLuaScripts(['a.lua', 'a.lua'], '1/2', timings), /unique nonempty/);
});

test('measured scheduling retains every current fixture and reduces estimated critical path', () => {
  const timings = JSON.parse(readFileSync('scripts/ci-test-timings.json', 'utf8'));
  assert.equal(timings.source.runId, 40630641377);
  assert.equal(timings.source.headSha, '257d9e0c9a4f2b680b8d1fc07c26025451eb5ac8');
  assert.equal(timings.jsSource.runId, 40980643080);
  assert.equal(timings.jsSource.runAttempt, 1);
  assert.equal(timings.jsSource.headSha, 'ce62e753065666fd26c9d85587a8f3ae2a580689');
  assert.equal(timings.jsCalibration.previousMapEntries.win32,408);
  assert.equal(timings.jsCalibration.previousMapEntries.linux,408);
  assert.ok(Object.keys(timings.js.win32).length>=408);
  assert.ok(Object.keys(timings.js.linux).length>=408);
  assert.equal(Object.keys(timings.lua).length, 974);
  const scripts = readdirSync('tests/lua').filter(file => file.endsWith('.lua')).sort().map(file => `tests/lua/${file}`);
  const weight = script => timings.luaShard?.[script] ?? timings.lua[script] ?? timings.unknownLuaMs;
  for (const count of [1, 2, 4, 8, 64]) {
    const bins = Array.from({ length: count }, (_, i) => shardLuaScripts(scripts, `${i + 1}/${count}`));
    const combined = bins.flat();
    assert.deepEqual(combined.sort(), scripts);
    assert.equal(new Set(combined).size, scripts.length);
    const reversed = scripts.toReversed();
    assert.deepEqual(shardLuaScripts(reversed, `1/${count}`), bins[0]);
  }
  const count=qualityShardMatrices.windows.length;
  const newLoads = jsShard(discoverJs(), `1/${count}`, 'win32').loads;
  const oldLoads = Array(count).fill(0);
  const jsWeights=jsPlanningWeights(discoverJs(),'win32');
  discoverJs().sort().forEach((file, i) => { oldLoads[i % count] += jsWeights[file]; });
  scripts.forEach((script, i) => { oldLoads[i % count] += weight(script); });
  for (let i = 0; i < count; i++) for (const script of shardLuaScripts(scripts, `${i + 1}/${count}`)) newLoads[i] += weight(script);
  assert.ok(Math.max(...newLoads) < Math.max(...oldLoads), 'measured schedule must improve the estimated critical path');
  assert.ok(Math.max(...newLoads) - Math.min(...newLoads) <= Math.max(...scripts.map(weight)), 'LPT bins differ by at most one fixture');
});

test('dual-worker partition includes the full serial cost of deadline-sensitive fixtures', () => {
  const fixtures = ['a.lua', 'b.lua', 'c.lua', 'd.lua'];
  const timings = { lua: { 'a.lua': 50000, 'b.lua': 30000, 'c.lua': 8000, 'd.lua': 8000 },
    unknownLuaMs: 10000, windowsJsShardMs: [20000, 0] };
  assert.deepEqual(shardLuaScripts(fixtures, '1/2', timings, 2), ['b.lua', 'c.lua']);
  assert.deepEqual(shardLuaScripts(fixtures, '2/2', timings, 2), ['a.lua', 'd.lua']);
});

test('default Lua placement ignores stale aggregates for every supported shape and uses its current complete JS plan',()=>{
  const scripts=Array.from({length:24},(_,i)=>`unmeasured-${i}.lua`);
  const weights=Object.fromEntries(scripts.map(path=>[path,runtimeTimings.unknownLuaMs]));
  const prior=runtimeTimings.windowsJsShardMs;
  try{
    for(const count of [1,2,8,qualityShardMatrices.windows.length,64]){
      const current=jsShard(discoverJs(),`1/${count}`,'win32').loads;
      const expected=Array.from({length:count},(_,i)=>partition(scripts,`${i+1}/${count}`,weights,runtimeTimings.unknownLuaMs,current).files);
      runtimeTimings.windowsJsShardMs=[0,...Array(count-1).fill(1000000000)];
      const actual=Array.from({length:count},(_,i)=>shardLuaScripts(scripts,`${i+1}/${count}`));
      assert.deepEqual(actual,expected,'matching shard count never proves the aggregate used current files and weights');
    }
  }finally{
    if(prior===undefined)delete runtimeTimings.windowsJsShardMs;else runtimeTimings.windowsJsShardMs=prior;
  }
});

test('current placement retains the original inventory, safety classification and complete hosted budget plan', () => {
  const timings = JSON.parse(readFileSync('scripts/ci-test-timings.json', 'utf8'));
  assert.equal(createHash('sha256').update(JSON.stringify(timings.lua)).digest('hex'),
    'a248c3e406651577d6ead3655d4760421940a7a8d85bf77d95fc85513020153c', 'all original worker safety weights remain identical');
  assert.equal(timings.luaShardSource.runId, 40980643080);
  assert.equal(timings.luaShardSource.headSha, 'ce62e753065666fd26c9d85587a8f3ae2a580689');
  const files = Object.keys(timings.luaShard);
  const original=JSON.parse(readHistoricalBaselineSource('scripts/ci-test-timings.json'));
  const originalFiles=Object.keys(original.luaShard).sort();
  assert.equal(originalFiles.length, 1114);
  assert.equal(createHash('sha256').update(JSON.stringify(originalFiles)).digest('hex'),
    '6715884814c25b9813572d03237750fbf920f2cdbd0e7956e298e8c63d841157', 'the complete original measured inventory is unchanged');
  const mapHash=map=>createHash('sha256').update(JSON.stringify(map)).digest('hex');
  let previous=mapHash(original.luaShard);
  assert.equal(previous,'0da156a0e66c32fcfcf79bfb1ec07706f1531d029c317fe895e6c35a6e970db7');
  const measured=new Set(originalFiles);
  for(const update of timings.luaShardCalibrationUpdates){
    assert.equal(update.previousMapSha256,previous,'each calibration starts at the preceding complete map');
    assert.match(update.resultingMapSha256,/^[a-f0-9]{64}$/);
    assert.ok(Number.isSafeInteger(update.runId)&&update.runId>0);
    assert.ok(Number.isSafeInteger(update.runAttempt)&&update.runAttempt>0);
    assert.match(update.headSha,/^[a-f0-9]{40}$/);
    assert.ok(Array.isArray(update.sourceRecords)&&update.sourceRecords.length>0);
    for(const record of update.sourceRecords){
      assert.ok(Number.isSafeInteger(record.jobId)&&record.jobId>0);
      assert.match(record.path,/^build\/[a-zA-Z0-9-]+\.log$/);
      assert.match(record.sha256,/^[a-f0-9]{64}$/);
    }
    assert.ok(Array.isArray(update.newlyMeasuredPaths));
    assert.deepEqual(update.newlyMeasuredPaths,[...new Set(update.newlyMeasuredPaths)].sort(),'new measurements have one explicit sorted inventory');
    for(const file of update.newlyMeasuredPaths){
      assert.equal(measured.has(file),false,'a newly measured path cannot already belong to an earlier map');
      measured.add(file);
    }
    previous=update.resultingMapSha256;
  }
  assert.equal(mapHash(timings.luaShard),previous,'the last calibration hash binds the actual current placement map');
  assert.deepEqual([...files].sort(),[...measured].sort(),'only original or explicitly newly measured paths belong to the map');
  for(const file of files){
    assert.ok(Number.isFinite(timings.luaShard[file])&&timings.luaShard[file]>0);
    if(Object.hasOwn(original.luaShard,file))assert.ok(timings.luaShard[file]>=original.luaShard[file],'original observations cannot decrease');
  }
  const current = readdirSync('tests/lua').filter(file => file.endsWith('.lua')).map(file => `tests/lua/${file}`);
  assert.ok(files.every(file => current.includes(file)), 'complete measured inventory remains discovered');
  const count=qualityShardMatrices.windows.length;
  const short = file => (timings.lua[file] ?? timings.unknownLuaMs) < 10000;
  const js = jsShard(discoverJs(), `1/${count}`, 'win32').loads;
  const bins=Array.from({length:count},(_,i)=>shardLuaScripts(current,`${i+1}/${count}`,runtimeTimings,2));
  assert.deepEqual(bins.flat().sort(),[...current].sort(),'every current raw fixture executes once, including unmeasured inputs');
  const observed=file=>timings.luaShard[file]??timings.lua[file]??timings.unknownLuaMs;
  const combined=bins.map((bin,i)=>{
    const pool=[0,0];
    for(const file of bin.filter(short).sort((a,b)=>(timings.lua[b]??timings.unknownLuaMs)-(timings.lua[a]??timings.unknownLuaMs)||a.localeCompare(b)))
      pool[pool[0]<=pool[1]?0:1]+=observed(file);
    return js[i]+bin.filter(file=>!short(file)).reduce((sum,file)=>sum+observed(file),0)+Math.max(...pool);
  });
  assert.ok(Math.max(...combined)+60000<1800000,'the complete current plan plus sixty-second setup sensitivity fits the original thirty-minute hosted budget');
  const sample = { lua: { heavy: 20000, short: 100 }, luaShard: { heavy: 100, short: 20000 }, unknownLuaMs: 10000 };
  assert.deepEqual(shardLuaScripts(['heavy', 'short'], '1/2', sample, 2), ['short']);
  for (const invalid of [0, -1, Infinity, NaN, '100']) {
    assert.throws(() => shardLuaScripts(['heavy'], '1/2', { ...sample, luaShard: { heavy: invalid } }, 2), /positive finite/);
    assert.throws(() => shardLuaScripts(['heavy'], '1/2', { ...sample, lua: { heavy: invalid } }, 2), /positive finite/);
  }
});

test('original 1114-fixture placement experiment retains its eight-shard improvement and spread',()=>{
  const raw=readHistoricalBaselineSource('scripts/ci-test-timings.json');
  assert.equal(createHash('sha256').update(raw).digest('hex'),'4039efc1bc954f541bcacac619550daa1231a4b3894ebe6568697d2f10af7ad8');
  const timings=JSON.parse(raw),files=Object.keys(timings.luaShard);
  assert.equal(files.length,1114);
  assert.equal(createHash('sha256').update(JSON.stringify(timings.luaShard)).digest('hex'),'0da156a0e66c32fcfcf79bfb1ec07706f1531d029c317fe895e6c35a6e970db7');
  // Git 98fef95d's complete 538-file JS inventory (sorted SHA256
  // 3abdc08613b8538cf3883e5831d17829ec954645b4c9a6aff80bbd7feb352353),
  // original Windows map and first-shard gate reconstruct these fixed loads.
  const js=[619528,619528,619529,619529,619528,619528,619528,619534];
  const calibrated={...timings,windowsJsShardMs:js},old={...calibrated};delete old.luaShard;
  const short=file=>(timings.lua[file]??timings.unknownLuaMs)<10000;
  function loads(weights){
    const bins=Array.from({length:8},(_,i)=>shardLuaScripts(files,`${i+1}/8`,weights,2));
    assert.deepEqual(bins.flat().sort(),[...files].sort(),'all original measured files exactly once');
    return bins.map((bin,i)=>{
      const pool=[0,0];
      for(const file of bin.filter(short).sort((a,b)=>timings.lua[b]-timings.lua[a]||a.localeCompare(b)))
        pool[pool[0]<=pool[1]?0:1]+=timings.luaShard[file];
      return js[i]+bin.filter(file=>!short(file)).reduce((sum,file)=>sum+timings.luaShard[file],0)+Math.max(...pool);
    });
  }
  const before=loads(old),after=loads(calibrated);
  assert.ok(Math.max(...after)<Math.max(...before)*0.95,'same measured workload improves projected maximum by at least 5%');
  assert.ok(Math.max(...after)-Math.min(...after)<1000,'projected combined spread remains under one second');
});

historicalTest('placement inverse preserves original runner bytes and exposes every unrelated mutation', () => {
  const path = 'scripts/test-lua.mjs', source = readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
  const sha = value => createHash('sha256').update(value).digest('hex');
  const before = '66dc757b28cbe4a0f802d7f660299f1e91f8381bd44a08ac2e69aff2d3398ab2';
  for (const text of [source, source.replaceAll('\n', '\r\n')]) assert.equal(sha(preCiLuaCalibrationSource(path, text)), before);
  for (const text of [source + '\n', source.replace('60000 : 30000', '60000 : 60000'), source.replace('runtimeTimings.lua });', 'runtimeTimings.luaShard });')]) {
    assert.notEqual(text, source);
    assert.equal(preCiLuaCalibrationSource(path, text), text, 'partial and foreign sources never receive historical identity');
  }
  assert.equal(preCiLuaCalibrationSource('scripts/other.mjs', source), source);
});

test('real CLI shards retain failure exit and continuation, allow empty slices and reject invalid arguments', () => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-lua-shards-')), cli = resolve('scripts/test-lua.mjs');
  const run = args => spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: 'utf8', timeout: 10000, windowsHide: true });
  try {
    mkdirSync(join(root, 'tests/lua'), { recursive: true });
    assert.notEqual(run(['--shard', '1/2']).status, 0, 'an undiscovered suite must still fail');
    // Name-only JS inputs make the preceding-load model identical to this
    // checkout; the Lua-only child never executes these synthetic JS files.
    for(const path of discoverJs())writeFileSync(join(root,path),'');
    const inputs=['tests/lua/a.lua','tests/lua/b.lua','tests/lua/c.lua'];
    const selections=[1,2].map(i=>shardLuaScripts(inputs,`${i}/2`));
    const failedIndex=selections.findIndex(files=>files.length>=2),passedIndex=1-failedIndex;
    const failedFiles=selections[failedIndex];assert.ok(failedFiles&&selections[passedIndex].length>0);
    for(const path of inputs)writeFileSync(join(root,path),path===failedFiles[0]?"print('failed block');error('CLI failure')"
      :failedFiles.includes(path)?"print('later block')":"print('other shard')");
    const failedShard=`${failedIndex+1}/2`,passedShard=`${passedIndex+1}/2`;
    const emptyIndex=[1,2,3,4].find(i=>shardLuaScripts(inputs,`${i}/4`).length===0),emptyShard=`${emptyIndex}/4`;
    assert.ok(emptyIndex,'a four-bin plan with three fixtures retains an empty slice');
    for (const args of [['--shard'], ['--shard', '2/1'], ['--shard', '1/65'], ['--unknown'], ['some.lua', '--shard', '1/2'],
      ['--workers'], ['--workers', '0'], ['--workers', '3'], ['--workers', '2', '--workers', '1']]) {
      assert.notEqual(run(args).status, 0);
    }
    const failed = run(['--shard', failedShard]);
    assert.ifError(failed.error);
    assert.notEqual(failed.status, 0);
    assert.match(failed.stderr, /CLI failure/);
    assert.match(failed.stdout, /failed block[\s\S]*later block/);
    for(const path of failedFiles)assert.ok(failed.stdout.includes(`Lua fixture ${path}:`),'every selected file continues after failure');
    assert.doesNotMatch(failed.stdout, /other shard/);
    const passed = run(['--shard', passedShard]), empty = run(['--shard', emptyShard]);
    assert.equal(passed.status, 0, passed.stderr);
    assert.match(passed.stdout, /other shard/);
    assert.equal(empty.status, 0, empty.stderr);
    assert.ok(empty.stdout.includes(`Lua shard ${emptyShard}: 0 fixtures`));
    const parallel = run(['--shard', failedShard, '--workers', '2']);
    assert.ifError(parallel.error);
    assert.notEqual(parallel.status, 0);
    assert.match(parallel.stderr, /CLI failure/);
    assert.match(parallel.stdout, /failed block/);
    assert.match(parallel.stdout, /later block/);
    assert.doesNotMatch(parallel.stdout, /other shard/);
    const passedParallel = run(['--shard', passedShard, '--workers', '2']);
    assert.equal(passedParallel.status, 0, passedParallel.stderr);
    assert.match(passedParallel.stdout, /other shard/);
    const emptyParallel = run(['--shard', emptyShard, '--workers', '2']);
    assert.equal(emptyParallel.status, 0, emptyParallel.stderr);
    assert.ok(emptyParallel.stdout.includes(`Lua shard ${emptyShard}: 0 fixtures`));
  } finally {
    assert.ok(resolve(root).startsWith(resolve(tmpdir()) + sep));
    assert.match(root, /abyss-lua-shards-/);
    rmSync(root, { recursive: true, force: true });
  }
});
