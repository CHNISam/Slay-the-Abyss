import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, existsSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import * as lfs from '../scripts/ci-reviewed-lfs.mjs';
import { reviewedPngPaths, needsReviewedAssets, verifyReviewedPngs, prepareReviewedAssets, lfsEnvironment, lfsArguments } from '../scripts/ci-reviewed-lfs.mjs';

const root = resolve('.');
const expectedPaths = ['armaments', 'heavy_blade'].flatMap(id => ['source.png', 'preview-native.png'].map(name => `art/cards/traveler-geo/${id}/${name}`));
const source = readFileSync('scripts/ci-reviewed-lfs.mjs', 'utf8');
// Synthetic pixels keep this CI-contract test independent of the real asset
// consumer's shard. Only the frozen data table changes in this test copy;
// actual Git/LFS transport, pointer budget and PNG verification code is unchanged.
const fakePngs = expectedPaths.map((_,index) => {
  const bytes=Buffer.alloc(64,index+1); Buffer.from([137,80,78,71,13,10,26,10]).copy(bytes); bytes.write('IHDR',12); return bytes;
});
function fixtureSource(text) {
  const table = /export const frozenObjects = \[[\s\S]*?\n\];/;
  assert.equal([...text.matchAll(new RegExp(table,'g'))].length,1);
  return text.replace(table, 'export const frozenObjects = '+JSON.stringify(fakePngs.map(b=>[createHash('sha256').update(b).digest('hex'),b.length]))+';');
}
const fixtureModuleDir=mkdtempSync(join(tmpdir(),'abyss-lfs-module-'));
after(()=>rmSync(fixtureModuleDir,{recursive:true,force:true}));
const fixtureModulePath=join(fixtureModuleDir,'ci-reviewed-lfs.mjs');
writeFileSync(fixtureModulePath,fixtureSource(source));
const fixtureLfs=await import(pathToFileURL(fixtureModulePath).href);

