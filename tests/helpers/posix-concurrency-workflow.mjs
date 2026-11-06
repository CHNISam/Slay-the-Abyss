// Undo only the reviewed POSIX scheduling cap for immutable source guards.
// Every other byte remains the responsibility of the original whole-source hash.
export function beforePosixConcurrencyWorkflow(text) {
  if (!/^[ \t]*max-parallel:/m.test(text)) return text;
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const jobs = [...text.matchAll(/^  engineering-posix-shards:\r?\n[\s\S]*?(?=^  [\w-]+:|(?![\s\S]))/gm)];
  if (jobs.length !== 1 || (text.match(/^[ \t]*max-parallel:/gm) ?? []).length !== 1) return null;
  const job = jobs[0][0];
  if ((job.match(/^    strategy:\r?$/gm) ?? []).length !== 1) return null;
  const block = value => [
    '    strategy:',
    '      fail-fast: false',
    '      max-parallel: ' + value,
    '      matrix:',
    ''
  ].join(eol);
  // Invert current 12-way scheduling to the reviewed six-way epoch first;
  // then restore its original no-cap source. Other changes remain visible
  // to the frozen whole-source guard. Unreviewed values fail closed.
  const current = block(12), legacy = block(6);
  const normalized = job.split(current).length === 2
    ? job.replace(current, legacy) : job;
  if (normalized.split(legacy).length !== 2) return null;
  return text.replace(job, normalized.replace(legacy, legacy.replace('      max-parallel: 6' + eol, '')));
}
