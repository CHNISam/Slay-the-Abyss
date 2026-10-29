import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const read = path => readFileSync(new URL(`../${path}`, import.meta.url));
const json = path => JSON.parse(read(path));
const hash = data => createHash('sha256').update(data).digest('hex');
const root = 'art/cards/traveler-geo/';

test('illustration candidates preserve identity, source bytes and unbound acceptance', () => {
  const catalog = json(root + 'catalog.json');
  const classIds = new Set(json('data/reference/warrior75.json').cards.map(card => card.id));
  const cards = new Map(json('data/cards.json').cards.map(card => [card.id, card]));
  const legal = json('docs/legal/assets.json');
  assert.equal(catalog.runtime.status, 'unbound');
  assert.deepEqual(Object.keys(catalog.cards).sort(), ['armaments', 'cleave', 'heavy_blade']);
  assert.equal(Object.keys(catalog.candidates).length, 72);
  assert.deepEqual([...Object.keys(catalog.cards), ...Object.keys(catalog.candidates)].sort(),
    [...classIds].sort(), 'all 75 class cards must have exactly one source entry');
  const review = json(root + 'source-design-review.json');
  assert.equal(review.records.length, 72);
  assert.deepEqual(review.records.map(record => record.cardId).sort(), Object.keys(catalog.candidates).sort());
  for (const record of review.records) {
    const asset = json(root + catalog.candidates[record.cardId]);
    assert.equal(record.verdict, 'PASS');
    assert.equal(record.reviewedFullSource, true);
    assert.equal(record.reviewed144x64, true);
    assert.equal(record.sourceSha256, asset.files['source.png'].sha256);
    const preview = asset.files['preview-contain-144x64.png'] ?? asset.files['preview-source-144x64.png'];
    assert.equal(record.previewPath, root + preview.path);
    assert.equal(record.previewSha256, preview.sha256);
  }
  for (const [id, path] of Object.entries(catalog.candidates ?? {})) {
    assert.ok(classIds.has(id), id);
    assert.equal(catalog.cards[id], undefined, 'candidate cannot replace an approved source');
    assert.equal(path, `${id}/asset.json`);
    const asset = json(root + path);
    assert.equal(asset.card_id, id);
    assert.equal(asset.assetRole, 'candidate-source-asset');
    assert.equal(asset.productionRuntimeApproved, false);
    assert.equal(asset.review.ownerVisualApproval, false);
    assert.equal(asset.review.runtime, 'unbound');
    for (const key of ['officialImport', 'PC', 'Android']) assert.equal(asset.review[key], 'not-run');
    assert.equal(asset.review.performance, 'not-measured');
    assert.deepEqual(asset.nativeTargetSize, [144, 64]);
    assert.equal(asset.adaptation.mode, 'contain');
    assert.equal(asset.adaptation.crop, null);
    assert.equal(asset.adaptation.stretch, false);
    assert.ok(asset.sourceSize.every(value => Number.isSafeInteger(value) && value > 0));
    const [width, height] = asset.sourceSize;
    const scale = Math.min(144 / width, 64 / height);
    assert.equal(asset.adaptation.scale, scale);
    assert.deepEqual(asset.adaptation.offset, [(144 - width * scale) / 2, (64 - height * scale) / 2]);
    // This is a generation-time brief, not a balance lock on number-free artwork.
    assert.equal(asset.ruleSource.path, 'data/cards.json');
    assert.equal(asset.ruleSource.cardId, id);
    assert.match(asset.ruleSource.sha256, /^[0-9a-f]{64}$/);
    assert.ok(Array.isArray(asset.ruleSource.effects) && asset.ruleSource.effects.length > 0);
    assert.ok(asset.ruleSource.effects.every(effect => typeof effect.op === 'string'));
    assert.equal(asset.ruleSource.target, cards.get(id).target);
    for (const required of ['source.png', 'prompt.txt', 'generation-provenance.json']) {
      assert.ok(asset.files[required], `${id}: missing ${required}`);
    }
    assert.ok(asset.files['preview-contain-144x64.png'] || asset.files['preview-source-144x64.png'],
      `${id}: missing actual-size review preview`);
    for (const [name, record] of Object.entries(asset.files)) {
      assert.equal(record.path, `${id}/${name}`);
      const bytes = read(root + record.path);
      const pointer = Buffer.from(`version https://git-lfs.github.com/spec/v1\noid sha256:${record.sha256}\nsize ${record.bytes}\n`);
      if (name === 'source.png' && bytes.equals(pointer)) {
        const entry = legal.files[root + record.path];
        assert.equal(entry.lfs, true);
        assert.equal(entry.sha256, record.sha256);
        assert.equal(entry.bytes, record.bytes);
        continue; // Content identity only; pixel inspection used materialized local bytes.
      }
      const canonical = /\.(json|txt)$/.test(name) ? Buffer.from(bytes.toString().replaceAll('\r\n', '\n')) : bytes;
      assert.equal(hash(canonical), record.sha256, record.path);
      assert.equal(canonical.length, record.bytes, record.path);
      if (name === 'source.png' || name.startsWith('preview-')) {
        assert.deepEqual([...bytes.subarray(0, 8)], [137,80,78,71,13,10,26,10]);
        assert.deepEqual([bytes.readUInt32BE(16), bytes.readUInt32BE(20)],
          name === 'source.png' ? asset.sourceSize : [144, 64]);
      }
    }
  }
});