const shardStep = `      - name: Materialize reviewed PNGs for this shard\n        timeout-minutes: 2\n        env:\n          CI_LFS_TOKEN: \${{ github.token }}\n        run: node scripts/ci-reviewed-lfs.mjs --shard=\${{ matrix.shard }}/\${{ strategy.job-total }}\n`;
const licenseStep = `      - name: Materialize reviewed PNGs for the license audit\n        timeout-minutes: 2\n        env:\n          CI_LFS_TOKEN: \${{ github.token }}\n        run: node scripts/ci-reviewed-lfs.mjs\n`;
function temp(t) { const dir = mkdtempSync(join(tmpdir(), 'abyss-reviewed-lfs-')); t.after(() => rmSync(dir, { recursive: true, force: true })); return dir; }
function git(cwd, ...args) {
  const r = spawnSync('git', ['-c', 'core.hooksPath=', ...args], { cwd, encoding: 'utf8', windowsHide: true, env: { ...process.env, GIT_NO_LAZY_FETCH: '1', GIT_LFS_SKIP_SMUDGE: '1', GIT_TERMINAL_PROMPT: '0' }, timeout: 30000 });
  assert.ifError(r.error); assert.equal(r.status, 0, r.stderr); return r.stdout.trim();
}
function fixture(t) {
  const dir = temp(t); git(dir, 'init');
  // Copy one existing commit object verbatim, not its tree/history and not a
  // new commit. Alternates would also let LFS silently borrow the source cache,
  // invalidating the missing-object negative control.
  const commit = spawnSync('git', ['cat-file','commit','HEAD'], {cwd:root,windowsHide:true});
  assert.equal(commit.status,0);
  const copied = spawnSync('git', ['hash-object','-t','commit','-w','--stdin'], {cwd:dir,input:commit.stdout,encoding:'utf8',windowsHide:true});
  assert.equal(copied.status,0); assert.equal(copied.stdout.trim(),git(root,'rev-parse','HEAD'));
  git(dir, 'update-ref', 'refs/heads/fixture', copied.stdout.trim());
  git(dir, 'symbolic-ref', 'HEAD', 'refs/heads/fixture');
  for (const [key,value] of [['clean','git-lfs clean -- %f'],['smudge','git-lfs smudge -- %f'],['process','git-lfs filter-process'],['required','true']]) git(dir, 'config', '--local', `filter.lfs.${key}`, value);
  git(dir, 'config', '--local', 'lfs.url', pathToFileURL(join(dir, 'absent-server')).href);
  const extra = 'art/cards/future/source.png';
  writeFileSync(join(dir, '.gitattributes'), [...expectedPaths,extra].map(p => `${p} filter=lfs diff=lfs merge=lfs -text`).join('\n')+'\n');
  const bytes = new Map();
  for (const [i,path] of [...expectedPaths,extra].entries()) {
    const png = expectedPaths.includes(path) ? fakePngs[expectedPaths.indexOf(path)] : Buffer.alloc(64,i+1);
    if (path === extra) { Buffer.from([137,80,78,71,13,10,26,10]).copy(png); png.write('IHDR',12); }
    mkdirSync(join(dir,path,'..'), {recursive:true}); writeFileSync(join(dir,path),png); bytes.set(path,png);
  }
  for (const id of ['armaments','heavy_blade']) {
    const files = Object.fromEntries(['source.png','preview-native.png'].map(name => { const b=bytes.get(`art/cards/traveler-geo/${id}/${name}`); return [name,{bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')}]; }));
    writeFileSync(join(dir,`art/cards/traveler-geo/${id}/asset.json`),JSON.stringify({files}));
  }
  git(dir,'add','.gitattributes',...expectedPaths,extra);
  for (const p of [...expectedPaths,extra]) writeFileSync(join(dir,p),git(dir,'show',':'+p)+'\n');
  const object = path => { const oid=createHash('sha256').update(bytes.get(path)).digest('hex'); return join(dir,'.git/lfs/objects',oid.slice(0,2),oid.slice(2,4),oid); };
  rmSync(object(extra)); // Broadening the pull to future art would now fail offline.
  return {dir,bytes,object,extra};
}
function workflowContract(quality, licenses) {
  assert.match(quality,/\npermissions:\n  contents: read\n/); assert.match(licenses,/\npermissions:\n  contents: read\n/);
  assert.doesNotMatch(quality+licenses,/contents: write|lfs:\s*true|persist-credentials:\s*true|actions\/cache/);
  assert.equal(quality.split(shardStep).length-1,2);
  assert.ok(quality.includes(shardStep+'      - name: JavaScript regression shard\n'));
  assert.ok(quality.includes(shardStep+'      - name: POSIX JavaScript regression shard\n'));
  assert.ok(licenses.includes(licenseStep+'      - run: node --test scripts/check-license.test.mjs\n'));
  assert.ok(quality.includes("          CI_REPOSITORY: ${{ github.repository }}\n          GIT_LFS_SKIP_SMUDGE: '1'\n"));
  assert.doesNotMatch(quality.match(/\n  presentation:\n([\s\S]*?)(?=\n  engineering-posix-shards:)/)[1],/ci-reviewed-lfs|lfs:\s*true/);
}

test('only the exact four reviewed PNG paths are eligible; child auth is ephemeral and sanitized', () => {
  assert.deepEqual(reviewedPngPaths, expectedPaths);
  assert.deepEqual(lfs.frozenObjects,[
    ['e63cd8703ce983eb1556efa31a017b803e31c7b887e9c3e14c77bd3ba9928332',1750604],
    ['b7b2cd9c4fdfa3f1d893156405a51afc8b8bd1b65a776a9f704086c97685b2ff',30121],
    ['f396062d29b6845b58bf0043c1941a2219d9ca501ae6520c8579d555d73008d5',1769446],
    ['6fefbbcbdaa503a1df1c04d282dc9f8cac0fdb36fb189e75aa89427b438b30b1',30178],
  ]);
  assert.deepEqual(lfsArguments.slice(-6), ['lfs','pull','--include',expectedPaths.join(','),'--exclude','']);
  assert.ok(lfsArguments.includes('credential.helper=')); assert.ok(lfsArguments.includes('lfs.transfer.maxretries=0'));
  assert.ok(!lfsArguments.includes('--all') && !lfsArguments.includes('--recent'));
  const env = {CI_LFS_TOKEN:'not-a-real-token',UNCHANGED:'yes'};
  const child = lfsEnvironment(env);
  assert.equal(child.CI_LFS_TOKEN,undefined); assert.equal(env.CI_LFS_TOKEN,'not-a-real-token');
  assert.equal(child.GIT_TERMINAL_PROMPT,'0'); assert.equal(child.GIT_CONFIG_COUNT,'1');
  assert.equal(child.GIT_CONFIG_KEY_0,'http.https://github.com/.extraheader');
  assert.equal(child.GIT_CONFIG_VALUE_0,'AUTHORIZATION: basic '+Buffer.from('x-access-token:not-a-real-token').toString('base64'));
});

test('real native Node CLI agrees with asset owner before and after insertion shifts the sorted position', t => {
  const dir=temp(t); mkdirSync(join(dir,'tests'));
  const name='reviewed-traveler-geo-assets.test.mjs';
  const names=['a.test.mjs','b.test.mjs',name,'z.test.mjs'];
  const env={...process.env}; delete env.NODE_TEST_CONTEXT;
  for (const added of [null,'aa-new.test.mjs']) {
    if(added) names.push(added);
    for(const n of names) writeFileSync(join(dir,'tests',n),`import test, { after } from 'node:test';test(${JSON.stringify(n)},()=>{});\n`);
    const files=readdirSync(join(dir,'tests')).filter(n=>n.endsWith('.test.mjs')).map(n=>'tests/'+n);
    for(const total of [1,2,4,8]) for(let shard=1;shard<=total;shard++) {
      const r=spawnSync(process.execPath,['--test',`--test-shard=${shard}/${total}`,'--test-reporter=tap','tests/*.test.mjs'],{cwd:dir,env,encoding:'utf8',windowsHide:true,timeout:30000});
      assert.ifError(r.error); assert.equal(r.status,0,r.stderr+r.stdout);
      const actual=r.stdout.includes('# Subtest: '+name+'\n');
      assert.equal(needsReviewedAssets(files,`${shard}/${total}`),actual,`${added??'original'} ${shard}/${total}`);
    }
  }
  for(const invalid of ['0/8','9/8','1/0','x','1/8;echo bad']) assert.throws(()=>needsReviewedAssets(names,invalid),/Invalid shard/);
  assert.throws(()=>needsReviewedAssets(['tests/other.test.mjs'],'1/2'),/reviewed asset test/);
});

test('non-owner shard does not inspect PNGs or start Git, while materialized bytes reuse the local cache', t => {
  const dir=temp(t); mkdirSync(join(dir,'tests')); writeFileSync(join(dir,'tests/reviewed-traveler-geo-assets.test.mjs'),'');
  assert.deepEqual(prepareReviewedAssets({root:dir,shard:'2/2',env:{...process.env,CI_LFS_TOKEN:''}}),{status:'not-needed',shard:'2/2'});
  const f=fixture(t);
  for(const p of expectedPaths) writeFileSync(join(f.dir,p),f.bytes.get(p));
  assert.equal(fixtureLfs.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:''}}).status,'cached');
});

test('actual git lfs pull materializes four objects offline, leaves unrelated future LFS data untouched, and then reuses them', t => {
  const f=fixture(t);
  // pull scans the current index; unlike fetch it does not apply these recent
  // history defaults. The unrelated object's local cache is deliberately absent.
  for(const [key,value] of [['lfs.fetchrecentalways','true'],['lfs.fetchrecentrefsdays','9999'],['lfs.fetchrecentcommitsdays','9999']]) git(f.dir,'config','--local',key,value);
  assert.throws(()=>fixtureLfs.verifyReviewedPngs(f.dir),/not the reviewed PNG/);
  assert.equal(fixtureLfs.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:''}}).status,'materialized');
  for(const p of expectedPaths) assert.deepEqual(readFileSync(join(f.dir,p)),f.bytes.get(p));
  assert.match(readFileSync(join(f.dir,f.extra),'utf8'),/^version https:\/\/git-lfs.github.com\/spec\/v1/);
  assert.equal(existsSync(f.object(f.extra)),false);
  assert.equal(fixtureLfs.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:''}}).status,'cached');
  writeFileSync(join(f.dir,expectedPaths[0]),'corrupted');
  assert.throws(()=>fixtureLfs.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:''}}),/not the reviewed PNG/);
});

