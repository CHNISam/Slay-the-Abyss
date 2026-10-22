import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

function check(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) check(path);
    else if (/\.[cm]?js$/.test(entry.name)) {
      const result = spawnSync(process.execPath, ['--check', path], { encoding: 'utf8', timeout: 10000 });
      if (result.status !== 0) throw new Error(result.stderr || result.error?.message || `Syntax check failed: ${path}`);
    }
  }
}
for (const directory of ['scripts', 'tests']) check(directory);
console.log('JavaScript syntax checks passed.');
