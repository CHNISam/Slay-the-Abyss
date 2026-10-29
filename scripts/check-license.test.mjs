import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { checkDependencies, checkAssets, digest, sensitive } from './check-license.mjs';

const component = (licenses = ['MIT'], version = '1.0.0') => ({version,
  properties: [{name:'cdx:npm:package:path',value:'node_modules/example'}],
  licenses: licenses.map(id => ({license:{id}}))});
const expected = {'node_modules/example':{version:'1.0.0',licenses:['MIT']}};

test('new, removed, unknown, changed and conflicting dependency licenses require review', () => {
  assert.deepEqual(checkDependencies({components:[component()]}, expected), []);
  const npm11 = {...component(),name:'example'};
  delete npm11.properties;
  assert.deepEqual(checkDependencies({components:[npm11]}, expected), []);
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
    mkdirSync(join(root,'art'));
    for (const extension of ['json','lua','svg']) {
      const path = `art/generated.${extension}`;
      writeFileSync(join(root,path),'text\r\n');
      const textInventory = {categories:inventory.categories, files:{[path]:{
        category:'unknown',sha256:digest(Buffer.from('text\n'),true)}}};
      assert.deepEqual(checkAssets(root,[path],textInventory),[]);
      writeFileSync(join(root,path),'changed\n');
      assert.ok(checkAssets(root,[path],textInventory).length);
    }
  } finally { rmSync(root,{recursive:true,force:true}); }
});

test('Lua generated runtime is reviewed even without an image; platform binaries and fonts are covered', () => {
  for (const path of ['art/cards/shared/frame-basic.lua','docs/experiments/art-portrait/portrait-64.lua',
    'new.gil','new.gia','new.mp3','new.ttf','new.glb','new.PNG']) assert.ok(sensitive(path),path);
  assert.equal(sensitive('scripts/build-ui.mjs'),false);
  assert.equal(digest(Buffer.from('a\r\nb'),true),digest(Buffer.from('a\nb'),true));
  assert.notEqual(digest(Buffer.from('a\r\nb')),digest(Buffer.from('a\nb')));
});

test('opted-in source LFS pointers authenticate identity while real source bytes remain checked', t => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-license-lfs-'));
  t.after(() => rmSync(root,{recursive:true,force:true}));
  const path = 'art/cards/traveler-geo/strike/source.png';
  mkdirSync(join(root,'art/cards/traveler-geo/strike'),{recursive:true});
  const source = Buffer.from('source image bytes');
  const entry = {category:'unknown',sha256:digest(source),bytes:source.length,lfs:true};
  const inventory = {categories:{unknown:{status:'unresolved'}},files:{[path]:entry}};
  const pointer = `version https://git-lfs.github.com/spec/v1\noid sha256:${entry.sha256}\nsize ${entry.bytes}\n`;
  const check = bytes => {
    writeFileSync(join(root,path),bytes);
    return checkAssets(root,[path],inventory);
  };
  assert.deepEqual(check(pointer),[]);
  assert.deepEqual(check(source),[]);
  for (const changed of [Buffer.alloc(source.length), Buffer.concat([source,Buffer.from('!')]),
    pointer.replace(entry.sha256,'0'.repeat(64)), pointer.replace(`size ${entry.bytes}`,`size ${entry.bytes+1}`),
    pointer.replaceAll('\n','\r\n'), pointer+'\n', pointer+'extra', pointer.slice(0,-1),
    pointer.replace(`size ${entry.bytes}`,`size 0${entry.bytes}`),
    pointer.replace(`size ${entry.bytes}`,'size 9007199254740992'),
    pointer.replace('sha256:','sha512:'), pointer.replace(entry.sha256,entry.sha256.toUpperCase())]) {
    assert.ok(check(changed).length, `reject changed source/pointer ${String(changed)}`);
  }
  for (const bytes of [0,-1,1.5,Number.MAX_SAFE_INTEGER+1,String(source.length),undefined]) {
    entry.bytes=bytes;
    assert.ok(check(pointer).length,'reject invalid registered size');
    assert.ok(check(source).length,'invalid metadata also rejects real source');
  }
  entry.bytes=source.length+1;
  assert.ok(check(source).length,'real bytes must match registered size as well as digest');
  entry.bytes=source.length;
  delete entry.lfs;
  assert.ok(check(pointer).length,'ordinary records retain real-byte-only verification');
  assert.deepEqual(check(source),[]);
  entry.lfs=true;
  entry.category='invented';
  assert.ok(check(pointer).length);
  delete inventory.files[path];
  assert.ok(check(pointer).length,'unregistered pointers require provenance review');
});

