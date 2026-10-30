import {materializeBeforeM3Events,m3EventSourceLayer} from './m3-event-source-inverse.mjs';
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
  for (const directory of ['data', 'src', 'scripts', 'config'])
    cpSync(directory, join(root, directory), { recursive: true });
  for (const directory of ['tests', 'tools', 'docs'])
    symlinkSync(resolve(directory), join(root, directory), 'junction');
  const outputs=[];
  for (const path of Object.keys(relicCompletionInverse.files)
    .filter(path => /^(data|src|scripts|config)\//.test(path))) {
    const target = join(root, path);
    const current = existsSync(target) ? readFileSync(target, 'utf8') : null;
    requireRelicCompletionSource(path, current);
    const previous = preRelicCompletionSource(path, current);
    outputs.push([target,previous]);
  }
  materializeBeforeM3Events(root,{historicalPaths:Object.keys(relicCompletionInverse.files).filter(path=>m3EventSourceLayer.files[path]?.beforeSha256!=null)});
  for(const [target,previous]of outputs){if(previous===null)rmSync(target);else writeFileSync(target,previous);}
  return root;
}
