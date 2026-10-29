import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { beforePlatformWorkflow, beforePlatformPackage, platformWorkflowEdits, platformPackageEdits } from './helpers/platform-load-wiring.mjs';
import { originalWorkflow } from './helpers/ci-runtime-workflow.mjs';
import { preRetirementSource } from './helpers/presentation-announcement-retirement.mjs';

const digest = value => createHash('sha256').update(value).digest('hex');
const workflow = readFileSync('.github/workflows/quality.yml', 'utf8').replaceAll('\r\n', '\n');
const pkg = readFileSync('package.json', 'utf8').replaceAll('\r\n', '\n');
const baseWorkflow = 'c1759c590177f4a2389fa04e700167d0948eae41b9f12e67db4b6bf48f5871ae';
const basePackage = 'a0b260e54faef8fa51e217a572c6258a03c8cdf69d0c545ba536c114a6f37273';

test('new platform gates and uploads preserve the entire accepted CI and package bytes', () => {
  assert.equal(digest(beforePlatformWorkflow(workflow)), baseWorkflow);
  assert.equal(digest(beforePlatformPackage(pkg)), basePackage);
  assert.doesNotThrow(() => originalWorkflow(workflow));
  assert.doesNotThrow(() => preRetirementSource('package.json', pkg));
});
test('missing, duplicated, moved or altered gate wiring cannot disappear in historical replay', () => {
  for (const [source, edits, invert, oldHash] of [[workflow, platformWorkflowEdits, beforePlatformWorkflow, baseWorkflow],
    [pkg, platformPackageEdits, beforePlatformPackage, basePackage]]) {
    for (const edit of edits) {
      assert.equal(source.split(edit.after).length, 2);
      for (const bad of [source.replace(edit.after, edit.before), source.replace(edit.after, edit.after + edit.after),
        source.replace(edit.after, edit.after.replace('platform-load', 'other-load')),
        source.replace(edit.after, edit.after.replace('platform-load', 'platform-load --skip'))]) {
        assert.equal(invert(bad), null);
      }
    }
    const unrelated = source.replace('"private": true', '"private": false').replace('contents: read', 'contents: write');
    assert.notEqual(digest(invert(unrelated)), oldHash, 'unrelated source drift must remain visible');
  }
  const moved = workflow.replace(platformWorkflowEdits[0].after, platformWorkflowEdits[0].before)
    + platformWorkflowEdits[0].after;
  assert.notEqual(digest(beforePlatformWorkflow(moved)), baseWorkflow, 'moving a gate outside its job must not restore accepted CI');
  assert.equal(beforePlatformWorkflow(workflow.replace('if: matrix.shard == 1\n        run: node scripts/platform-load',
    'if: matrix.shard == 2\n        run: node scripts/platform-load')), null);
});