test('LFS source identity opt-in cannot broaden to other assets or replace old reviewed PNG checks', t => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-license-lfs-scope-'));
  t.after(() => rmSync(root,{recursive:true,force:true}));
  const source = Buffer.from('source bytes');
  const entry = {category:'unknown',sha256:digest(source),bytes:source.length,lfs:true};
  const pointer = `version https://git-lfs.github.com/spec/v1\noid sha256:${entry.sha256}\nsize ${entry.bytes}\n`;
  for (const path of ['picture.png','art/cards/traveler-geo/strike/preview-native.png',
    'art/cards/traveler-geo/Strike/source.png','art/cards/other/strike/source.png']) {
    mkdirSync(join(root,path,'..'),{recursive:true});
    const inventory = {categories:{unknown:{}},files:{[path]:entry}};
    for (const bytes of [pointer,source]) {
      writeFileSync(join(root,path),bytes);
      assert.ok(checkAssets(root,[path],inventory).length,`reject out-of-scope opt-in ${path}`);
    }
  }
  for (const id of ['armaments','cleave','heavy_blade']) for (const name of ['source.png','preview-native.png']) {
    const path = `art/cards/traveler-geo/${id}/${name}`;
    mkdirSync(join(root,path,'..'),{recursive:true});
    writeFileSync(join(root,path),pointer);
    const ordinary = {category:entry.category,sha256:entry.sha256};
    assert.ok(checkAssets(root,[path],{categories:{unknown:{}},files:{[path]:ordinary}}).length,
      `old reviewed PNG still needs materialization: ${path}`);
    for (const bytes of [pointer, source]) {
      writeFileSync(join(root,path),bytes);
      assert.ok(checkAssets(root,[path],{categories:{unknown:{}},files:{[path]:entry}}).length,
        `old reviewed PNG cannot opt into candidate identity checks: ${path}`);
    }
  }
});

test('explicit raster LFS records bind canonical pointers without claiming payload materialization', () => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-license-lfs-'));
  const bytes = Buffer.from('reviewed image bytes'), sha256 = digest(bytes);
  const pointer = `version https://git-lfs.github.com/spec/v1\noid sha256:${sha256}\nsize ${bytes.length}\n`;
  const record = {category:'unknown',sha256,lfsBytes:bytes.length};
  const inventory = {categories:{unknown:{status:'unresolved'}},files:{'picture.png':record}};
  const check = value => { writeFileSync(join(root,'picture.png'),value); return checkAssets(root,['picture.png'],inventory); };
  try {
    assert.deepEqual(check(pointer),[]);
    assert.deepEqual(check(bytes),[]);
    const changed=Buffer.from(bytes);changed[changed.length-1]^=1;
    assert.ok(check(changed).length,'same-size payload still requires the reviewed SHA');
    for (const bad of [pointer.replace(sha256,'0'.repeat(64)), pointer.replace(`size ${bytes.length}`, 'size 1'),
      `\ufeff${pointer}`, `${pointer}extra\n`, `${pointer}\n`, pointer.replace('size ', 'size 0'), pointer.trimEnd(),
      pointer.replace('oid sha256:', 'oid sha256:bad'), pointer.replace(/\n/g,'\r\n'), 'arbitrary text']) {
      assert.ok(check(bad).length, 'invalid pointer or payload must fail');
    }
    for (const size of [0,-1,1.5,Number.MAX_SAFE_INTEGER+1,`${bytes.length}`,bytes.length+1]) {
      record.lfsBytes = size;
      assert.ok(check(pointer).length);
      assert.ok(check(bytes).length);
    }
    delete record.lfsBytes;
    assert.ok(check(pointer).length, 'undeclared LFS pointer is not a reviewed image');
  } finally { rmSync(root,{recursive:true,force:true}); }
});

test('missing reviewed assets return provenance errors rather than throwing', t => {
  const root = mkdtempSync(join(tmpdir(), 'abyss-license-missing-'));
  t.after(() => rmSync(root, {recursive:true, force:true}));
  for (const extra of [{}, {lfs:true,bytes:1}, {lfsBytes:1}]) {
    const path = 'art/cards/traveler-geo/strike/source.png';
    const inventory = {categories:{unknown:{}},files:{[path]:{category:'unknown',sha256:'0'.repeat(64),...extra}}};
    assert.deepEqual(checkAssets(root,[path],inventory), [`Changed asset/runtime needs provenance review: ${path}`]);
  }
});