test('a missing LFS object fails closed, and errors never echo the token or Git authorization header', t => {
  const f=fixture(t); rmSync(f.object(expectedPaths[0]));
  assert.throws(()=>fixtureLfs.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:'not-a-real-token'}}),error=> {
    assert.match(error.message,/LFS materialization failed/); assert.doesNotMatch(error.message,/not-a-real-token|AUTHORIZATION|eC1hY2Nlc3M/); return true;
  });
});

test('workflow contract rejects broader permissions, unconditional pulls, automatic LFS checkout, and missing skip-smudge', () => {
  const quality=readFileSync('.github/workflows/quality.yml','utf8').replaceAll('\r\n','\n');
  const licenses=readFileSync('.github/workflows/licenses.yml','utf8').replaceAll('\r\n','\n');
  workflowContract(quality,licenses);
  for(const mutate of [q=>q.replace('contents: read','contents: write'),q=>q.replace('persist-credentials: false','persist-credentials: false\n          lfs: true'),q=>q.replace(' --shard=${{ matrix.shard }}/${{ strategy.job-total }}',''),q=>q.replace("          GIT_LFS_SKIP_SMUDGE: '1'\n",'')]) assert.throws(()=>workflowContract(mutate(quality),licenses));
});

test('negative controls reject expanded include, retained token, omitted real PNG verification and unconditional materialization', async t => {
  async function mutant(before,after) { assert.ok(source.includes(before)); const dir=temp(t); const path=join(dir,'mutant.mjs'); writeFileSync(path,fixtureSource(source.replace(before,after))); return import(pathToFileURL(path).href); }
  const broad=await mutant("['source.png', 'preview-native.png']","['*.png', 'preview-native.png']");
  assert.ok(Array.isArray(broad.reviewedPngPaths));
  assert.notDeepEqual(broad.reviewedPngPaths,expectedPaths);
  const retained=await mutant('delete childEnv.CI_LFS_TOKEN;', '// token cleanup removed');
  assert.equal(retained.lfsEnvironment({CI_LFS_TOKEN:'not-a-real-token'}).CI_LFS_TOKEN,'not-a-real-token');
  const noVerify=await mutant('const verified = verifyReviewedPngs(root); // Required after pull, even when Git exits zero.', 'const verified = {}; // verification removed');
  const f=fixture(t); for(const p of expectedPaths) writeFileSync(join(f.dir,p),f.bytes.get(p)); writeFileSync(join(f.dir,expectedPaths[0]),'corrupted');
  assert.throws(()=>fixtureLfs.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:''}}), { code: 'ERR_REVIEWED_PNG' });
  // Call the actual mutant. A TypeError or a no-op mutation must fail this test,
  // not be mistaken for successful detection by nested assert.throws.
  assert.equal(noVerify.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:''}}).status, 'materialized');
  assert.equal(readFileSync(join(f.dir,expectedPaths[0]), 'utf8'), 'corrupted');
  const unconditional=await mutant("if (!needsReviewedAssets(files, shard)) return { status: 'not-needed', shard };", '// shard guard removed');
  const dir=temp(t); mkdirSync(join(dir,'tests')); writeFileSync(join(dir,'tests/reviewed-traveler-geo-assets.test.mjs'),'');
  assert.throws(()=>unconditional.prepareReviewedAssets({root:dir,shard:'2/2',env:{...process.env,CI_LFS_TOKEN:''}}), /Invalid reviewed LFS index pointer/);
});

