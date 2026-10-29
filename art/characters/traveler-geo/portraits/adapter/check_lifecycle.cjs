// Image-only portrait contract. Reuses the exact pinned checker's vm() mock API.
// No game SDK, real template ID, device rendering or physical cleanup claim.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const args = process.argv.slice(2);
if (args.length !== 4) throw Error('Usage: node check_lifecycle.cjs <cache-root> <portrait.lua> <portrait.json> <new-receipt.json>');
const [cache, luaFile, jsonFile, receiptFile] = args.map(p => path.resolve(p));
if (fs.existsSync(receiptFile)) throw Error('Use a new receipt path; do not overwrite evidence');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sourceBytes = fs.readFileSync(luaFile), sceneBytes = fs.readFileSync(jsonFile);
const source = sourceBytes.toString('utf8'), scene = JSON.parse(sceneBytes);
const fixturePath = path.join(cache, 'upstream/backend/tests/check_textbox_lua.cjs');
const fixtureBytes = fs.readFileSync(fixturePath);
const blob = crypto.createHash('sha1').update(Buffer.from(`blob ${fixtureBytes.length}\0`)).update(fixtureBytes).digest('hex');
if (blob !== 'ced76db25cd9e386d9c2dd683ea8f0aeef1b35aa') throw Error('Pinned upstream checker mismatch');
const assets = {rectangle: 100001, ellipse: 100002, triangle: 100003};
const elements = [...scene.elements].sort((a, b) => Number(b.isBackground) - Number(a.isBackground) || a.zIndex - b.zIndex);
assert(elements.length >= 1 && elements.every(e => assets[e.type] && !e.luaMask && !e.rotationX && !e.rotationY));
const count = elements.length;
assert.equal((source.match(/local IMAGE_PREFAB_ID = 0/g) || []).length, 1);
assert(!source.includes('local TEXTBOX_PREFAB_ID'));
assert(source.includes('function OnDestroy()\n    Clear()\nend'), 'Expect actual unmasked direct cleanup runtime');
const configured = source.replace('local IMAGE_PREFAB_ID = 0', 'local IMAGE_PREFAB_ID = 1234');
const fengari = require(path.join(cache, 'lua-runtime/node_modules/fengari'));
const open = fengari.lualib.luaL_openlibs;
fengari.lualib.luaL_openlibs = L => {
  open(L);
  const restricted = 'io=nil;os=nil;package=nil;require=nil;dofile=nil;loadfile=nil;load=nil;fengari=nil;debug={traceback=debug.traceback}';
  if (fengari.lauxlib.luaL_dostring(L, fengari.to_luastring(restricted)) !== fengari.lua.LUA_OK) throw Error('Cannot restrict Lua VM');
};
const blocked = [];
const deny = name => () => { blocked.push(name); throw Error('Offline VM prohibits ' + name); };
for (const name of ['exec', 'execFile', 'execSync', 'execFileSync', 'spawn', 'spawnSync', 'fork']) require('node:child_process')[name] = deny(name);
for (const [module, names] of [['net', ['connect', 'createConnection', 'createServer']], ['http', ['request', 'get', 'createServer']], ['https', ['request', 'get', 'createServer']], ['dgram', ['createSocket']]])
  for (const name of names) require('node:' + module)[name] = deny(module + '.' + name);
global.fetch = deny('fetch');
const fixture = fixtureBytes.toString('utf8');
const begin = fixture.indexOf('function vm(script) {');
const end = fixture.indexOf('\nvm(source)(');
assert(begin > 0 && end > begin);
// No altered vendor file or synthetic textbox. Only its exact helper function.
const makeVm = require('node:vm').runInThisContext('(function(deps){\n' +
  'const {assert,lua,lauxlib,lualib,to_luastring,to_jsstring,maskSlots,controlCount}=deps;\n' +
  fixture.slice(begin, end) + '\nreturn vm;\n})', {filename: fixturePath + ': image-only helper reuse'});
