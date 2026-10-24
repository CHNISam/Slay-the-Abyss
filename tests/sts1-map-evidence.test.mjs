import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, cpSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, relative, isAbsolute } from 'node:path';
import { normalizeOracle, normalizeProject, projectTerminalErrors, diffMaps, mapInvariants, requestedSeeds, compareFixtures, exportProjectMaps } from '../scripts/sts1-map-evidence.mjs';

const graph = {
  nodes: Array.from({ length: 15 }, (_, y) => ({ x: 0, y, type: y === 0 ? 'combat' : y === 8 ? 'treasure' : y === 14 ? 'camp' : 'event' })),
  edges: Array.from({ length: 14 }, (_, y) => ({ src_x: 0, src_y: y, dst_x: 0, dst_y: y + 1 })),
};

function withTerminals(generated) {
  const nodes = generated.nodes.map(n => ({ id: `${n.x},${n.y}`, floor: n.y + 1, lane: n.x + 1, type: n.type,
    nextIds: generated.edges.filter(e => e.src_x === n.x && e.src_y === n.y).map(e => `${e.dst_x},${e.dst_y}`) }));
  for (const node of nodes) if (node.floor === 15) node.nextIds = ['boss'];
  nodes.push({ id: 'boss', floor: 16, lane: 4, type: 'boss', nextIds: ['chest'] },
    { id: 'chest', floor: 17, lane: 4, type: 'treasure', roomKind: 'boss_treasure', nextIds: [] });
  return { nodes };
}

test('golden comparison projects generated rows while separately validating both terminal rooms', () => {
  const map = withTerminals(graph);
  assert.deepEqual(normalizeProject(map), graph);
  assert.deepEqual(projectTerminalErrors(map), []);
  const report = compareFixtures(undefined, seed => {
    const fixture = JSON.parse(readFileSync(`tests/fixtures/sts1/maps/${seed}.json`, 'utf8'));
    const project = withTerminals(fixture);
    return { seed, status: 'EXPORTED', graph: normalizeProject(project), terminalErrors: projectTerminalErrors(project) };
  });
  assert.equal(report.status, 'PASS');
  assert.equal(report.matches, 12); // Checker reachability only; not actual project parity.
});

test('terminal checks reject absent, duplicate, mistyped, mislinked and nonterminal boss treasure rooms', () => {
  for (const mutate of [
    m => m.nodes.pop(),
    m => m.nodes.push({ ...m.nodes.at(-2), id: 'boss2' }),
    m => { m.nodes.at(-2).type = 'combat'; },
    m => { delete m.nodes.at(-1).roomKind; },
    m => { m.nodes[14].nextIds = []; },
    m => { m.nodes[13].nextIds = ['boss']; },
    m => { m.nodes.at(-2).nextIds = []; },
    m => { m.nodes.at(-1).nextIds = ['boss']; },
  ]) {
    const map = withTerminals(graph); mutate(map);
    assert(projectTerminalErrors(map).length > 0);
  }
  const report = compareFixtures(undefined, seed => ({ seed, status: 'EXPORTED',
    graph: JSON.parse(readFileSync(`tests/fixtures/sts1/maps/${seed}.json`, 'utf8')), terminalErrors: ['missing Boss'] }));
  assert.equal(report.status, 'FAIL');
  assert.equal(report.matches, 0);
  const malformed = withTerminals(graph); malformed.nodes.at(-1).nextIds = ['missing'];
  assert.throws(() => normalizeProject(malformed), /Dangling/); // Projection must not hide bad terminal data.
});

test('canonical oracle and actual project schemas use the same zero-based coordinates', () => {
  const oracle = { nodes: [{ x: 2, y: 0, class: 'MonsterRoom' }, { x: 1, y: 1, class: 'EventRoom' }],
    edges: [{ src_x: 2, src_y: 0, dst_x: 1, dst_y: 1 }] };
  const project = { nodes: [{ id: 'a', floor: 1, lane: 3, type: 'combat', nextIds: ['b'] },
    { id: 'b', floor: 2, lane: 2, type: 'event', nextIds: [] }] };
  assert.deepEqual(normalizeOracle(oracle), normalizeProject(project));
  assert.deepEqual(diffMaps(normalizeOracle(oracle), normalizeProject(project)), { missingNodes: [], extraNodes: [], typeMismatches: [], missingEdges: [], extraEdges: [] });
});

test('diff cannot pass a swapped type, missing node, invented node or replaced edge', () => {
  const actual = structuredClone(graph);
  actual.nodes[0].type = 'boss';
  actual.nodes.splice(2, 1);
  actual.nodes.push({ x: 6, y: 2, type: 'shop' });
  actual.edges[0] = { src_x: 0, src_y: 0, dst_x: 1, dst_y: 1 };
  const diff = diffMaps(graph, actual);
  assert.equal(diff.missingNodes.length, 1);
  assert.equal(diff.extraNodes.length, 1);
  assert.equal(diff.typeMismatches.length, 1);
  assert.equal(diff.missingEdges.length, 1);
  assert.equal(diff.extraEdges.length, 1);
});