function replaceIndexPointer(dir, path, pointer) {
  const r=spawnSync('git',['hash-object','-w','--stdin'],{cwd:dir,input:pointer,encoding:'utf8',windowsHide:true});
  assert.equal(r.status,0,r.stderr); git(dir,'update-index','--cacheinfo','100644',r.stdout.trim(),path);
}
test('frozen payload budget and OIDs reject oversized or changed pointers before any transfer', t => {
  assert.equal(lfs.maxReviewedPngBytes,3580349);
  const oversized=fixture(t), path=expectedPaths[0];
  const pointer=git(oversized.dir,'show',':'+path)+'\n';
  replaceIndexPointer(oversized.dir,path,pointer.replace(/size \d+/,'size 1073741824'));
  assert.throws(()=>fixtureLfs.prepareReviewedAssets({root:oversized.dir,env:{...process.env,CI_LFS_TOKEN:''}}),/payload exceeds.*3580349/);
  const changed=fixture(t);
  replaceIndexPointer(changed.dir,path,(git(changed.dir,'show',':'+path)+'\n').replace(/oid sha256:[0-9a-f]{64}/,'oid sha256:'+'0'.repeat(64)));
  assert.throws(()=>fixtureLfs.prepareReviewedAssets({root:changed.dir,env:{...process.env,CI_LFS_TOKEN:''}}),/does not match the frozen reviewed object/);
  for(const p of expectedPaths) writeFileSync(join(changed.dir,p),changed.bytes.get(p));
  assert.throws(()=>fixtureLfs.prepareReviewedAssets({root:changed.dir,env:{...process.env,CI_LFS_TOKEN:''}}),/does not match the frozen reviewed object/, 'cache hits cannot bypass index pointer validation');
});

test('a fresh runner with empty LFS filter configuration still materializes without persisting configuration', t => {
  const f=fixture(t);
  for(const key of ['clean','smudge','process']) git(f.dir,'config','--local',`filter.lfs.${key}`,'');
  git(f.dir,'config','--local','filter.lfs.required','false');
  const before=readFileSync(join(f.dir,'.git/config'));
  assert.equal(fixtureLfs.prepareReviewedAssets({root:f.dir,env:{...process.env,CI_LFS_TOKEN:''}}).status,'materialized');
  assert.deepEqual(readFileSync(join(f.dir,'.git/config')),before,'command-only filters never persist in Git config');
});
