import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Observe actual writes in a disposable fixture, independently of either guard.
// POSIX commonly traverses the link before '..'; Windows may normalize first.
export function traversesLinkBeforeParent(root) {
  const probe = join(root, 'parent-traversal-probe');
  const physical = join(probe, 'physical');
  mkdirSync(join(physical, 'inner'), { recursive: true });
  const lexicalTarget = join(probe, 'target');
  const physicalTarget = join(physical, 'target');
  writeFileSync(lexicalTarget, 'lexical sentinel');
  writeFileSync(physicalTarget, 'physical sentinel');
  symlinkSync(join(physical, 'inner'), join(probe, 'link'), 'junction');
  writeFileSync(`${probe}/link/../target`, 'write probe');
  const lexical = readFileSync(lexicalTarget, 'utf8');
  const actual = readFileSync(physicalTarget, 'utf8');
  const followsLink = actual === 'write probe' && lexical === 'lexical sentinel';
  const normalizesFirst = lexical === 'write probe' && actual === 'physical sentinel';
  assert.ok(followsLink || normalizesFirst, 'Raw write must change exactly one independently named sentinel target');
  return followsLink;
}
