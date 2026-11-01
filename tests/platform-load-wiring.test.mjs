import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { beforePlatformWorkflow, beforePlatformPackage, platformWorkflowEdits, platformPackageEdits } from './helpers/platform-load-wiring.mjs';
import { originalWorkflow } from './helpers/ci-runtime-workflow.mjs';
import { preRetirementSource } from './helpers/presentation-announcement-retirement.mjs';
import {readHistoricalBaselineSource,withHistoricalBaseline} from './helpers/historical-baseline-inputs.mjs';

const digest = value => createHash('sha256').update(value).digest('hex');
// These complete-byte witnesses precede current gate orchestration.
const workflow = readHistoricalBaselineSource('.github/workflows/quality.yml').replaceAll('\r\n', '\n');
const pkg = readHistoricalBaselineSource('package.json').replaceAll('\r\n', '\n');
const baseWorkflow = 'c1759c590177f4a2389fa04e700167d0948eae41b9f12e67db4b6bf48f5871ae';
const basePackage = 'a0b260e54faef8fa51e217a572c6258a03c8cdf69d0c545ba536c114a6f37273';

function assertCurrentWiring(source, packageSource) {
  source=source.replaceAll('\r\n','\n');
  const job=name=>(source+'\n  end-of-workflow:\n').match(new RegExp(`^  ${name}:\\n([\\s\\S]*?)(?=^  [\\w-]+:)`,'m'))?.[1];
  const upload='      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4\n';
  const artifact=(guard,name)=>upload+`        if: ${guard}\n        with:\n          name: ${name}\n          path: build/platform-load-daily.json\n          retention-days: 7\n          if-no-files-found: warn\n`;
  const fast=job('fast');assert.ok(fast,'current fast job');
  assert.ok(fast.includes("      - run: npm run check:platform-load\n        if: steps.runtime.outputs.tests == 'true'\n"),'runtime-only fast platform gate');
  assert.ok(fast.includes(artifact("always() && steps.runtime.outputs.tests == 'true'",'platform-load-fast-${{ matrix.os }}')),'fast daily artifact retains its runtime guard');
  for(const [name,platform]of [['rules','windows'],['engineering-posix-shards','posix']]){
    const body=job(name);assert.ok(body,'current platform job: '+name);
    assert.ok(body.includes('      - name: Check production platform load\n        if: matrix.shard == 1\n        run: node scripts/platform-load.mjs daily\n'),'only first shard owns daily gate: '+name);
    assert.ok(body.includes(artifact('always() && matrix.shard == 1',`platform-load-${platform}-`+'${{ github.run_id }}-${{ github.run_attempt }}')),'first shard always uploads its own daily evidence: '+name);
    assert.equal((body.match(/run: node scripts\/platform-load\.mjs/g)||[]).length,1,'one unmodified platform gate: '+name);
  }
  assert.equal((source.match(/run: npm run check:platform-load/g)||[]).length,1,'one fast platform gate');
  const {scripts}=JSON.parse(packageSource);
  assert.equal(scripts['check:platform-load'],'npm run build:data && npm run build:ui && node scripts/platform-load.mjs daily');
  assert.equal(scripts['verify:platform-load'],'node scripts/platform-load.mjs release');
  assert.equal(scripts['check:rules'].split(' && ').filter(command=>command==='npm run check:platform-load').length,1,'ordinary complete check retains daily platform acceptance');
  assert.equal(scripts.check,'npm run check:rules && npm run test:presentation');
}

test('current fast and Full platform gates retain their package commands, owners and daily artifacts',()=>{
  const source=readFileSync('.github/workflows/quality.yml','utf8'),currentPackage=readFileSync('package.json','utf8');
  assertCurrentWiring(source,currentPackage);
  assertCurrentWiring(source.replaceAll('\r\n','\n').replaceAll('\n','\r\n'),currentPackage);
  const normalized=source.replaceAll('\r\n','\n');
  for(const drift of [
    normalized.replace("      - run: npm run check:platform-load\n        if: steps.runtime.outputs.tests == 'true'\n",'      - run: npm run check:platform-load\n'),
    normalized.replace('if: matrix.shard == 1\n        run: node scripts/platform-load','if: matrix.shard == 2\n        run: node scripts/platform-load'),
    normalized.replace('if: always() && matrix.shard == 1\n        with:\n          name: platform-load-','if: matrix.shard == 1\n        with:\n          name: platform-load-'),
    normalized.replace('name: platform-load-posix-','name: platform-load-other-'),
  ]){assert.notEqual(drift,normalized,'current negative control changes real wiring');assert.throws(()=>assertCurrentWiring(drift,currentPackage));}
  const changed=JSON.parse(currentPackage);changed.scripts['check:platform-load']='node scripts/platform-load.mjs daily';
  assert.throws(()=>assertCurrentWiring(source,JSON.stringify(changed)));
  changed.scripts['check:platform-load']=JSON.parse(currentPackage).scripts['check:platform-load'];
  changed.scripts['check:rules']=changed.scripts['check:rules'].replace('npm run check:platform-load && ','');
  assert.throws(()=>assertCurrentWiring(source,JSON.stringify(changed)));
});

test('new platform gates and uploads preserve the entire accepted CI and package bytes', () => {
  assert.equal(digest(beforePlatformWorkflow(workflow)), baseWorkflow);
  assert.equal(digest(beforePlatformPackage(pkg)), basePackage);
  assert.doesNotThrow(() => originalWorkflow(workflow));
  assert.doesNotThrow(() => withHistoricalBaseline(()=>preRetirementSource('package.json', pkg)));
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
