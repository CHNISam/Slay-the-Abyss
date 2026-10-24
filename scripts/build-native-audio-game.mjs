// Production audio entrypoint: build every module before enabling native BGM.
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve, join } from 'node:path';

const [base, output = '.artifacts/native-audio-game'] = process.argv.slice(2);
if (!base) throw new Error('Usage: npm run build:native -- <base.gil> [new-output-directory]');
const directory = resolve(output);
function run(script, args = []) {
  const result = spawnSync(process.execPath, [script, ...args], { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${script} failed (${result.status})`);
}
run('scripts/build-lua-data.mjs');
run('scripts/build-ui.mjs');
run('scripts/build-native-candidate.mjs', [resolve(base), join(directory, 'full')]);
const full = JSON.parse(readFileSync(join(directory, 'full/candidate.json'), 'utf8'));
run('scripts/build-native-bgm-candidate.mjs', [full.mapPath, join(directory, 'audio')]);
console.log(`Complete game with native music: ${join(directory, 'audio/candidate.json')}`);
