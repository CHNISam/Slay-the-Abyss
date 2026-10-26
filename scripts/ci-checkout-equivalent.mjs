// Reviewed offline Linux equivalent of the pinned Windows checkout contract.
// This is not a PowerShell interpreter or evidence of Windows execution.
import { createHash } from 'node:crypto';
import { appendFileSync, readdirSync, statSync, realpathSync } from 'node:fs';
import { join, resolve, relative } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

// Script semantics are unchanged after PR215; hash only its PowerShell body,
// without the neighboring YAML comments formerly captured by the regression.
const reviewedContract = '19aa856fe5024090182abbff487b334eb9d48cc63dc31a1f4caa940930f90c51';
export function checkoutPlan(script) {
  const preserve = script.includes('git update-ref refs/ci/previous $previousHead');
  const current = script.includes('"+${env:CI_SHA}:refs/ci/current"');
  const cap = script.includes('$receivedPackBytes -gt 1KB') ? 1024 : 128 * 1024 ** 2;
  // Only the existing regression's explicit mutations are accepted. Any other
  // workflow edit requires reviewing this adapter, rather than silently passing
  // a Linux model which no longer describes the production Windows program.
  const canonical = script.replace('# No advancing reference (regression)', 'git update-ref refs/ci/previous $previousHead')
    .replace('origin $env:CI_SHA', 'origin "+${env:CI_SHA}:refs/ci/current"')
    .replace('git checkout --force --detach FETCH_HEAD', 'git checkout --force --detach refs/ci/current')
    .replace('$receivedPackBytes -gt 1KB', '$receivedPackBytes -gt 128MB');
  if (createHash('sha256').update(canonical).digest('hex') !== reviewedContract)
    throw new Error('Unreviewed Windows checkout contract: review Linux equivalence before accepting this workflow change');
  const checkout = script.includes('git checkout --force --detach refs/ci/current');
  if (current !== checkout) throw new Error('Inconsistent checkout reference contract');
  return { preserve, current, cap };
}

export function equivalentCheckout({ script, cwd, remote, sha, summary }) {
  const plan = checkoutPlan(script);
  // Destructive checkout/clean are confined to the regression's own temp trees.
  const directory = realpathSync(cwd), temp = realpathSync(tmpdir());
  const inside = relative(temp, directory);
  if (inside.startsWith('..') || !inside.split(/[\\/]/)[0].startsWith('abyss-ci-downloads-'))
    throw new Error('Equivalent checkout requires its isolated regression temp directory');
  if (!remote.startsWith('file:') || !/^[0-9a-f]{40}$/.test(sha)) throw new Error('Only offline file transport and exact SHA are supported');
  const env = { ...process.env };
  // No credentials are needed by the offline oracle. Preserve inherited config
  // for unrelated processes; do not overwrite their authentication or globals.
  for (const key of Object.keys(env)) if (/^GIT_CONFIG_(COUNT|KEY_\d+|VALUE_\d+)$/.test(key) || key === 'CI_TOKEN') delete env[key];
  const git = (...args) => {
    const r = spawnSync('git', args, { cwd: directory, env, encoding: 'utf8', timeout: 30000 });
    if (r.error || r.status !== 0) throw new Error(`Git ${args[0]} failed: ${r.error?.message || r.stderr}`);
    return r.stdout.trim();
  };
  git('init', '.');
  git('remote', ...((git('remote').split('\n').includes('origin')) ? ['set-url'] : ['add']), 'origin', remote);
  const previous = spawnSync('git', ['rev-parse', '--verify', '--quiet', 'HEAD'], { cwd: directory, env, encoding: 'utf8' });
  if (previous.status === 0 && plan.preserve) git('update-ref', 'refs/ci/previous', previous.stdout.trim());
  const bytes = () => readdirSync(join(directory, '.git/objects/pack')).filter(name => name.endsWith('.pack'))
    .reduce((sum, name) => sum + statSync(join(directory, '.git/objects/pack', name)).size, 0);
  const before = bytes();
  git('-c', 'credential.helper=', '-c', 'fetch.unpackLimit=1', 'fetch', '--no-auto-maintenance', '--force', '--no-tags',
    'origin', plan.current ? `+${sha}:refs/ci/current` : sha);
  const received = bytes() - before;
  const message = `Checkout new Git pack payload: ${received} bytes`;
  process.stdout.write(message + '\n');
  if (summary) appendFileSync(summary, message + '\n');
  if (received < 0) throw new Error('Git pack accounting changed unexpectedly');
  if (received > plan.cap) throw new Error('Checkout exceeded size limit; investigate before retrying');
  if (received > 32 * 1024 ** 2) process.stdout.write('::warning::Checkout received over 32 MiB\n');
  git('checkout', '--force', '--detach', plan.current ? 'refs/ci/current' : 'FETCH_HEAD');
  if (git('rev-parse', 'HEAD') !== sha) throw new Error('Revision mismatch');
  git('clean', '-ffd');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { equivalentCheckout(JSON.parse(process.argv[2])); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
