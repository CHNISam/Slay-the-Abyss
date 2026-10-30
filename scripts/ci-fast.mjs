import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { prepareReviewedAssets, prepareRuntimePreviews, needsRuntimePreviews } from './ci-reviewed-lfs.mjs';

const plan = JSON.parse(readFileSync('ci-impact.json', 'utf8'));
if (plan.mode !== 'fast' || plan.sha !== process.env.GITHUB_SHA) throw new Error('Invalid impact plan identity');
const files = [...plan.js, ...plan.lua];
if (new Set(files).size !== files.length || files.some(p => !/^tests\/(?:[^/]+\.test\.mjs|lua\/[^/]+\.lua)$/.test(p))) throw new Error('Invalid test paths');
function run(args) {
  const r = spawnSync(process.execPath, args, { stdio: 'inherit', windowsHide: true });
  if (r.error || r.status !== 0) throw r.error ?? new Error(`Failed ${JSON.stringify(args)}: ${r.status ?? r.signal}`);
}
if (plan.js.includes('tests/reviewed-traveler-geo-assets.test.mjs')) prepareReviewedAssets();
prepareRuntimePreviews({ needed: needsRuntimePreviews(plan.js) });
if (files.length) {
  for (const script of ['build-lua-data', 'build-ui', 'map-ui-layout']) run([`scripts/${script}.mjs`]);
  if (plan.js.length) run(['--test', '--test-concurrency=1', ...plan.js]);
  for (const file of plan.lua) run(['scripts/test-lua.mjs', file]);
}
console.log(`Complete affected set passed: ${plan.js.length} JS, ${plan.lua.length} Lua. ${plan.reason}`);
