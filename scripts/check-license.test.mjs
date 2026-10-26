import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { checkDependencies, checkAssets, digest, sensitive } from './check-license.mjs';

const component = (licenses = ['MIT'], version = '1.0.0') => ({version,
  properties: [{name:'cdx:npm:package:path',value:'node_modules/example'}],
  licenses: licenses.map(id => ({license:{id}}))});
const expected = {'node_modules/example':{version:'1.0.0',licenses:['MIT']}};

test('new, removed, unknown, changed and conflicting dependency licenses require review', () => {
  assert.deepEqual(checkDependencies({components:[component()]}, expected), []);
  for (const components of [[], [component([])], [component(['GPL-3.0-only'])],
    [component(['MIT','GPL-3.0-only'])], [component(['MIT'],'2.0.0')]]) {
    assert.ok(checkDependencies({components}, expected).length);
  }
  assert.ok(checkDependencies({components:[component()]}, {}).length);
});

test('asset gate detects additions, byte changes, missing provenance and deleted records', () => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-license-'));
  try {
    writeFileSync(join(root,'picture.png'), 'image bytes');
    const inventory = {categories:{unknown:{status:'unresolved'}},files:{'picture.png':{
      category:'unknown',sha256:digest(Buffer.from('image bytes'))}}};
    assert.deepEqual(checkAssets(root,['picture.png'],inventory),[]);
    assert.ok(checkAssets(root,['picture.png','new.woff2'],inventory).length);
    writeFileSync(join(root,'picture.png'), 'changed image');
    assert.ok(checkAssets(root,['picture.png'],inventory).length);
    assert.ok(checkAssets(root,[],inventory).length);
    inventory.files['picture.png'].category='invented';
    assert.ok(checkAssets(root,['picture.png'],inventory).length);
  } finally { rmSync(root,{recursive:true,force:true}); }
});

test('Lua generated runtime is reviewed even without an image; platform binaries and fonts are covered', () => {
  for (const path of ['art/cards/shared/frame-basic.lua','docs/experiments/art-portrait/portrait-64.lua',
    'new.gil','new.gia','new.mp3','new.ttf','new.glb','new.PNG']) assert.ok(sensitive(path),path);
  assert.equal(sensitive('scripts/build-ui.mjs'),false);
  assert.equal(digest(Buffer.from('a\r\nb'),true),digest(Buffer.from('a\nb'),true));
  assert.notEqual(digest(Buffer.from('a\r\nb')),digest(Buffer.from('a\nb')));
});
