// Undo only the reviewed POSIX scheduling cap for immutable source guards.
// Every other byte remains the responsibility of the original whole-source hash.
export function beforePosixConcurrencyWorkflow(text) {
  if (!/^[ \t]*max-parallel:/m.test(text)) return text;
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const jobs = [...text.matchAll(/^  engineering-posix-shards:\r?\n[\s\S]*?(?=^  [\w-]+:|(?![\s\S]))/gm)];
  if (jobs.length !== 1 || (text.match(/^[ \t]*max-parallel:/gm) ?? []).length !== 1) return null;
  const job = jobs[0][0];
  if ((job.match(/^    strategy:\r?$/gm) ?? []).length !== 1) return null;
  const approved = [
    '    strategy:',
    '      fail-fast: false',
    '      max-parallel: 6',
    '      matrix:',
    ''
  ].join(eol);
  if (job.split(approved).length !== 2) return null;
  return text.replace(job, job.replace(approved, approved.replace('      max-parallel: 6' + eol, '')));
}
