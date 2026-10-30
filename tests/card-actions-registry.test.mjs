import test from 'node:test';
import assert from 'node:assert/strict';
import {preRelicRound3CompositionSource} from './helpers/relic-round3-composition.mjs';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';
import { luaString } from '../scripts/build-lua-data.mjs';
import luaparse from 'luaparse';

const before = 'tests/fixtures/card-actions-registry-before.lua';
const live = 'src/lua/abyss_card_actions.lua';
const read = path => readFileSync(path, 'utf8').replaceAll('\r\n', '\n');
const sha = source => createHash('sha256').update(source).digest('hex');
function execute(module, fixture, flag = '') {
  const dir = mkdtempSync(join(tmpdir(), 'abyss-action-registry-'));
  try {
    const driver = join(dir, 'driver.lua');
    writeFileSync(driver, `${flag};package.loaded.abyss_card_actions=dofile(${luaString(resolve(module).replaceAll('\\', '/'))});dofile(${luaString(resolve(fixture).replaceAll('\\', '/'))})`);
    const result = runLua(driver);
    assert.equal(result.status, 0, result.stderr || result.stdout.slice(-1500));
    return result.stdout;
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
function registryKeys() {
  const keys = new Set();
  const visit = node => {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'LocalStatement') for (const [i, variable] of node.variables.entries()) {
      if (variable.name === 'actionHandlers') for (const field of node.init[i].fields) keys.add(field.key.name);
    }
    if (node.type === 'FunctionDeclaration' && node.identifier?.base?.name === 'actionHandlers') keys.add(node.identifier.identifier.name);
    for (const child of Object.values(node)) if (child && typeof child === 'object') {
      if (Array.isArray(child)) child.forEach(visit); else visit(child);
    }
  };
  visit(luaparse.parse(read(live)));
  assert.ok(keys.size > 40, 'all local operation entries are discovered from the AST');
  return [...keys].sort();
}
test('fixed 9293405d action oracle, supports admission and victory policy remain unchanged', () => {
  assert.equal(sha(read(before)), '614ff20df48f8b2e10d9750f9857a2a4d68a8d4961c6be45a7e5144436d756c1');
  const section = (source, start, end) => {
    const at = source.indexOf(start);
    assert.ok(at >= 0 && source.indexOf(end, at) > at);
    return source.slice(at, source.indexOf(end, at));
  };
  for (const [start, end] of [['local operations =', 'function M.enqueue('], ['local retained=', 'return M']])
    assert.equal(section(preRelicRound3CompositionSource(live,read(live),'round3'), start, end), section(read(before), start, end));
});
for (const [fixture, flag] of [
  ['tests/lua/support/card_actions_registry_fixture.lua', ''],
  ['tests/lua/card_actions_exhaust.lua', 'ABYSS_EXHAUST_TRACE=true'],
  ['tests/lua/card_actions_hand_mutation.lua', 'ABYSS_HAND_MUTATION_TRACE=true'],
]) test(`real old/new action state, queues, returns and RNG agree: ${fixture}`, () => {
  assert.equal(execute(live, fixture, flag), execute(before, fixture, flag));
});
test('apply performs a single finite lookup rather than repeated op comparisons', () => {
  const source = read(live);
  const body = source.slice(source.indexOf('function M.apply(combat,state,item)'), source.indexOf('-- Only source-supported retained actions'));
  assert.match(body, /local handler=actionHandlers\[item.effect.op\]/);
  assert.doesNotMatch(body, /(?:op|effect\.op)\s*==|exhaustActions\[|handMutationActions\[/);
});
test('finite local registry has no collisions with any dynamic domain', () => {
  const dir = mkdtempSync(join(tmpdir(), 'abyss-action-domain-'));
  try {
    const fixture = join(dir, 'domains.lua');
    const keys = registryKeys().map(luaString).join(',');
    writeFileSync(fixture, `local P=require('abyss_plated_armor');local A=require('abyss_act2_powers');local W=require('abyss_watcher_final_cards');for _,op in ipairs({${keys}})do assert(not P.supports(op)and not A.supports(op)and not W.ops[op],op..' domain collision')end;print('DOMAIN_DISJOINT')`);
    assert.match(execute(live, fixture), /DOMAIN_DISJOINT/);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
test('common local operations eliminate real dynamic-domain probes and watcher lookups', () => {
  const fixture = 'tests/lua/support/card_actions_registry_fixture.lua';
  const old = execute(before, fixture, 'ABYSS_REGISTRY_PROFILE=true').trim().split(/\r?\n/);
  const current = execute(live, fixture, 'ABYSS_REGISTRY_PROFILE=true').trim().split(/\r?\n/);
  assert.equal(old.length, 7);
  assert.equal(current.length, old.length);
  for (const [i, line] of old.entries()) {
    const previous = line.split(' '), next = current[i].split(' ');
    assert.deepEqual(next.slice(0, 2), previous.slice(0, 2));
    assert.equal(previous.length, 6);
    for (let column = 2; column < 6; column++) {
      assert.equal(Number(previous[column]) - Number(next[column]), 1, `${previous[1]} probe ${column - 2}`);
      assert.ok(Number(next[column]) >= 0);
    }
    console.log(`${line} -> ${current[i].split(' ').slice(2).join(' ')}`);
  }
});
