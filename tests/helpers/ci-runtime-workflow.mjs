import { readFileSync } from 'node:fs';
// Invert only the reviewed executor substitutions; retain the original workflow
// hash guards for every gate, permission, deadline, matrix and artifact field.
import { beforeQualityArtifacts } from './quality-workflow.mjs';
export function originalWorkflow(text) {
  text = beforeQualityArtifacts(text);
  // Only the two reviewed, shell-only summaries changed runner image. Keep all
  // their other bytes visible to the original routing and workflow hash guards.
  for (const name of ['check', 'engineering-posix']) {
    const jobs = [...text.matchAll(new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [\\w-]+:|(?![\\s\\S]))`, 'gm'))];
    const body = jobs[0]?.[1];
    if (jobs.length !== 1 || (body.match(/^    runs-on:/gm) ?? []).length !== 1
      || !/^    runs-on: ubuntu-slim$/m.test(body)) throw new Error('CI summary runner migration mismatch');
    text = text.replace(body, body.replace('    runs-on: ubuntu-slim\n', '    runs-on: ubuntu-24.04\n'));
  }
  // Invert only the added guidance gate; its placement is tested separately.
  text = text.replace('      - name: Validate concise agent entry points\n        run: npm run check:guidance\n', '');
  // Invert exact reviewed routing edits only. Existing full-suite hashes still
  // protect all assertions, commands, matrices and deadlines under the route.
  for (const edit of JSON.parse(readFileSync('tests/helpers/ci-fast-migration.json', 'utf8')).reverse()) {
    if (!edit.after || text.split(edit.after).length !== 2) throw new Error('CI routing migration mismatch');
    text = text.replace(edit.after, edit.before);
  }
  return text.replace(`      - name: Check feature branch history\n        if: github.event_name == 'pull_request' && matrix.shard == 1\n        env:\n          GITHUB_TOKEN: \${{ github.token }}\n        run: node scripts/check-pr-history.mjs\n`, '')
    .replace(" --workers ${{ inputs.runner_pool == 'local-special' && 1 || 2 }}", '')
    .replaceAll('node scripts/ci-shards.mjs --prepare=', 'node scripts/ci-reviewed-lfs.mjs --shard=')
    .replaceAll('node scripts/ci-shards.mjs --shard=${{ matrix.shard }}/${{ strategy.job-total }}',
      'node --test --test-concurrency=1 --test-shard=${{ matrix.shard }}/${{ strategy.job-total }} tests/*.test.mjs')
    .replace('# All test files are partitioned by measured file weights', '# Every shard runs the same non-test gates; all test files are partitioned')
    .replace('# 20-minute budget. Weighted files execute once, serially per VM.', '# 20-minute budget. Node partitions every JS file once, serially per VM.');
}
