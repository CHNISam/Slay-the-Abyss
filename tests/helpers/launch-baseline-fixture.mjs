import {materializeBeforeDelivery} from './delivery-source-composition.mjs';
import {pathToFileURL} from 'node:url';
import {fileURLToPath} from 'node:url';
import {withHistoricalBaseline, loadHistoricalBaselineInputs} from './historical-baseline-inputs.mjs';
import { after } from 'node:test';
import { readFileSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, existsSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { relicCompletionInverse, requireRelicCompletionSource, preRelicCompletionSource } from './relic-completion-inverse.mjs';

// Frozen launch-ledger tests replay their whole matching source/data layer.
// Current relic feature tests continue to use production without projection.
export function launchBaselineFixture() {
  const root = mkdtempSync(join(tmpdir(), 'abyss-launch-baseline-'));
  after(() => rmSync(root, { recursive: true, force: true }));
  const implementationRoot=fileURLToPath(new URL('../..',import.meta.url));
  // The launch ledger is a frozen replay. Execute today's inverse helpers on
  // the registered original inputs, while current launch acceptance stays live.
  return withHistoricalBaseline(()=>{
  // These are the exact original bytes already mounted in the source root.
  // Materialize them directly: recursive cp performs stat/chmod work for each
  // of 1,779 files on Windows before the unchanged Sapphire deadline can run.
  // Every invocation still validates the full archive and writes private files.
  const directories = new Set();
  for (const [path, bytes] of Object.entries(loadHistoricalBaselineInputs())) {
    if (!/^(?:data|src|scripts|config|tools|tests\/lua)\//.test(path)) continue;
    const target = join(root, path), directory = dirname(target);
    if (!directories.has(directory)) { mkdirSync(directory, { recursive: true }); directories.add(directory); }
    writeFileSync(target, bytes);
  }
  for (const directory of ['tests/helpers', 'tests/fixtures', 'docs', 'node_modules'])
    symlinkSync(resolve(implementationRoot,directory), join(root, directory), 'junction');
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
  });
}

// The validator constants and Lua probe must come from the same historical root.
export async function loadLaunchBaselineValidator(root){return import(pathToFileURL(join(root,'scripts/verify-launch-content.mjs')).href);}
