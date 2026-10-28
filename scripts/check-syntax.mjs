import { readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFile } from 'node:child_process';

function files(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? files(path) : /\.[cm]?js$/.test(entry.name) ? [path] : [];
  });
}

export async function checkSyntax(directories = ['scripts', 'tests'], run = execFile) {
  const paths = directories.flatMap(files), errors = [];
  let next = 0;
  async function consume() {
    while (next < paths.length) {
      const path = paths[next++];
      try {
        await new Promise((resolve, reject) => {
          run(process.execPath, ['--check', path], { encoding: 'utf8', timeout: 10000, windowsHide: true },
            (error, stdout, stderr) => error ? reject(new Error(stderr || error.message)) : resolve());
        });
      } catch (error) { errors.push(new Error(`${path}: ${error.message}`)); }
    }
  }
  // Parsing does not execute modules or touch generated files. Keep at most
  // two independent Node parsers active, each with its original 10s deadline.
  await Promise.all([consume(), consume()]);
  if (errors.length) throw new AggregateError(errors, 'JavaScript syntax checks failed');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    await checkSyntax();
    console.log('JavaScript syntax checks passed.');
  } catch (error) {
    console.error((error.errors ?? [error]).map(item => item.message).join('\n'));
    process.exitCode = 1;
  }
}
