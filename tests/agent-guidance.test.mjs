import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { auditGuidance } from '../scripts/check-agent-guidance.mjs';

function fixture(t, overrides = {}) {
  const root = mkdtempSync(join(tmpdir(), 'agent-guidance-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const files = {
    'package.json': JSON.stringify({ scripts: { check: 'node check.mjs' } }),
    'AGENTS.md': '# Project\n[Guide](docs/guide.md)\n`npm run check`\n',
    'docs/guide.md': '# Guide\n',
    'CLAUDE.md': '[Rules](AGENTS.md)\n',
    '.cursor/rules/miliastra.mdc': '[Rules](../../AGENTS.md)\n',
    ...overrides,
  };
  for (const [file, content] of Object.entries(files)) {
    if (content === null) continue;
    mkdirSync(dirname(join(root, file)), { recursive: true });
    writeFileSync(join(root, file), content);
  }
  return auditGuidance(root);
}

test('repository entry points fit their budgets and reference existing commands and files', () => {
  assert.deepEqual(auditGuidance().errors, []);
});
test('small adapters resolve links relative to their own directory', t => {
  assert.deepEqual(fixture(t).errors, []);
});
test('both line and Unicode character budgets fail closed', t => {
  assert.match(fixture(t, { 'AGENTS.md': '# Rules\n'.repeat(81) }).errors.join('\n'), /budget exceeded/);
  assert.match(fixture(t, { 'AGENTS.md': '规'.repeat(5001) }).errors.join('\n'), /budget exceeded/);
  assert.match(fixture(t, { 'CLAUDE.md': '[Rules](AGENTS.md)\n' + 'a'.repeat(1000) }).errors.join('\n'), /budget exceeded/);
});
test('missing files, broken links and paths outside the repo are rejected', t => {
  const result = fixture(t, {
    'CLAUDE.md': null,
    'AGENTS.md': '[missing](docs/missing.md)\n[outside](../package.json)\n[directory](docs)\n',
  });
  assert.equal(result.errors.length, 4);
  assert.match(result.errors.join('\n'), /missing guidance/);
  assert.equal(result.errors.filter(e => e.includes('invalid local link')).length, 3);
});
test('unknown commands and policy copies in adapters are rejected', t => {
  const result = fixture(t, {
    'AGENTS.md': '`npm run nonexistent`\n',
    'CLAUDE.md': '[Guide](docs/guide.md)\n## Duplicate rules\n',
  });
  assert.equal(result.errors.length, 3);
  assert.match(result.errors.join('\n'), /unknown npm script/);
  assert.match(result.errors.join('\n'), /adapter must link/);
  assert.match(result.errors.join('\n'), /must not add policy/);
});
