// Native per-file summaries include startup/hooks and dynamic test cases.
// Diagnostics never alter discovery, assertions or the test runner's status.
export default async function* report(source) {
  for await (const { type, data } of source) {
    if (type === 'test:summary' && data.file) {
      const record = JSON.stringify({ file: data.file.replaceAll('\\', '/').replace(process.cwd().replaceAll('\\', '/') + '/', ''),
        durationMs: data.duration_ms, success: data.success });
      process.stdout.write(`CI_FILE_TIMING ${record}\n`);
      yield record + '\n';
    }
  }
}
