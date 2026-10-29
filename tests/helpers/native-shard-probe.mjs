import { spawnSync } from 'node:child_process';

// Name-only probes are independent CLI runs, like the hosted shard VMs.
// Let Node expand the short pattern inside the temporary directory: enumerating
// absolute paths in argv exceeds Windows' command-line limit as the suite grows.
export function nativeShardProbe(root, shard, total) {
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT;
  const args = ['--test', '--test-isolation=none', '--test-concurrency=1', `--test-shard=${shard}/${total}`, '--test-reporter=tap', '*.test.mjs'];
  const result = spawnSync(process.execPath, args, {
    cwd: root, env, encoding: 'utf8', windowsHide: true, timeout: 30000, maxBuffer: 2 * 1024 * 1024,
  });
  return { ...result, command: [process.execPath, ...args] };
}
