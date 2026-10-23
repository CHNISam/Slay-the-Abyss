import { existsSync, realpathSync, statSync } from 'node:fs';
import { dirname, basename, join } from 'node:path';

export function exportedCandidatePath(input) {
  const officialSave = /(?:^|[/\\])Beyond_Local_Save_Level(?:[/\\]|$)/i;
  if (officialSave.test(input)) throw new Error('Use an exported candidate copy, not an official save');
  const candidate = realpathSync.native(input);
  if (officialSave.test(candidate)) throw new Error('Use an exported candidate copy, not an official save');
  if (!statSync(candidate).isFile()) throw new Error('Candidate must be a regular file');
  return candidate;
}

export function newEvidenceDirectory(input) {
  // Resolve the raw existing prefix before joining any new suffix: lexical
  // normalization can change the identity of a path containing symlink/.. .
  let parent = input;
  const pending = [];
  while (!existsSync(parent)) {
    const next = dirname(parent);
    if (next === parent) throw new Error('Output has no existing parent directory');
    pending.unshift(basename(parent));
    parent = next;
  }
  if (pending.includes('..')) throw new Error('Output parent traversal must refer to existing directories');
  return join(realpathSync.native(parent), ...pending);
}
