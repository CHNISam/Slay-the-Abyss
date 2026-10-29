import { readFileSync, statSync, realpathSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const limits = {
  'AGENTS.md': { lines: 80, characters: 5000 },
  'CLAUDE.md': { lines: 16, characters: 1000 },
  '.cursor/rules/miliastra.mdc': { lines: 16, characters: 1000 },
};
const outside = path => path === '..' || path.startsWith('../') || path.startsWith('..\\') || isAbsolute(path);

export function auditGuidance(root = '.') {
  root = realpathSync(root);
  const scripts = JSON.parse(readFileSync(resolve(root, 'package.json'), 'utf8')).scripts;
  const errors = [], metrics = [];
  for (const [file, limit] of Object.entries(limits)) {
    let source;
    try { source = readFileSync(resolve(root, file), 'utf8').replaceAll('\r\n', '\n'); }
    catch { errors.push(`${file}: missing guidance`); continue; }
    const lines = source.trimEnd().split('\n').length, characters = [...source].length;
    metrics.push({ file, lines, characters });
    if (lines > limit.lines || characters > limit.characters) errors.push(`${file}: budget exceeded (${lines}/${limit.lines} lines, ${characters}/${limit.characters} characters)`);
    let pointsToAgents = false;
    // Entry files use inline Markdown links. Remote links and in-page anchors
    // do not require network access; local file targets must resolve in-tree.
    for (const [, raw] of source.matchAll(/\[[^\]\n]+\]\(([^)\n]+)\)/g)) {
      if (/^(?:[a-z][a-z\d+.-]*:|#)/i.test(raw)) continue;
      const target = resolve(root, dirname(file), raw.split('#')[0]);
      try {
        if (outside(relative(root, target)) || outside(relative(root, realpathSync(target))) || !statSync(target).isFile()) throw new Error('invalid');
        if (relative(root, target) === 'AGENTS.md') pointsToAgents = true;
      } catch { errors.push(`${file}: invalid local link ${raw}`); }
    }
    for (const [, command] of source.matchAll(/\bnpm run ([\w:-]+)/g)) {
      if (!Object.hasOwn(scripts, command)) errors.push(`${file}: unknown npm script ${command}`);
    }
    if (file !== 'AGENTS.md') {
      if (!pointsToAgents) errors.push(`${file}: adapter must link AGENTS.md`);
      if (/^##\s/m.test(source)) errors.push(`${file}: adapter must not add policy sections`);
    }
  }
  return { errors, metrics };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const result = auditGuidance();
  console.log(JSON.stringify(result, null, 2));
  if (result.errors.length) process.exitCode = 1;
}
