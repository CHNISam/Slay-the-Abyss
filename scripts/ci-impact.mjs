import { readFileSync, readdirSync, writeFileSync, appendFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { selectTests, parseGitChanges } from './test-affected.mjs';

export function impact(changed, sources, event, timings) {
  const full = reason => ({ mode: 'full', reason, changed, js: [], lua: [] });
  if (event.eventName !== 'pull_request' || event.base !== 'develop' || event.forceFull) return full('Integration, release or explicit full validation');
  if (!changed.length) return full('Empty comparison');
  // Documentation is not generally inert: evidence, design, source ledgers and
  // backlog are consumed by gates. Only this explicit prose allowlist is inert.
  const inert = p => /^docs\/(?:HANDOFF|CI|CI-FAST)\.md$/.test(p);
  const active = changed.filter(p => !inert(p));
  if (!active.length) return { mode: 'fast', reason: 'Prose only; governance gates still run', changed, js: [], lua: [] };
  // Economic, RNG, persistence and combat changes require the complete suite.
  if (active.some(p => /^(?:data\/|config\/|\.github\/|package|vendor\/)/.test(p)
    || /^src\/lua\/(?!abyss_(?:battle_ui|game_ui|map_ui|reward_ui|shop_ui|camp_ui)\.lua$)/.test(p))) return full('High risk or shared infrastructure');
  const plan = selectTests(active, sources);
  if (plan.full) return full(plan.reason);
  const js = [...new Set([...plan.fast, ...plan.integration])].sort(), lua = [...new Set(plan.lua)].sort();
  if (!js.length && !lua.length) return full('No proven test coverage');
  const estimate = js.reduce((n, p) => n + Math.max(timings.js.win32[p] ?? timings.unknownJsMs, timings.js.linux[p] ?? timings.unknownJsMs), 0)
    + lua.reduce((n, p) => n + (timings.lua[p] ?? timings.unknownLuaMs), 0);
  if (estimate > 180000) return full('Complete affected set exceeds fast execution budget');
  return { mode: 'fast', reason: plan.reason, changed, js, lua, estimateMs: estimate };
}

function scan(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? scan(`${dir}/${e.name}`) : [`${dir}/${e.name}`]);
}
export function main() {
  const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  let changed = [];
  if (process.env.GITHUB_EVENT_NAME === 'pull_request') {
    const base = event.pull_request.base.sha;
    if (!/^[a-f0-9]{40}$/.test(base)) throw new Error('Invalid base');
    const git = spawnSync('git', ['diff', '--name-status', '-z', '--find-renames', base, 'HEAD', '--'], { encoding: 'utf8' });
    if (git.status !== 0) throw new Error(git.stderr || 'Cannot compare exact base');
    changed = [...new Set(parseGitChanges(git.stdout))];
  }
  const sources = Object.fromEntries(['src/lua', 'scripts', 'tests'].flatMap(scan).filter(p => /\.(lua|mjs)$/.test(p)).map(p => [p, readFileSync(p, 'utf8')]));
  const plan = impact(changed, sources, { eventName: process.env.GITHUB_EVENT_NAME, base: event.pull_request?.base.ref,
    forceFull: event.pull_request?.labels?.some(l => l.name === 'ci:full') }, JSON.parse(readFileSync('scripts/ci-test-timings.json', 'utf8')));
  plan.sha = process.env.GITHUB_SHA;
  writeFileSync('ci-impact.json', JSON.stringify(plan, null, 2));
  appendFileSync(process.env.GITHUB_OUTPUT, `mode=${plan.mode}\n`);
  appendFileSync(process.env.GITHUB_STEP_SUMMARY, `CI plan: ${JSON.stringify(plan)}\n`);
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) main();
