// Invert only the reviewed executor substitutions; retain the original workflow
// hash guards for every gate, permission, deadline, matrix and artifact field.
export function originalWorkflow(text) {
  return text.replace(" --workers ${{ inputs.runner_pool == 'local-special' && 1 || 2 }}", '')
    .replaceAll('node scripts/ci-shards.mjs --prepare=', 'node scripts/ci-reviewed-lfs.mjs --shard=')
    .replaceAll('node scripts/ci-shards.mjs --shard=${{ matrix.shard }}/${{ strategy.job-total }}',
      'node --test --test-concurrency=1 --test-shard=${{ matrix.shard }}/${{ strategy.job-total }} tests/*.test.mjs')
    .replace('# All test files are partitioned by measured file weights', '# Every shard runs the same non-test gates; all test files are partitioned')
    .replace('# 20-minute budget. Weighted files execute once, serially per VM.', '# 20-minute budget. Node partitions every JS file once, serially per VM.');
}
