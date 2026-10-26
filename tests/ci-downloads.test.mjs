import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { randomBytes } from 'node:crypto';
import { checkNetworkPolicy } from '../scripts/check-network-policy.mjs';

const workflow = readFileSync('.github/workflows/quality.yml', 'utf8');
const checkout = workflow.match(/      - name: Check out exact revision[^\n]*\r?\n[\s\S]*?        run: \|\r?\n([\s\S]*?)(?=\r?\n      - )/)[1].split(/\r?\n/).map(line => line.replace(/^          /, '')).join('\n');
function git(cwd, ...args) {
  const r = spawnSync('git', args, { cwd, encoding: 'utf8', windowsHide: true });
  assert.equal(r.status, 0, r.stderr); return r.stdout.trim();
}
test('real workflow checkout transfers only the follow-up delta; old-ref negative control retransfers and size gate fails', t => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-ci-downloads-'));
  t.after(() => {
    assert.ok(resolve(root).startsWith(resolve(tmpdir()) + (process.platform === 'win32' ? '\\' : '/')));
    assert.match(root, /abyss-ci-downloads-/); rmSync(root, { recursive: true, force: true });
  });
  const source = join(root, 'source'); mkdirSync(source); git(source, 'init');
  git(source, 'config', 'user.name', 'CI download test'); git(source, 'config', 'user.email', 'test@example.invalid');
  writeFileSync(join(source, 'base.txt'), 'base'); git(source, 'add', '.'); git(source, 'commit', '-m', 'base');
  const base = git(source, 'rev-parse', 'HEAD'), remote = pathToFileURL(source).href;
  function client(name) {
    const dir = join(root, name); mkdirSync(dir); git(dir, 'init');
    git(dir, 'config', 'gc.auto', '0'); git(dir, 'config', 'maintenance.auto', 'false');
    git(dir, 'fetch', '--no-tags', remote, base); git(dir, 'checkout', '--detach', 'FETCH_HEAD');
    git(dir, 'update-ref', 'refs/remotes/pull/4/merge', base); return dir;
  }
  const fixed = client('fixed'), broken = client('broken'), capped = client('capped');
  function run(dir, sha, script = checkout) {
    const file = join(root, 'checkout.ps1');
    // Only replace transport: execute the actual production PowerShell body offline.
    // Windows TEMP can be ADMINI~1; GitHub supplies a canonical workspace path.
    writeFileSync(file, 'Set-Location -LiteralPath $env:GITHUB_WORKSPACE\n$env:GITHUB_WORKSPACE = (Get-Location).Path\n' + script.replaceAll('https://github.com/$env:CI_REPOSITORY.git', remote));
    const r = spawnSync(process.platform === 'win32' ? 'powershell.exe' : 'pwsh', ['-NoProfile', '-File', file], {
      cwd: dir, encoding: 'utf8', windowsHide: true,
      env: { ...process.env, CI_TOKEN: 'offline-test-only', CI_SHA: sha, CI_REPOSITORY: 'CHNISam/Slay-the-Abyss', GITHUB_WORKSPACE: dir, GITHUB_STEP_SUMMARY: join(root, 'summary.md') }
    });
    return { ...r, payload: Number(r.stdout?.match(/Checkout new Git pack payload: (\d+) bytes/)?.[1]) };
  }
  const old = checkout.replace('git update-ref refs/ci/previous $previousHead', '# No advancing reference (regression)')
    .replace('"+${env:CI_SHA}:refs/ci/current"', '$env:CI_SHA').replace('git checkout --force --detach refs/ci/current', 'git checkout --force --detach FETCH_HEAD');
  writeFileSync(join(source, 'large.bin'), randomBytes(256 * 1024)); git(source, 'add', '.'); git(source, 'commit', '-m', 'large');
  let sha = git(source, 'rev-parse', 'HEAD');
  const first = run(fixed, sha); assert.equal(first.status, 0, first.stderr); assert.ok(first.payload > 250000);
  assert.equal(run(broken, sha, old).status, 0);
  const tooLarge = run(capped, sha, checkout.replace('$receivedPackBytes -gt 128MB', '$receivedPackBytes -gt 1KB'));
  assert.notEqual(tooLarge.status, 0); assert.match(tooLarge.stderr, /exceeded/);
  writeFileSync(join(source, 'tiny.txt'), 'tiny follow-up'); git(source, 'add', '.'); git(source, 'commit', '-m', 'tiny'); sha = git(source, 'rev-parse', 'HEAD');
  const next = run(fixed, sha); assert.equal(next.status, 0, next.stderr); assert.ok(next.payload < 8192, `new pack: ${next.payload}`);
  assert.equal(git(fixed, 'rev-parse', 'HEAD'), sha); assert.equal(git(fixed, 'rev-parse', 'refs/ci/current'), sha);
  git(fixed, 'diff', '--check', base, 'HEAD');
  const repeated = run(broken, sha, old); assert.equal(repeated.status, 0, repeated.stderr); assert.ok(repeated.payload > 250000, 'old workflow repeats the large object');
  assert.match(readFileSync(join(root, 'summary.md'), 'utf8'), /Checkout new Git pack payload:/);
  console.log(`Git regression: first=${first.payload}B, follow-up=${next.payload}B, old-flow follow-up=${repeated.payload}B`);
});
test('lightweight engineering check catches old refs, removed size guard and unlimited dependency retry', () => {
  assert.deepEqual(checkNetworkPolicy(workflow), []);
  assert.ok(checkNetworkPolicy(workflow.replace('git update-ref refs/ci/previous', 'git remote remove origin')).length);
  assert.ok(checkNetworkPolicy(workflow.replace('$receivedPackBytes -gt 128MB', '$receivedPackBytes -gt 999GB')).length);
  assert.ok(checkNetworkPolicy(workflow.replace('--fetch-retries=0', '--fetch-retries=99')).length);
});
