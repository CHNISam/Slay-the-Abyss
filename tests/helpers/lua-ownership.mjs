import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// A path-only relocation keeps the runner's existing `endsWith('tests/lua/…')`
// layout injection and deadlines. This is an inventory audit, never a selector.
export const ownedRoot = 'tests/fixtures/js-owned/tests/lua/';
export const canonical = text => text.replaceAll(ownedRoot, 'tests/lua/').replaceAll(ownedRoot.slice(0,-1), 'tests/lua');
export const sha = text => createHash('sha256').update(text.replaceAll('\r\n','\n')).digest('hex');
export const read = path => readFileSync(path,'utf8');

export function auditOwnership(manifest, { historical = false } = {}) {
  const originals = new Set(manifest.originals.map(row=>row.path));
  const moved = new Map(manifest.moved.map(row=>[row.from,row]));
  assert.equal(originals.size,manifest.originals.length,'unique original Lua entries');
  assert.equal(moved.size,manifest.moved.length,'unique ownership transfers');
  const raw = readdirSync('tests/lua').filter(f=>f.endsWith('.lua')).map(f=>'tests/lua/'+f);
  for (const row of manifest.originals) {
    const transfer=moved.get(row.path);
    const path=transfer?.to??row.path;
    assert.ok(existsSync(path),`original fixture still exists: ${path}`);
    if (transfer||historical) assert.equal(sha(canonical(read(path))),row.sha256LF,`all original Lua assertions: ${path}`);
    if (transfer) {
      assert.ok(!existsSync(row.path),`no second raw entry for ${path}`);
      assert.ok(transfer.owners.length,`JS owner required: ${path}`);
      assert.equal(transfer.to,ownedRoot+row.path.slice('tests/lua/'.length));
      for (const owner of transfer.owners) assert.ok(existsSync(owner),`owner exists: ${owner}`);
    } else assert.ok(raw.includes(row.path),`retained raw coverage: ${row.path}`);
  }
  assert.deepEqual(raw.filter(path=>originals.has(path)).sort(),manifest.originals.filter(row=>!moved.has(row.path)).map(row=>row.path).sort(),
    'original raw fixtures partition exactly into raw and JS ownership');
  assert.deepEqual(readdirSync(ownedRoot).filter(f=>f.endsWith('.lua')).sort(),
    manifest.moved.map(row=>row.to.slice(ownedRoot.length)).sort(),'no unowned relocated fixture');
  for (const row of historical?manifest.support:[]) {
    assert.equal(sha(read(row.path)),row.sha256LF,`unchanged shared Lua assertions and inputs: ${row.path}`);
  }
  for (const row of manifest.fixtures) {
    assert.equal(sha(canonical(read(row.path))),row.sha256LF,`unchanged JSON parameters and partitions: ${row.path}`);
  }
  for (const row of manifest.wrappers) {
    let source=canonical(read(row.path));
    for (const rewrite of row.pathOnlyRewrites??[]) {
      assert.equal(source.split(rewrite.current).length,2,'one explicit path-only rewrite');
      source=source.replace(rewrite.current,rewrite.original);
    }
    assert.equal(sha(source),row.sha256LF,`all original JS assertions: ${row.path}`);
  }
}

if (process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  const manifest=JSON.parse(read('tests/fixtures/lua-ownership.json'));
  auditOwnership(manifest,{historical:true});
  console.log(`Historical assertion audit passed: ${manifest.originals.length} original Lua entries, ${manifest.support.length} shared supports, ${manifest.wrappers.length} affected JS wrappers.`);
}
