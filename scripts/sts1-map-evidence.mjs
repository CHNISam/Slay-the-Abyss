import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { isAbsolute, join, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { toLua } from './build-lua-data.mjs';
import { runLua } from './test-lua.mjs';

const oracleTypes = { MonsterRoom: 'combat', MonsterRoomElite: 'elite', RestRoom: 'camp',
  ShopRoom: 'shop', EventRoom: 'event', TreasureRoom: 'treasure' };
const projectTypes = new Set([...Object.values(oracleTypes), 'boss']);
const position = node => `${node.x},${node.y}`;
const edgeKey = edge => `${edge.src_x},${edge.src_y}>${edge.dst_x},${edge.dst_y}`;
const digest = value => createHash('sha256').update(value).digest('hex');
const orderNodes = (a, b) => a.y - b.y || a.x - b.x;
const orderEdges = (a, b) => a.src_y - b.src_y || a.src_x - b.src_x || a.dst_y - b.dst_y || a.dst_x - b.dst_x;
const coordinate = (n, min, max) => Number.isInteger(n) && n >= min && n <= max;

function removeStaging(directory) {
  const inside = relative(resolve(tmpdir()), resolve(directory));
  if (isAbsolute(inside) || inside.startsWith('..') || !inside.startsWith('abyss-')) throw Error('Unsafe temporary cleanup path');
  rmSync(directory, { recursive: true, force: true });
}

function canonical(nodes, edges) {
  const positions = new Set();
  for (const node of nodes) {
    if (!coordinate(node.x, 0, 6) || !coordinate(node.y, 0, 16) || !projectTypes.has(node.type)) throw Error('Invalid map node');
    if (positions.has(position(node))) throw Error(`Duplicate map node ${position(node)}`);
    positions.add(position(node));
  }
  const seen = new Set();
  for (const edge of edges) {
    if (!coordinate(edge.src_x, 0, 6) || !coordinate(edge.dst_x, 0, 6) ||
        !coordinate(edge.src_y, 0, 16) || !coordinate(edge.dst_y, 0, 16)) throw Error('Invalid map edge coordinates');
    if (!positions.has(`${edge.src_x},${edge.src_y}`) || !positions.has(`${edge.dst_x},${edge.dst_y}`)) throw Error('Dangling map edge');
    if (seen.has(edgeKey(edge))) throw Error('Duplicate map edge');
    seen.add(edgeKey(edge));
  }
  return { nodes: nodes.sort(orderNodes), edges: edges.sort(orderEdges) };
}

export function normalizeOracle(raw) {
  if (!Array.isArray(raw.nodes) || !Array.isArray(raw.edges)) throw Error('Oracle nodes and edges required');
  const nodes = raw.nodes.map(node => {
    if (!oracleTypes[node.class] || !coordinate(node.y, 0, 14)) throw Error(`Unknown Oracle room or row: ${node.class}/${node.y}`);
    return { x: node.x, y: node.y, type: oracleTypes[node.class] };
  });
  return canonical(nodes, raw.edges.map(({ src_x, src_y, dst_x, dst_y }) => ({ src_x, src_y, dst_x, dst_y })));
}

export function normalizeProject(map) {
  if (!Array.isArray(map.nodes)) throw Error('Project nodes required');
  const ids = new Map(map.nodes.map(node => [node.id, node]));
  if (ids.size !== map.nodes.length) throw Error('Duplicate project id');
  const nodes = [], edges = [];
  for (const node of map.nodes) {
    if (!coordinate(node.floor, 1, 17) || !coordinate(node.lane, 1, 7) || !Array.isArray(node.nextIds)) throw Error('Invalid project map coordinate or adjacency');
    nodes.push({ x: node.lane - 1, y: node.floor - 1, type: node.type });
    for (const id of node.nextIds) {
      const target = ids.get(id);
      if (!target) throw Error(`Dangling project edge ${id}`);
      edges.push({ src_x: node.lane - 1, src_y: node.floor - 1, dst_x: target.lane - 1, dst_y: target.floor - 1 });
    }
  }
  return canonical(nodes, edges);
}

export function diffMaps(expected, actual) {
  const wanted = new Map(expected.nodes.map(node => [position(node), node]));
  const found = new Map(actual.nodes.map(node => [position(node), node]));
  const wantedEdges = new Set(expected.edges.map(edgeKey)), foundEdges = new Set(actual.edges.map(edgeKey));
  return {
    missingNodes: expected.nodes.filter(node => !found.has(position(node))),
    extraNodes: actual.nodes.filter(node => !wanted.has(position(node))),
    typeMismatches: expected.nodes.filter(node => found.has(position(node)) && found.get(position(node)).type !== node.type)
      .map(node => ({ x: node.x, y: node.y, expected: node.type, actual: found.get(position(node)).type })),
    missingEdges: expected.edges.filter(edge => !foundEdges.has(edgeKey(edge))),
    extraEdges: actual.edges.filter(edge => !wantedEdges.has(edgeKey(edge))),
  };
}

// Structural checks only. Quotas, sibling fallback and ancestor/RNG behavior
// need exact independent golden comparison; this function cannot prove parity.
export function mapInvariants(map) {
  const errors = [], outgoing = new Map();
  const graph = canonical(structuredClone(map.nodes), structuredClone(map.edges));
  for (const node of graph.nodes) {
    const { x, y, type } = node;
    if (y > 14 || type === 'boss') errors.push(`non-map room at ${x},${y}`);
    const fixed = ({ 0: 'combat', 8: 'treasure', 14: 'camp' })[y];
    if (fixed && type !== fixed) errors.push(`fixed row ${y + 1}: ${type}`);
    if (y !== 8 && type === 'treasure') errors.push(`random treasure at ${x},${y}`);
    if (y < 5 && (type === 'elite' || type === 'camp')) errors.push(`early ${type} at ${x},${y}`);
    if (y === 13 && type === 'camp') errors.push(`floor-14 camp at ${x},${y}`);
  }
  for (const edge of graph.edges) {
    const src = `${edge.src_x},${edge.src_y}`, dst = `${edge.dst_x},${edge.dst_y}`;
    if (edge.dst_y !== edge.src_y + 1 || Math.abs(edge.src_x - edge.dst_x) > 1) errors.push(`invalid step ${edgeKey(edge)}`);
    outgoing.set(src, [...(outgoing.get(src) ?? []), dst]);
  }
  const reachable = new Set(graph.nodes.filter(node => node.y === 0).map(position));
  for (let row = 0; row < 15; row++) {
    const nodes = graph.nodes.filter(node => node.y === row);
    if (!nodes.length) errors.push(`missing row ${row}`);
    for (const node of nodes) {
      const id = position(node);
      if (!reachable.has(id)) errors.push(`unreachable ${id}`);
      if (row < 14 && !(outgoing.get(id)?.length)) errors.push(`cannot reach final camp from ${id}`);
      for (const dst of outgoing.get(id) ?? []) reachable.add(dst);
    }
  }
  for (const a of graph.edges) for (const b of graph.edges) {
    if (a.src_y === b.src_y && a.src_x < b.src_x && a.dst_x > b.dst_x) errors.push(`crossing ${edgeKey(a)} / ${edgeKey(b)}`);
  }
  return errors;
}

export function requestedSeeds(file = 'tests/fixtures/sts1/map_seeds.csv') {
  const lines = readFileSync(file, 'utf8').trim().split(/\r?\n/);
  if (lines.shift() !== 'seed,act,ascension,oracle_flag,expected_output_status') throw Error('Unexpected seed manifest schema');
  return lines.map(line => {
    const [seed, act, ascension, flag] = line.split(',');
    if (!/^-?\d+$/.test(seed) || act !== '1' || ascension !== '0' || flag !== '--a0') throw Error('Invalid StS1 A0 seed request');
    return seed;
  });
}

const provenance = {
  url: 'https://github.com/Ru5ty0ne/sts_map_oracle',
  release: 'v1.1.0', revision: 'ea5200f21fa566de77ec14b6155b3bf3756dccbf',
  executableSha256: 'add3b40d49dd5e2e371818bdc9ebfa991344b494732b0698ecaf392ecb0f3660',
  reportedVersion: 'sts_map_oracle 1.0.0',
  scope: { act: 1, ascension: 0, height: 15, width: 7, pathDensity: 6 },
  evidenceBoundary: 'Third-party black-box reference; not original-game verification or a license to reuse source code.',
};

export function captureOracle(executable, directory = 'tests/fixtures/sts1/maps') {
  if (digest(readFileSync(executable)) !== provenance.executableSha256) throw Error('Oracle executable hash differs from reviewed release');
  mkdirSync(directory, { recursive: true });
  const staging = mkdtempSync(join(tmpdir(), 'abyss-oracle-'));
  const records = [];
  try {
    for (const seed of requestedSeeds()) {
      const args = [`--seed=${seed}`, '--a0', '--path', staging];
      const result = spawnSync(resolve(executable), args, { encoding: 'utf8', timeout: 10000, maxBuffer: 1024 * 1024 });
      const record = { seed, arguments: args.slice(0, 2), exitCode: result.status, stderr: result.stderr?.trim() ?? '' };
      if (result.error || result.status !== 0) {
        record.status = 'ORACLE_FAILED'; record.error = result.error?.message ?? record.stderr;
      } else {
        const rawFile = `${seed}_Act1.json`, rawText = readFileSync(join(staging, rawFile), 'utf8');
        const graph = normalizeOracle(JSON.parse(rawText));
        record.invariantErrors = mapInvariants(graph);
        record.status = record.invariantErrors.length ? 'ORACLE_INVARIANT_FAILED' : 'CAPTURED';
        record.file = `${seed}.json`; record.rawSha256 = digest(rawText);
        writeFileSync(join(directory, record.file), JSON.stringify({ seed, ...provenance, rawSha256: record.rawSha256, ...graph }, null, 2) + '\n');
        record.fixtureSha256 = digest(readFileSync(join(directory, record.file)));
      }
      records.push(record);
    }
  } finally { removeStaging(staging); }
  const manifest = { ...provenance, capturedAt: new Date().toISOString(), records };
  writeFileSync(join(directory, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}

export function exportProjectMaps(seeds) {
  // Never round a 64-bit Oracle seed or quietly substitute a different seed.
  const supported = seeds.filter(seed => Number.isSafeInteger(Number(seed)));
  const failures = seeds.filter(seed => !Number.isSafeInteger(Number(seed)))
    .map(seed => ({ status: 'UNSUPPORTED_PROJECT_SEED', seed }));
  if (!supported.length) return failures;
  const staging = mkdtempSync(join(tmpdir(), 'abyss-map-'));
  try {
    const script = join(staging, 'export.lua');
    writeFileSync(script, `local Map = require('abyss_map')\nlocal data = require('abyss_data')\nfor _, input in ipairs(${toLua(supported)}) do\nlocal map = Map.generate(data, tonumber(input))\nlocal nodes = {}\nfor _, n in ipairs(map.nodes) do\n local nextIds = {}\n for _, id in ipairs(n.nextIds) do nextIds[#nextIds+1] = string.format('%q', id) end\n nodes[#nodes+1] = string.format('{"id":%q,"floor":%d,"lane":%d,"type":%q,"nextIds":[%s]}', n.id, n.floor, n.lane, n.type, table.concat(nextIds, ','))\nend\nprint('{"seed":' .. string.format('%q',input) .. ',"nodes":[' .. table.concat(nodes, ',') .. ']}')\nend\n`);
    const result = runLua(script);
    if (result.status !== 0) return [...failures, ...supported.map(seed => ({ status: 'PROJECT_EXECUTION_FAILED', seed, error: result.stderr || result.stdout }))];
    const outputs = result.stdout.trim().split(/\r?\n/).map(line => JSON.parse(line));
    if (outputs.length !== supported.length || outputs.some((map, i) => map.seed !== supported[i])) throw Error('Project exporter returned incomplete or reordered maps');
    return [...failures, ...outputs.map(map => ({ status: 'EXPORTED', seed: map.seed, graph: normalizeProject(map) }))];
  } finally { removeStaging(staging); }
}

export function exportProjectMap(seed) {
  return exportProjectMaps([seed])[0];
}

export function auditProjectSeeds(count, start = 0) {
  if (!Number.isSafeInteger(count) || count < 1 || count > 100000 || !Number.isSafeInteger(start) || start < 0 || !Number.isSafeInteger(start + count)) throw Error('Invalid property seed range');
  const report = { status: 'PASS', requested: count, executed: 0, passed: 0, failed: 0, executionErrors: 0,
    seedRange: { start: String(start), end: String(start + count - 1) }, examples: [],
    scope: 'Structural invariants only; not golden parity, quota/ancestor proof, or platform verification.' };
  for (let offset = 0; offset < count; offset += 50) {
    const seeds = Array.from({ length: Math.min(50, count - offset) }, (_, i) => String(start + offset + i));
    for (const result of exportProjectMaps(seeds)) {
      if (result.status !== 'EXPORTED') { report.executionErrors++; report.status = 'FAIL'; continue; }
      report.executed++;
      const errors = mapInvariants(result.graph);
      if (errors.length) {
        report.failed++; report.status = 'FAIL';
        if (report.examples.length < 10) report.examples.push({ seed: result.seed, errors });
      } else report.passed++;
    }
    if (offset % 1000 === 0) process.stderr.write(`Audited ${report.executed}/${count} project seeds\n`);
  }
  return report;
}

export function compareFixtures(directory = 'tests/fixtures/sts1/maps', exporter = exportProjectMap) {
  const manifest = JSON.parse(readFileSync(join(directory, 'manifest.json'), 'utf8'));
  const seeds = requestedSeeds(), records = [];
  if (manifest.revision !== provenance.revision || manifest.executableSha256 !== provenance.executableSha256 ||
      JSON.stringify(manifest.scope) !== JSON.stringify(provenance.scope)) throw Error('Unrecognized Oracle provenance');
  if (manifest.records.length !== seeds.length || new Set(manifest.records.map(record => record.seed)).size !== seeds.length) throw Error('Incomplete or duplicate fixture manifest');
  for (const seed of seeds) {
    const reference = manifest.records.find(record => record.seed === seed);
    if (!reference || reference.status !== 'CAPTURED') {
      records.push({ seed, status: reference?.status ?? 'MISSING_FIXTURE', error: reference?.error }); continue;
    }
    if (reference.file !== `${seed}.json` || JSON.stringify(reference.arguments) !== JSON.stringify([`--seed=${seed}`, '--a0'])) throw Error('Invalid Oracle seed/flags/path');
    const contents = readFileSync(join(directory, reference.file));
    if (digest(contents) !== reference.fixtureSha256) throw Error(`Changed fixture ${seed}`);
    const expected = JSON.parse(contents);
    if (expected.seed !== seed || expected.revision !== manifest.revision || expected.rawSha256 !== reference.rawSha256) throw Error('Fixture provenance mismatch');
    const actual = exporter(seed);
    if (actual.status !== 'EXPORTED') { records.push(actual); continue; }
    const diff = diffMaps(expected, actual.graph), invariantErrors = mapInvariants(actual.graph);
    const matched = Object.values(diff).every(entries => entries.length === 0) && invariantErrors.length === 0;
    records.push({ seed, status: matched ? 'MATCH' : 'MISMATCH', diff, invariantErrors });
  }
  const matches = records.filter(record => record.status === 'MATCH').length;
  return { status: matches >= 10 && records.every(record => record.status === 'MATCH') ? 'PASS' : 'FAIL',
    matches, requested: seeds.length, oracle: { ...provenance }, records,
    propertySeedRuns: 0, platformCompile: 'NOT_EXECUTED', saveImport: 'NOT_EXECUTED', realClient: 'NOT_EXECUTED' };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const [command, argument] = process.argv.slice(2);
    if (command === 'capture' && argument) {
      const manifest = captureOracle(argument);
      console.log(JSON.stringify({ captured: manifest.records.filter(record => record.status === 'CAPTURED').length,
        total: manifest.records.length, failures: manifest.records.filter(record => record.status !== 'CAPTURED') }, null, 2));
      if (manifest.records.some(record => record.status !== 'CAPTURED')) process.exitCode = 1;
    } else if (command === 'compare') {
      const report = compareFixtures(argument);
      mkdirSync('build/sts1', { recursive: true });
      writeFileSync('build/sts1/map-diff.json', JSON.stringify(report, null, 2) + '\n');
      console.log(`StS1 A0 map golden parity ${report.status}: ${report.matches}/${report.requested}; full diff: build/sts1/map-diff.json`);
      for (const record of report.records) console.log(`${record.seed}: ${record.status}`);
      if (report.status !== 'PASS') process.exitCode = 1;
    } else if (command === 'properties' && argument) {
      const report = auditProjectSeeds(Number(argument));
      mkdirSync('build/sts1', { recursive: true });
      writeFileSync('build/sts1/map-properties.json', JSON.stringify(report, null, 2) + '\n');
      console.log(`StS1 A0 map properties ${report.status}: ${report.passed}/${report.executed} passed; ${report.executionErrors} execution errors`);
      if (report.status !== 'PASS') process.exitCode = 1;
    } else throw Error('Usage: node scripts/sts1-map-evidence.mjs capture <oracle-executable> | compare [fixture-directory] | properties <count>');
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}
