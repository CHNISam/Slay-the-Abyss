import {materializeBeforeDelivery} from './delivery-source-composition.mjs';
import {pathToFileURL} from 'node:url';
import { after } from 'node:test';
import { readFileSync, cpSync, mkdtempSync, rmSync, symlinkSync, existsSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { relicCompletionInverse, requireRelicCompletionSource, preRelicCompletionSource } from './relic-completion-inverse.mjs';

// Frozen launch-ledger tests replay their whole matching source/data layer.
// Current relic feature tests continue to use production without projection.
export function launchBaselineFixture() {
  const root = mkdtempSync(join(tmpdir(), 'abyss-launch-baseline-'));
  after(() => rmSync(root, { recursive: true, force: true }));
  for (const directory of ['data', 'src', 'scripts', 'config', 'tools'])
    cpSync(directory, join(root, directory), { recursive: true });
  for (const directory of ['tests', 'docs', 'node_modules'])
    symlinkSync(resolve(directory), join(root, directory), 'junction');
  materializeBeforeDelivery(root);
  const validatorPath=join(root,'scripts/verify-launch-content.mjs');
  const validatorSource=readFileSync(validatorPath,'utf8');
  for (const path of Object.keys(relicCompletionInverse.files)
    .filter(path => /^(data|src|scripts|config)\//.test(path))) {
    const target = join(root, path);
    const current = existsSync(target) ? readFileSync(target, 'utf8') : null;
    requireRelicCompletionSource(path, current);
    const previous = preRelicCompletionSource(path, current);
    if (previous === null) rmSync(target);
    else writeFileSync(target, previous);
  }
  // Preserve the exact outer-base validator and its current packaging contract.
  writeFileSync(validatorPath,validatorSource);
  return root;
}

// The validator constants and Lua probe must come from the same historical root.
export async function loadLaunchBaselineValidator(root){return import(pathToFileURL(join(root,'scripts/verify-launch-content.mjs')).href);}
