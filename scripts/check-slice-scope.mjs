// Opt-in, zero-model-cost write-set guard for isolated `slice/<lane>/<slug>` PRs.
// Keep the pilot deliberately narrow; other PRs retain their existing checks.
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const lanes = Object.freeze({
  'actor-damage': Object.freeze([
    'src/lua/abyss_actor.lua',
    'tests/actor-damage-pipeline.test.mjs',
    'tests/lua/actor_damage_pipeline.lua',
    'tests/helpers/actor-damage-parity.mjs',
    'tests/helpers/actor-damage-trace.lua',
  ]),
  'battle-hotpath': Object.freeze([
    'src/lua/abyss_battle_card_view.lua',
    'src/lua/abyss_battle_potion_bindings.lua',
    'tests/runtime-ui-hotpaths.test.mjs',
    'tests/lua/hand_geometry_cache.lua',
    'tests/lua/potion_drag_hotpath.lua',
    'tests/lua/runtime_ui_hotpaths.lua',
  ]),
  'ci-cost': Object.freeze([
    'scripts/ci-run-costs.mjs',
    'tests/ci-run-costs.test.mjs',
  ]),
});

export function checkPolicy(policy = lanes) {
  const owners = new Map();
  const errors = [];
  for (const [lane, paths] of Object.entries(policy)) {
    if (!/^[a-z0-9-]+$/.test(lane) || !paths?.length) errors.push(`invalid or empty lane: ${lane}`);
    for (const path of paths || []) {
      if (!path || path.startsWith('/') || path.includes('\\') || path.split('/').some(part => !part || part === '.' || part === '..')) {
        errors.push(`invalid path in ${lane}: ${path}`);
        continue;
      }
      if (owners.has(path)) errors.push(`${path}: owned by both ${owners.get(path)} and ${lane}`);
      owners.set(path, lane);
    }
  }
  return errors;
}

export function auditSlice(branch, touchedPaths, policy = lanes) {
  if (!branch.startsWith('slice/')) return { decision: 'SKIP', lane: null, errors: [] };
  const match = /^slice\/([a-z0-9-]+)\/([a-z0-9][a-z0-9._-]*)$/.exec(branch);
  if (!match) return { decision: 'HOLD', lane: null, errors: ['invalid slice branch; expected slice/<lane>/<slug>'] };
  const lane = match[1], allowed = policy[lane];
  if (!allowed) return { decision: 'HOLD', lane, errors: [`unknown lane: ${lane}`] };
  const valid = new Set(allowed);
  const errors = [...new Set(touchedPaths)].filter(p => !valid.has(p)).map(p => `${p}: outside ${lane} write scope`);
  if (!touchedPaths.length) errors.push('empty change set');
  return { decision: errors.length ? 'HOLD' : 'PASS', lane, errors };
}

// -z preserves tabs, newlines and unicode file names. Renames/copies check both
// source and destination paths, not only the destination of a move.
export function parseChangedPaths(raw) {
  const fields = raw.split('\0');
  if (fields.at(-1) === '') fields.pop();
  const changed = [];
  for (let i = 0; i < fields.length;) {
    const status = fields[i++];
    if (!/^(?:[ACDMRTUXB]|[RC][0-9]+)$/.test(status)) throw new Error(`invalid diff status ${JSON.stringify(status)}`);
    const count = status[0] === 'R' || status[0] === 'C' ? 2 : 1;
    if (i + count > fields.length) throw new Error('incomplete git name-status record');
    for (let j = 0; j < count; j++) {
      const path = fields[i++];
      if (!path) throw new Error('empty git path');
      changed.push(path);
    }
  }
  return changed;
}

export function run({branch,base,git = execFileSync}) {
  const policyErrors = checkPolicy();
  if (policyErrors.length) throw new Error(policyErrors.join('\n'));
  if (!branch.startsWith('slice/')) return auditSlice(branch, []);
  if (!/^[a-f0-9]{40}$/.test(base || '')) throw new Error('SLICE_BASE_SHA must be an exact 40-character commit SHA');
  const raw = git('git', ['diff', '--no-ext-diff', '--name-status', '-z', '--find-renames', base, 'HEAD'], {encoding:'utf8'});
  return auditSlice(branch, parseChangedPaths(raw));
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const result = run({branch:process.env.GITHUB_HEAD_REF || '',base:process.env.SLICE_BASE_SHA});
    console.log(`[slice-scope] ${result.decision}${result.lane ? ' '+result.lane : ''}`);
    for (const error of result.errors) console.error(`[slice-scope] ${error}`);
    if (result.decision === 'HOLD') process.exitCode = 1;
  } catch (error) {
    console.error(`[slice-scope] ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
