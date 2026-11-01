import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const args = process.argv.slice(2);
const option = (name, fallback) => args.find(arg => arg.startsWith(`--${name}=`))?.slice(name.length + 3) ?? fallback;
const seeds = option('seeds', '42,36,1,2,3').split(',').map(Number);
const stopAfter = Number(option('stop-after', '17'));
if (!seeds.length || seeds.some(seed => !Number.isSafeInteger(seed)) || !Number.isInteger(stopAfter) || stopAfter < 1 || stopAfter > 17) {
  throw new Error('Use integer --seeds=42,36 and --stop-after=1..17');
}
const output = resolve(option('output', '.artifacts/m2-resource/evidence.json'));
const cli = createRequire(import.meta.url).resolve('fengari-node-cli/src/lua-cli.js');
const result = spawnSync(process.execPath, [cli, '-e', `M2_SEEDS={${seeds.join(',')}};M2_STOP_AFTER=${stopAfter};dofile('scripts/m2-resource-audit.lua')`], {
  cwd: process.cwd(), encoding: 'utf8', timeout: 300000, maxBuffer: 32 * 1024 * 1024,
});
if (result.error) throw result.error;
process.stderr.write(result.stderr ?? '');
const lines = (result.stdout ?? '').split(/\r?\n/);
for (const line of lines.filter(line => !line.startsWith('M2_EVIDENCE_JSON '))) if (line) console.log(line);
if (result.status !== 0) process.exit(result.status ?? 1);
const json = lines.find(line => line.startsWith('M2_EVIDENCE_JSON '));
if (!json) throw new Error('No completed evidence report returned');
const report = JSON.parse(json.slice('M2_EVIDENCE_JSON '.length));
const git = (...gitArgs) => {
  const child = spawnSync('git', gitArgs, { encoding: 'utf8' });
  if (child.error || child.status !== 0) throw child.error ?? new Error(child.stderr);
  return child.stdout.trim();
};
const sha256 = value => createHash('sha256').update(value).digest('hex');
report.source = { sha: git('rev-parse', 'HEAD'), dirty: git('status', '--porcelain'), files: {} };
for (const dir of ['src/lua', 'data']) for (const file of readdirSync(dir).filter(file => /\.(lua|json)$/.test(file))) {
  report.source.files[`${dir}/${file}`] = sha256(readFileSync(`${dir}/${file}`));
}
for (const file of ['data/presentation/ui_theme.json', 'scripts/m2-autoplay-policy.lua',
  'scripts/m2-resource-audit.lua', 'scripts/m2-resource-evidence.mjs']) {
  report.source.files[file] = sha256(readFileSync(file));
}
report.executedAt = new Date().toISOString();
report.command = `node scripts/m2-resource-evidence.mjs ${args.join(' ')}`.trim();
mkdirSync(dirname(output), { recursive: true });
writeFileSync(output, `${JSON.stringify(report, null, 2)}\n`);
console.log(`Evidence: ${output}`);
console.log(`SHA256: ${sha256(readFileSync(output))}`);
