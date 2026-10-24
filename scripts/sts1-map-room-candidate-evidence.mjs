import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, relative, isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';
import { toLua } from './build-lua-data.mjs';
import { runLua } from './test-lua.mjs';
import { compareFixtures, exportProjectMaps, mapInvariants, requestedSeeds } from './sts1-map-evidence.mjs';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
export function exportRoomCandidateMaps(seeds) {
  const staging = mkdtempSync(join(tmpdir(), 'abyss-room-export-'));
  try {
    const file = join(staging, 'export.lua');
    writeFileSync(file, `local C=dofile('tools/candidates/sts1_map_rooms.lua')
local function json(v)
 if type(v)=='string' then return string.format('%q',v) end
 if type(v)=='number' then return tostring(v) end
 local array=true;for k in pairs(v) do if type(k)~='number' then array=false end end
 local items={}
 if array then for _,item in ipairs(v) do items[#items+1]=json(item) end
 else for k,item in pairs(v) do items[#items+1]=json(k)..':'..json(item) end end
 return (array and '[' or '{')..table.concat(items,',')..(array and ']' or '}')
end
for _,seed in ipairs(${toLua(seeds)}) do
 local m=C.generate(seed)
 print(json({seed=seed,mapSeed=m.mapSeed,graph={nodes=m.nodes,edges=m.edges},topologyState=m.topologyState,
 randomState=m.randomState,quotaCount=m.quotaCount,quotas=m.quotas,unassignedCount=m.unassignedCount,
 poolBeforeShuffle=m.poolBeforeShuffle,poolAfterShuffle=m.poolAfterShuffle,remainingRooms=m.remainingRooms,fallbackCount=m.fallbackCount}))
end`);
    const result = runLua(file);
    if (result.status !== 0) throw Error(result.stderr || result.stdout);
    const records = result.stdout.trim().split(/\r?\n/).map(line => JSON.parse(line));
    if (records.length !== seeds.length || records.some((record, i) => record.seed !== seeds[i])) throw Error('Incomplete, extra or reordered candidate maps');
    return records.map(record => ({ ...record, status: 'EXPORTED' }));
  } finally {
    const inside = relative(resolve(tmpdir()), resolve(staging));
    if (isAbsolute(inside) || inside.startsWith('..') || !inside.startsWith('abyss-room-export-')) throw Error('Unsafe temporary cleanup path');
    rmSync(staging, { recursive: true, force: true });
  }
}

export function roomCandidateEvidence(directory, count = 128) {
  if (!Number.isInteger(count) || count < 1 || count > 10000) throw Error('Invalid structural sample size');
  mkdirSync(directory, { recursive: true });
  const seeds = requestedSeeds(), records = exportRoomCandidateMaps(seeds);
  for (const record of records) writeFileSync(join(directory, `candidate-${record.seed}.json`), JSON.stringify(record, null, 2) + '\n');
  const bySeed = new Map(records.map(record => [record.seed, record]));
  const golden = compareFixtures(undefined, seed => bySeed.get(seed));
  const properties = { status: 'PASS', requested: count, executed: 0, passed: 0, failed: 0, executionErrors: 0, examples: [],
    scope: 'Structural invariants only; not quota/algorithm parity or platform evidence.' };
  for (let start = 0; start < count; start += 16) {
    const inputs = Array.from({ length: Math.min(16, count - start) }, (_, i) => String(start + i));
    let outputs;
    try { outputs = exportRoomCandidateMaps(inputs); }
    catch (error) {
      properties.status = 'FAIL'; properties.executionErrors += inputs.length;
      properties.examples.push({ start, error: error.message }); continue;
    }
    for (const record of outputs) {
      const errors = mapInvariants(record.graph); properties.executed++;
      if (errors.length) {
        properties.status = 'FAIL'; properties.failed++;
        if (properties.examples.length < 10) properties.examples.push({ seed: record.seed, errors });
      } else properties.passed++;
    }
    process.stderr.write(`Room candidate structural seeds: ${properties.executed}/${count}\n`);
  }
  const productionRecords = exportProjectMaps(seeds), productionBySeed = new Map(productionRecords.map(record => [record.seed, record]));
  const productionGolden = compareFixtures(undefined, seed => productionBySeed.get(seed));
  writeFileSync(join(directory, 'production-full-map-diff.json'), JSON.stringify(productionGolden, null, 2) + '\n');
  const files = ['tools/candidates/sts1_map_rooms.lua', 'tools/candidates/sts1_map_topology.lua', 'tools/candidates/sts_random.lua',
    'tools/candidates/libgdx_randomxs128.lua', 'tests/sts1-map-room-candidate.test.mjs', 'tests/fixtures/sts1/maps/manifest.json'];
  const report = { scope: 'ISOLATED_A0_ACT1_COMPLETE_GENERATED_MAP_COORDINATES_EDGES_ROOMS',
    status: golden.status === 'PASS' && properties.status === 'PASS' ? 'PASS' : 'FAIL',
    candidateGolden: golden, candidateProperties: properties,
    productionGolden: { status: productionGolden.status, matches: productionGolden.matches, requested: productionGolden.requested,
      statuses: productionGolden.records.map(({ seed, status }) => ({ seed, status })), fullDiff: 'production-full-map-diff.json' },
    inputs: files.map(file => ({ file, sha256: hash(readFileSync(file)) })),
    candidateRecords: records.map(record => ({ seed: record.seed, quotaCount: record.quotaCount, quotas: record.quotas,
      nodes: record.graph.nodes.length, edges: record.graph.edges.length, topologyState: record.topologyState,
      randomState: record.randomState, fallbackCount: record.fallbackCount,
      outputSha256: hash(readFileSync(join(directory, `candidate-${record.seed}.json`))) })),
    targetPcBinary: 'NOT_AUTHENTICATED', compiled: 'NOT_EXECUTED', saveImport: 'NOT_EXECUTED', realClient: 'NOT_EXECUTED',
    caveat: 'Unchanged third-party captured golden is not original-game verification. Production remains a separate failing comparison.' };
  writeFileSync(join(directory, 'report.json'), JSON.stringify(report, null, 2) + '\n');
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const report = roomCandidateEvidence(process.argv[2] ?? 'build/sts1/room-candidate');
  console.log(`Candidate full golden ${report.candidateGolden.status} ${report.candidateGolden.matches}/${report.candidateGolden.requested}; structural ${report.candidateProperties.passed}/${report.candidateProperties.requested}; production ${report.productionGolden.status} ${report.productionGolden.matches}/${report.productionGolden.requested}`);
  if (report.status !== 'PASS') process.exitCode = 1;
}
