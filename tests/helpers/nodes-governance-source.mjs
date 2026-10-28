import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read = file => readFileSync(`src/lua/${file}.lua`, 'utf8').replaceAll('\r\n', '\n');
export function nodesGovernanceSources() {
  return {main:read('abyss_nodes'), entry:read('abyss_nodes_entry')};
}

function replaceOnce(source, before, after) {
  assert.equal(source.split(before).length - 1, 1, `one reviewed extraction: ${before}`);
  return source.replace(before, after);
}

// Reassemble only the reviewed extraction seams. The original frozen hashes
// remain the oracle, and the bodies below always come from the live modules.
export function nodesGovernanceWitness({main, entry} = nodesGovernanceSources()) {
  entry = entry.replace(/^ {4}/gm, '');
  const bossStart = 'local function prepareBossReward(run,flow,random)\n';
  const bossEnd = '\nend\n\nlocal function prepare(run, node, miscRng)';
  const start = entry.indexOf(bossStart), end = entry.indexOf(bossEnd, start);
  assert.ok(start >= 0 && end > start, 'bounded live Boss preparation helper');
  const body = entry.slice(start + bossStart.length, end).split('\n').map(line => '    ' + line).join('\n');
  entry = replaceOnce(entry,
    '    elseif node.roomKind == "boss_treasure" then\n        prepareBossReward(run,flow,random)\n',
    '    elseif node.roomKind == "boss_treasure" then\n' + body + '\n');

  const claimStart = 'local function claimSourceBossRelic(run,flow,choice)\n';
  const claimEnd = '    return true\nend\n';
  const claimAt = main.indexOf(claimStart), claimLast = main.indexOf(claimEnd, claimAt);
  assert.ok(claimAt >= 0 && claimLast > claimAt, 'bounded live source chest helper');
  main = replaceOnce(main,
    '    if flow.chest then\n        local ok,why=claimSourceBossRelic(run,flow,choice);if not ok then return false,why end\n',
    '    if flow.chest then\n' + main.slice(claimAt + claimStart.length, claimLast));
  main = replaceOnce(main, "require('abyss_nodes_events')(M)", 'function M.eventOptions(run,flow)');
  return main + '\n' + entry;
}
