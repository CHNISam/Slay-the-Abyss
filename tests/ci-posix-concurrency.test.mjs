import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {beforePosixConcurrencyWorkflow} from './helpers/posix-concurrency-workflow.mjs';
import {beforeAutoMergeWorkflow} from './helpers/auto-merge-workflow.mjs';
import {beforePlatformWorkflow} from './helpers/platform-load-wiring.mjs';
import {originalWorkflow} from './helpers/ci-runtime-workflow.mjs';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';

const current = readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
const cap = '      max-parallel: 12\n';
const job = source => source.match(/^  engineering-posix-shards:\n[\s\S]*?(?=^  [\w-]+:|(?![\s\S]))/m)[0];
const addCap = source => source.replace(job(source),job(source).replace('      fail-fast: false\n','      fail-fast: false\n'+cap));
const digest = source => createHash('sha256').update(source).digest('hex');

test('physical Quality workflow caps concurrent POSIX shards at twelve',()=>{
  assert.equal((current.match(/^\s*max-parallel:/gm)??[]).length,1);
  assert.ok(job(current).includes('    strategy:\n      fail-fast: false\n'+cap+'      matrix:\n        shard: ${{ fromJSON(needs.impact.outputs.posix_shards) }}\n'));
  assert.ok(job(current).includes('    runs-on: ubuntu-24.04\n    timeout-minutes: 30\n'));
  assert.equal(beforePosixConcurrencyWorkflow(current),current.replace(cap,''));
});

test('current twelve and historical six both restore the exact original source',()=>{
  const noCap=current.replace(cap,''),oldCap=current.replace(cap,'      max-parallel: 6\n');
  assert.equal(beforePosixConcurrencyWorkflow(current),noCap);
  assert.equal(beforePosixConcurrencyWorkflow(oldCap),noCap);
  for(const drift of [
    current.replace(cap,'      max-parallel: 8\n'),
    current.replace(cap,cap+cap)
  ])assert.equal(beforePosixConcurrencyWorkflow(drift),null);
});

test('exact concurrency inverse preserves old bytes and LF or CRLF endings',()=>{
  for(const eol of ['\n','\r\n']){
    const old=current.replace(cap,'').replaceAll('\n',eol);
    const capped=current.replaceAll('\n',eol);
    assert.equal(beforePosixConcurrencyWorkflow(old),old);
    assert.equal(beforePosixConcurrencyWorkflow(capped),old);
    // Existing layered callers normalize endings; this inverse alone preserves
    // the original bytes, including a Windows checkout's CRLF.
    const projected=beforeAutoMergeWorkflow(capped.replaceAll('\r\n','\n'));
    assert.equal(typeof projected,'string');
    assert.equal(projected,beforeAutoMergeWorkflow(old.replaceAll('\r\n','\n')));
  }
});

historicalTest('cap inverse shares the platform and original whole-source guards without changing their hashes',()=>{
  const old=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
  const capped=addCap(old);
  assert.notEqual(capped,old);
  assert.equal(beforeAutoMergeWorkflow(capped),beforeAutoMergeWorkflow(old));
  assert.equal(digest(beforePlatformWorkflow(capped)),'c1759c590177f4a2389fa04e700167d0948eae41b9f12e67db4b6bf48f5871ae');
  const expected='d44ae4e29ef74a972f329ecdc8f8131c464d30196300a600387479945660d35d';
  assert.equal(digest(originalWorkflow(capped)),expected);
  assert.equal(digest(originalWorkflow(old)),expected);
  const reject=source=>{
    let rejected=false;
    try{rejected=digest(originalWorkflow(source))!==expected;}catch{rejected=true;}
    assert.equal(rejected,true,'old complete source identity rejects drift');
  };
  const body=job(capped);
  const malformed=[
    capped.replace(cap,'      max-parallel: 7\n'),
    capped.replace(cap,'      max-parallel: 8\n'),
    capped.replace(cap,cap+cap),
    capped.replace(body,body.replace('    strategy:\n','    strategy:\n    strategy:\n')),
    capped.replace(body,body+body),
    capped.replace(cap,'').replace('  rules:\n','  rules:\n    strategy:\n'+cap),
    capped.replace(cap,'').replace('  impact:\n','  impact:\n    strategy:\n'+cap),
    capped.replace(cap,'').replace('      matrix:\n','      matrix:\n'+cap),
  ];
  for(const source of malformed){
    for(const eol of ['\n','\r\n']) assert.equal(beforePosixConcurrencyWorkflow(source.replaceAll('\n',eol)),null);
    reject(source);
  }
  for(const source of [
    capped.replace('contents: read','contents: write'),
    capped.replace(body,body.replace('    timeout-minutes: 20','    timeout-minutes: 21')),
    capped.replace(body,body.replace('        shard: [1, 2, 3, 4]','        shard: [1, 2, 3]')),
    capped.replace(body,body.replace('      - run: npm run check:engineering\n','      - run: echo omitted\n')),
  ]){
    assert.equal(beforePosixConcurrencyWorkflow(source),source.replace(cap,''),'unrelated bytes remain visible');
    reject(source);
  }
});