const exactVm = makeVm({...fengari, assert, maskSlots: [], controlCount: count});
let latestState;
const newState = fengari.lauxlib.luaL_newstate;
fengari.lauxlib.luaL_newstate = () => (latestState = newState());
const vm = script => {
  const run = exactVm(script), state = latestState;
  run.close = () => fengari.lua.lua_close(state);
  return run;
};
const liveHelpers = `
function LiveCount()
 local n=0; for _,c in ipairs(controls) do if c.alive then n=n+1 end end; return n
end
`;
const unbound = vm(source);
unbound('OnStart(); assert(#controls==0 and #errors==1)'); unbound.close();
const missingHost = vm(configured);
missingHost('script.object=nil; OnStart(); assert(#controls==0 and #errors==0)'); missingHost.close();
const run = vm(configured);
run(liveHelpers);
run(`OnStart(); assert(#controls==${count} and #errors==0 and LiveCount()==${count})`);
const near = (actual, value) => `assert(math.abs(${actual}-(${value}))<0.00021)`;
let geometryChecks = [];
for (const [i, e] of elements.entries()) {
  const c = `controls[${i + 1}]`;
  geometryChecks.push(`assert(${c}.alive and ${c}.top and ${c}.parent==script.object and ${c}.asset==${assets[e.type]} and ${c}.source=='static')`);
  for (const [key, vector] of Object.entries({
    SetAnchoredPositionValue: [e.x - scene.canvas.width / 2, scene.canvas.height / 2 - e.y],
    SetSizeDeltaValue: [e.width, e.height], SetPivotValue: [.5, .5],
    SetAnchorMinValue: [.5, .5], SetAnchorMaxValue: [.5, .5],
    SetLocalScaleValue: [1, 1, 1], SetLocalRotationValue: [0, 0, e.rotation],
    imageColor: [1, 3, 5].map(offset => parseInt(e.color.slice(offset, offset + 2), 16)).concat(Math.round(e.opacity * 255)),
  })) vector.forEach((value, j) => geometryChecks.push(near(`${c}.${key}[${j + 1}]`, value)));
  if (i % 32 === 31 || i === elements.length - 1) { run(geometryChecks.join(';\n')); geometryChecks = []; }
}
run(near('script.object.SetSizeDeltaValue[1]', scene.canvas.width));
run(near('script.object.SetSizeDeltaValue[2]', scene.canvas.height));
run('OnDestroy(); assert(LiveCount()==0)'); run.close();
for (let cycle = 0; cycle < 3; cycle++) {
  const life = vm(configured); life(liveHelpers);
  for (let start = 1; start <= 3; start++) life(`OnStart(); assert(#errors==0 and LiveCount()==${count} and destroyed==${(start - 1) * count})`);
  life(`OnDestroy(); OnDestroy(); assert(LiveCount()==0 and destroyed==${count * 3})`);
  life.close();
}
const failAt = Math.min(10, count), partialCases = [];
for (const mode of ['nil-image-creation', 'image-setter-throw']) {
  const failed = vm(configured); failed(liveHelpers);
  failed(`
local original=game.InstantiateClientUIControl
local attempts=0
game.InstantiateClientUIControl=function(id,parent)
 attempts=attempts+1
 ${mode === 'nil-image-creation' ? `if attempts==${failAt} then return nil end` : ''}
 local c=original(id,parent)
 ${mode === 'image-setter-throw' ? `if attempts==${failAt} then c.SetImage=function() error('injected setter failure') end end` : ''}
 return c
end
OnStart(); assert(#errors==1 and LiveCount()==0 and destroyed==${mode === 'nil-image-creation' ? failAt - 1 : failAt})
OnDestroy(); assert(LiveCount()==0)
OnStart(); assert(#errors==1 and LiveCount()==${count})
OnDestroy(); OnDestroy(); assert(LiveCount()==0)
`);
  partialCases.push({mode, failAt, recovered: true});
  failed.close();
}
assert.deepEqual(blocked, []);
assert.equal(hash(fs.readFileSync(luaFile)), hash(sourceBytes));
assert.equal(hash(fs.readFileSync(jsonFile)), hash(sceneBytes));
const report = {
  scope: 'offline image-only Lua/API mock contract, not a native platform result',
  upstreamCheckerGitBlob: blob, reusedHelper: 'exact vm(script) function',
  inputs: [{path: luaFile, bytes: sourceBytes.length, sha256: hash(sourceBytes)}, {path: jsonFile, bytes: sceneBytes.length, sha256: hash(sceneBytes)}],
  contentImages: count, extraMasks: 0, allocatedPerBuild: count, mockTemplateIndex: 1234,
  geometryRGBAOrder: 'pass', missingTemplateFailClosed: 'pass', missingHost: 'pass',
  cycles: 3, startsPerCycle: 3, liveAfterEachBuild: count, liveAfterOnDestroy: 0,
  repeatedOnDestroy: 'pass', partialCases, artifactBindingsEdited: false,
  cleanupContract: 'unmasked pinned runtime directly destroys its created children',
  testStateLifetime: 'each independent Fengari state is closed after its assertion group',
  templateDefaultVisibility: 'native template activation/visibility defaults not verified',
  synchronousReentry: 'not tested; unmasked upstream runtime has no reentry guard',
  externalAttempts: blocked, physicalCleanup: 'not_measured', officialCompile: 'not_run',
  officialImport: 'not_run', nativeB0B1: 'not_run', uploadIncrementBytes: null,
};
fs.writeFileSync(receiptFile, JSON.stringify(report, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify({contentImages: count, cycles: 3, startsPerCycle: 3, partialCases, nativeB0B1: 'not_run'}));
