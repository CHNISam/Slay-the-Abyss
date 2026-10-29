import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url));
const json = path => JSON.parse(read(path));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const root = 'art/monsters/';
const noApprovals = { owner:false, native:false, runtime:false, device:false };
const pngSize = bytes => {
  assert.deepEqual([...bytes.subarray(0,8)], [137,80,78,71,13,10,26,10]);
  return [bytes.readUInt32BE(16),bytes.readUInt32BE(20)];
};

test('monster roster covers exactly current Acts1–2 enemy definitions', () => {
  const ids = json('data/enemies.json').enemies.map(enemy => enemy.id);
  // Bounded definition rows, not a Lua parser: encounter tables and move IDs cannot match.
  for (const module of ['abyss_act1_bosses','abyss_act2_enemies']) {
    const definitions = read(`src/lua/${module}.lua`).toString().split('function M.register')[0];
    ids.push(...[...definitions.matchAll(/\{id='([a-z0-9_]+)',name='[^']+',tier='(?:normal|elite|boss)'/g)].map(match => match[1]));
  }
  assert.equal(new Set(ids).size,42);
  const catalog = json(root+'catalog.json');
  assert.equal(catalog.targetCount,42);
  assert.deepEqual([...catalog.roster].sort(),[...new Set(ids)].sort());
  const ready=Object.keys(catalog.candidates), missing=Object.keys(catalog.unavailable);
  assert.deepEqual([...ready,...missing].sort(),[...catalog.roster].sort());
  assert.equal(new Set([...ready,...missing]).size,42);
  const folders=readdirSync(new URL('../'+root,import.meta.url),{withFileTypes:true}).filter(d=>d.isDirectory()).map(d=>d.name);
  assert.deepEqual(folders.sort(),ready.sort());
  for(const [id,state] of Object.entries(catalog.unavailable)) {
    assert.equal(state.sourceProduced,false);
    assert.ok(state.reason); assert.ok(state.status);
    assert.equal(existsSync(new URL('../'+root+id+'/asset.json',import.meta.url)),false);
    if(state.status.includes('MODERATION')) assert.equal(state.retryAuthorized,false);
  }
});

test('monster files preserve reviewed source identity and strict unbound limits', () => {
  const catalog=json(root+'catalog.json');
  assert.deepEqual(catalog.runtime,{status:'unbound',binding:'none'});
  assert.deepEqual(catalog.approvals,noApprovals);
  const geometry=catalog.portraitGeometry;
  assert.match(geometry.auditedCommit,/^[a-f0-9]{40}$/);
  assert.match(geometry.auditSha256,/^[a-f0-9]{64}$/);
  assert.deepEqual(geometry.logicalCanvas,[1280,720]);
  assert.deepEqual(geometry.portrait.readabilityThumbnailIntegers,[106,127,173]);
  assert.equal(geometry.sourcePreviewExplicitPaddingPixels,0);
  assert.equal(geometry.recommendedFutureMinimumInsetFractionEachSide,0.06);
  assert.equal(geometry.insetImplementedInRuntime,false);
  const legal=json('docs/legal/assets.json');
  for(const [id,path] of Object.entries(catalog.candidates)) {
    assert.equal(path,`${id}/asset.json`);
    const asset=json(root+path), provenance=json(root+id+'/generation-provenance.json');
    const review=json(root+id+'/source-review.json');
    assert.equal(asset.enemy_id,id);
    assert.equal(asset.assetRole,'source-candidate-only');
    assert.deepEqual(asset.approvals,noApprovals);
    assert.deepEqual(provenance.approvals,noApprovals);
    assert.deepEqual(review.approvals,noApprovals);
    assert.equal(asset.runtimeBinding,'none');
    assert.equal(asset.nativeJsonLua,'not-created');
    assert.equal(provenance.runtimeBinding,'none');
    assert.match(review.verdict,/^PASS_SOURCE_CANDIDATE_ONLY/);
    assert.equal(review.sourceSha256,asset.files['source.png'].sha256);
    assert.deepEqual(review.sourceSize,asset.sourceSize);
    assert.equal(provenance.generation.exactPrompt,asset.prompt);
    for (const [name,file] of Object.entries(provenance.files)) assert.deepEqual(file,asset.files[name]);
    assert.ok(asset.files[asset.prompt]);
    assert.ok(asset.files['prompt.txt']);
    for (const [name,file] of Object.entries(asset.files)) {
      assert.equal(file.path,name);
      const bytes=read(root+id+'/'+name);
      const pointer=Buffer.from(`version https://git-lfs.github.com/spec/v1\noid sha256:${file.sha256}\nsize ${file.bytes}\n`);
      if(name==='source.png' && bytes.equals(pointer)) {
        const entry=legal.files[root+id+'/'+name];
        assert.equal(entry.sha256,file.sha256);
        assert.equal(entry.lfsBytes,file.bytes);
        continue; // Identity only; actual pixels independently reviewed before publication.
      }
      assert.equal(hash(bytes),file.sha256,`${id}/${name}`);
      assert.equal(bytes.length,file.bytes);
      if(name==='source.png') assert.deepEqual(pngSize(bytes),asset.sourceSize);
    }
    for(const size of [106,127]) assert.ok(asset.previews.some(p => p.size[0]===size));
    for(const preview of asset.previews) {
      const [size,height]=preview.size;
      assert.equal(size,height);
      assert.ok([106,127,173].includes(size));
      assert.equal(preview.path,`preview-contain-${size}.png`);
      assert.deepEqual(pngSize(read(root+id+'/'+preview.path)),preview.size);
      assert.equal(preview.explicitPaddingPixels,0);
      assert.equal(preview.recommendedFutureInsetFractionEachSide,0.06);
      assert.equal(preview.recommendedInsetImplemented,false);
      assert.equal(preview.mode,'contain'); assert.equal(preview.crop,null); assert.equal(preview.stretch,false);
      const [w,h]=asset.sourceSize, scale=Math.min(size/w,size/h);
      assert.equal(preview.scale,scale);
      assert.deepEqual(preview.resizedSize,[Math.round(w*scale),Math.round(h*scale)]);
      assert.deepEqual(preview.offset,preview.resizedSize.map(n => Math.floor((size-n)/2)));
    }
    const references=[...provenance.references,...(provenance.generation.history??[]).flatMap(h=>h.references??[])];
    for(const ref of references) {
      assert.match(ref.sha256,/^[a-f0-9]{64}$/); assert.ok(ref.role);
      if(ref.path) {
        assert.match(ref.path,/^\.\.\/[a-z0-9_]+\/source\.png$/);
        const referenced=json(root+ref.path.split('/')[1]+'/asset.json');
        assert.equal(ref.sha256,referenced.files['source.png'].sha256);
      }
      if(ref.repositoryPath) assert.match(ref.repositoryPath,/^art\//);
      if(!ref.path&&!ref.repositoryPath) assert.ok(ref.availability);
    }
    for(const doc of [asset,provenance,review]) assert.doesNotMatch(JSON.stringify(doc),/\/workspace\/|\/home\/|exec-[0-9a-f-]+|"reviewer"|"requestId"/i);
  }
});
