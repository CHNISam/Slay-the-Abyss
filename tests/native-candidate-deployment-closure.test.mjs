import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join, resolve, relative, isAbsolute } from 'node:path';
import { tmpdir } from 'node:os';
import { candidateScriptFiles } from '../scripts/native-candidate-scripts.mjs';

const roots = ['abyss_curses', 'abyss_relic_pool', 'abyss_relic_hooks', 'abyss_act1_events',
  'abyss_potion_health', 'abyss_potion_random', 'abyss_fountain'];
const generated = ['abyss_data', 'abyss_map_layout', 'abyss_narrative', 'abyss_presentation', 'abyss_theme'];

function dependencyClosure(scripts) {
  const byName = new Map(scripts.map(script => [script.name, script]));
  const visited = new Set();
  function visit(name, parent) {
    assert.ok(byName.has(name), `${parent || 'production root'} requires missing deployed module ${name}`);
    if (visited.has(name)) return;
    visited.add(name);
    const source = readFileSync(byName.get(name).sourceFile, 'utf8');
    // Current runtime imports use literal abyss_* module IDs. Ignore platform
    // APIs and generated test helpers; this checks deployment, not Lua syntax.
    for (const match of source.matchAll(/\brequire\s*(?:\(\s*)?(['"])(abyss_[a-z0-9_]+)\1/g)) visit(match[2], name);
  }
  for (const name of roots) visit(name);
  return visited;
}

test('current M3 event/relic/potion modules and their complete literal dependency closure deploy automatically', () => {
  const directory = mkdtempSync(join(tmpdir(), 'abyss-deploy-closure-'));
  try {
    // No UI/data build or MCP process is needed to inspect the source manifest.
    // These represent only the five generated production modules, not fixtures.
    for (const name of generated) writeFileSync(join(directory, name + '.lua'), 'return {}\n');
    writeFileSync(join(directory, 'sts1_unknown_vectors.lua'), 'error("test fixture must not deploy")');
    const scripts = candidateScriptFiles('src/lua', directory);
    const names = scripts.map(script => script.name);
    const closure = dependencyClosure(scripts);
    for (const name of roots) assert.ok(closure.has(name), name);
    for (const name of generated) assert.ok(names.includes(name), name);
    assert.ok(!names.includes('sts1_unknown_vectors'));
    // A dropped transitive dependency must fail, even when every new root is present.
    assert.throws(() => dependencyClosure(scripts.filter(script => script.name !== 'abyss_sts_random')),
      /requires missing deployed module abyss_sts_random/);
  } finally {
    const inside = relative(resolve(tmpdir()), resolve(directory));
    assert.ok(!isAbsolute(inside) && !inside.startsWith('..') && inside.startsWith('abyss-deploy-closure-'));
    rmSync(directory, { recursive: true, force: true });
  }
});