test('normalization rejects unknown classes, duplicates, dangling edges and malformed project coordinates', () => {
  for (const invalid of [
    { nodes: [{ x: 1, y: 1, class: 'UnknownRoom' }], edges: [] },
    { nodes: [{ x: 1, y: 1, class: 'EventRoom' }, { x: 1, y: 1, class: 'EventRoom' }], edges: [] },
    { nodes: [], edges: [{ src_x: 0, src_y: 0, dst_x: 0, dst_y: 1 }] },
    { nodes: [{ x: 0, y: 0, class: 'MonsterRoom' }, { x: 0, y: 1, class: 'EventRoom' }], edges: [{ src_x: '0', src_y: 0, dst_x: 0, dst_y: 1 }] },
  ]) assert.throws(() => normalizeOracle(invalid));
  assert.throws(() => normalizeProject({ nodes: [{ id: 'x', floor: 1, lane: 0, type: 'combat', nextIds: [] }] }));
  assert.throws(() => normalizeProject({ nodes: [{ id: 'x', floor: 1, lane: 1, type: 'combat', nextIds: ['absent'] }] }));
});

test('map structural checks reject old fixed floors and disconnected or crossing topology', () => {
  assert.deepEqual(mapInvariants(graph), []);
  for (const [floor, type] of [[0, 'shop'], [2, 'treasure'], [4, 'camp'], [8, 'shop'], [13, 'camp'], [14, 'boss']]) {
    const actual = structuredClone(graph); actual.nodes[floor].type = type;
    assert(mapInvariants(actual).length > 0, `${floor + 1}/${type}`);
  }
  const disconnected = structuredClone(graph); disconnected.edges.splice(4, 1);
  assert(mapInvariants(disconnected).some(error => error.includes('reach')));
  const crossing = structuredClone(graph);
  crossing.nodes.push({ x: 1, y: 0, type: 'combat' }, { x: 1, y: 1, type: 'event' });
  crossing.edges.push({ src_x: 0, src_y: 0, dst_x: 1, dst_y: 1 }, { src_x: 1, src_y: 0, dst_x: 0, dst_y: 1 });
  assert(mapInvariants(crossing).some(error => error.includes('cross')));
});

test('all twelve captured fixtures are individually hashed and structurally valid A0 black-box outputs', () => {
  const seeds = requestedSeeds();
  assert.equal(seeds.length, 12);
  assert(seeds.includes('2780424839485660359'));
  assert.equal(new Set(seeds).size, seeds.length);
  const report = compareFixtures(undefined, seed => {
    const map = JSON.parse(readFileSync(`tests/fixtures/sts1/maps/${seed}.json`, 'utf8'));
    assert.deepEqual(mapInvariants(map), [], seed);
    return { seed, status: 'EXPORTED', graph: map };
  });
  // This verifies the evidence checker on identical input, not project parity.
  assert.equal(report.status, 'PASS');
  assert.equal(report.matches, 12);
});

test('evidence checker rejects missing fixtures, changed hashes and omitted A0 flags', () => {
  const temporary = mkdtempSync(join(tmpdir(), 'abyss-evidence-test-'));
  const original = JSON.parse(readFileSync('tests/fixtures/sts1/maps/manifest.json', 'utf8'));
  const manifestPath = join(temporary, 'manifest.json');
  try {
    cpSync('tests/fixtures/sts1/maps', temporary, { recursive: true });
    const write = manifest => writeFileSync(manifestPath, JSON.stringify(manifest));
    const incomplete = structuredClone(original); incomplete.records.pop(); write(incomplete);
    assert.throws(() => compareFixtures(temporary), /Incomplete/);
    const duplicate = structuredClone(original); duplicate.records[0] = duplicate.records[1]; write(duplicate);
    assert.throws(() => compareFixtures(temporary), /duplicate/);
    const noA0 = structuredClone(original); noA0.records[0].arguments.pop(); write(noA0);
    assert.throws(() => compareFixtures(temporary), /flags/);
    for (const patch of [{ exitCode: 23 }, { exitCode: null }, { error: 'spawn failed' }, { invariantErrors: ['invalid row'] }]) {
      const invalid = structuredClone(original); Object.assign(invalid.records[0], patch); write(invalid);
      assert.throws(() => compareFixtures(temporary), /process evidence/);
    }
    write(original);
    writeFileSync(join(temporary, original.records[0].file), '{}');
    assert.throws(() => compareFixtures(temporary), /Changed fixture/);
  } finally {
    const inside = relative(resolve(tmpdir()), resolve(temporary));
    assert(!isAbsolute(inside) && !inside.startsWith('..') && inside.startsWith('abyss-evidence-test-'));
    rmSync(temporary, { recursive: true, force: true });
  }
});

test('actual Lua maps export full signed64 strings in original batch order', () => {
  const records = exportProjectMaps(['0', '2780424839485660359', '1']);
  assert.deepEqual(records.map(record=>record.seed),['0','2780424839485660359','1']);
  for (const seed of ['0', '2780424839485660359', '1']) {
    const record = records.find(entry => entry.seed === seed);
    assert.equal(record.status, 'EXPORTED');
    assert(record.graph.nodes.length > 0);
    assert(record.graph.nodes.every(node => node.y < 15));
    assert.deepEqual(record.terminalErrors, []);
  }
});
