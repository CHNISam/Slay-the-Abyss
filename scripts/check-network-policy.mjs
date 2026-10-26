import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export function checkNetworkPolicy(text) {
  const check = (text + '\n  end-of-workflow:\n').match(/\n  rules:\r?\n([\s\S]*?)(?=\r?\n  [\w-]+:)/)?.[1];
  if (!check) return ['Quality/rules missing'];
  const errors = [];
  if (/git remote remove origin|actions\/cache(?:@|\/)/.test(check)) errors.push('Local CI must preserve Git refs and avoid remote dependency cache downloads');
  for (const required of ['git update-ref refs/ci/previous', '+${env:CI_SHA}:refs/ci/current', '--no-auto-maintenance', 'git checkout --force --detach refs/ci/current', '$receivedPackBytes -gt 128MB', '$env:GITHUB_STEP_SUMMARY', 'npm run check:network']) if (!check.includes(required)) errors.push(`Missing CI download safeguard: ${required}`);
  for (const required of ['CI_REF: ${{ github.ref }}', 'git check-ref-format $env:CI_REF', "'\\A[0-9a-fA-F]{40}\\z'", "'^refs/((heads|tags)/.+|pull/[1-9][0-9]*/merge)$'", "'refs/ci/quality-tips/'", '[Security.Cryptography.SHA256]::Create()', 'git update-ref --no-deref $checkoutRef refs/ci/current', '$maxCheckoutTips = 64', "--format='%(refname)' refs/ci/quality-tips/", "Where-Object { $_ -cmatch '^refs/ci/quality-tips/[0-9a-f]{64}$' -and $_ -cne $checkoutRef }", 'Select-Object -Skip ($maxCheckoutTips - 1)', 'git update-ref --no-deref -d $staleRef']) if (!check.includes(required)) errors.push(`Missing bounded per-branch checkout safeguard: ${required}`);
  const installs = check.match(/npm ci[^\r\n]*/g) || [];
  if (!installs.length || installs.some(line => ['--prefer-offline', '--no-audit', '--fetch-retries=0', '--fetch-timeout=30000'].some(flag => !line.includes(flag)))) errors.push('npm CI downloads must prefer cache and use bounded retries/timeouts');
  return errors;
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const errors = checkNetworkPolicy(readFileSync(new URL('../.github/workflows/quality.yml', import.meta.url), 'utf8'));
  if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
  else console.log('CI download safeguards verified: incremental Git refs, size summary/limit, bounded npm retries');
}
