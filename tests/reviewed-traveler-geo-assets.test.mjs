import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync, realpathSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { relative, isAbsolute, sep } from 'node:path';
import luaparse from 'luaparse';

const root = new URL('../', import.meta.url);
const base = 'art/cards/traveler-geo/';
const ids = ['armaments', 'heavy_blade'];
const editorCommit = '103025f9095d8089e3f9bf097f4d0c5fe039d546';
const files = ['source.png', 'prompt.txt', 'native-art.json', 'native-art.lua', 'preview-native.png'];
const frozen = {
  armaments: {
    'source.png': 'e63cd8703ce983eb1556efa31a017b803e31c7b887e9c3e14c77bd3ba9928332',
    'prompt.txt': '2e92f99d714ec5e50d4c02d941086ecaa189f7184e1d3071273e24e3845cf0d6',
    'native-art.json': '277afd4d54a2a6a2688205c81e29663ff3253d19df72759ead8621935f9a3e0a',
    'native-art.lua': 'b120cb5d4d30372611c539b69c8b04af1c8ea5feafbdb561c1eabb37443c8a04',
    'preview-native.png': 'b7b2cd9c4fdfa3f1d893156405a51afc8b8bd1b65a776a9f704086c97685b2ff',
  },
  heavy_blade: {
    'source.png': 'f396062d29b6845b58bf0043c1941a2219d9ca501ae6520c8579d555d73008d5',
    'prompt.txt': 'cc3d1e634a7c9cec0c91b7d03624f8d66f79136dead1bfc14ed8ef3e6f6ad677',
    'native-art.json': '337632a85aa0f1df9b9d077ecb919a67caa92d98175bda39d188c86ad418b2b2',
    'native-art.lua': 'db35c898e427d1487766484817384b190407d7cc46ec3a2212ee878db39e1e47',
    'preview-native.png': '6fefbbcbdaa503a1df1c04d282dc9f8cac0fdb36fb189e75aa89427b438b30b1',
  },
};
const originalLua = {
  armaments: { sha256: '1ab3309300aa54f75214aff4aafd41e0af604ab5909508209f71d246ab12e9b6', bytes: 350790, removedTrailingLf: 1 },
  heavy_blade: { sha256: '0f8ad60f1e7ff4d4d10fe4bb69b62297a92a5e268c1e13d471f9a4c4413ba54b', bytes: 624749, removedTrailingLf: 1 },
};
const counts = { armaments: [1834, 0], heavy_blade: [1476, 1] };
const text = bytes => bytes.toString('utf8').replace(/\r\n/g, '\n');
const digest = (bytes, path) => createHash('sha256').update(/\.(json|lua|txt)$/.test(path) ? text(bytes) : bytes).digest('hex');
const read = path => readFileSync(new URL(path, root));
const json = path => JSON.parse(text(read(path)));
const state = {
  runtimeBinding: 'unbound', officialImport: 'not-run', deviceXYZAndMasks: 'unverified',
  repeatedEntryCleanup: 'unverified', multiCardPerformance: 'not-run', phonePerformance: 'not-run',
  fullPoolApproval: 'not-approved',
};

// Same locked-luaparse literal-only approach as native-bloodletting-fine-strokes.
// Never execute Lua, render shapes, or treat the optional editor snapshot as truth.
function literal(node) {
  if (['NumericLiteral', 'BooleanLiteral'].includes(node.type)) return node.value;
  if (node.type === 'StringLiteral') return JSON.parse(node.raw);
  if (node.type === 'NilLiteral') return null;
  if (node.type === 'UnaryExpression' && node.operator === '-') return -literal(node.argument);
  assert.equal(node.type, 'TableConstructorExpression', 'drawing must contain literals');
  if (node.fields.every(field => field.type === 'TableValue')) return node.fields.map(field => literal(field.value));
  return Object.fromEntries(node.fields.map(field => {
    assert.ok(['TableKey', 'TableKeyString'].includes(field.type));
    return [field.type === 'TableKeyString' ? field.key.name : literal(field.key), literal(field.value)];
  }));
}

function drawing(source) {
  const bare = source.replace(/^-- MILIASTRA_EDITOR_SCENE_V1 .*$/gm, '');
  assert.ok(!bare.includes('MILIASTRA_EDITOR_SCENE_V1'));
  assert.doesNotMatch(bare, /data:image|iVBORw0KGgo|https?:\/\/|TEXTBOX_PREFAB_ID|local TEXTS\b/, 'no embedded bitmap, external resource, or static card text');
  const ast = luaparse.parse(bare, { luaVersion: '5.3' });
  const values = {};
  for (const name of ['ROOT', 'ELEMENTS', 'ROTATIONS', 'IMAGE_TYPES', 'IMAGE_MASKS', 'IMAGE_PREFAB_ID']) {
    const declarations = ast.body.filter(node => node.type === 'LocalStatement' && node.variables[0]?.name === name);
    assert.ok(declarations.length === 1 || (name === 'IMAGE_MASKS' && declarations.length === 0), `missing/duplicate literal ${name}`);
    values[name] = declarations.length ? literal(declarations[0].init[0]) : [];
  }
  assert.equal(values.IMAGE_PREFAB_ID, 0, 'export is not bound to a game template');
  assert.match(bare, /SetImage\(Enum\.ImageSource\.StaticReference, item\[1\]\)/);
  assert.match(bare, /function OnDestroy\(\)/, 'preserve upstream cleanup entry; not device cleanup evidence');
  return values;
}

function safePath(path) {
  assert.equal(typeof path, 'string');
  assert.ok(/^[a-z0-9_./-]+$/.test(path) && !path.startsWith('/') && !path.split('/').some(part => part === '..' || part === '' || part === '.'), 'asset path must stay inside catalog directory');
  return path;
}

function validateCatalog(catalog) {
  assert.equal(catalog.schemaVersion, 1);
  assert.deepEqual(catalog.runtime, { status: 'unbound', fallback: 'placeholder-type-icon' });
  assert.deepEqual(Object.keys(catalog.cards), ids, 'only explicitly approved card IDs');
  for (const id of ids) assert.equal(safePath(catalog.cards[id]), `${id}/asset.json`, 'explicit card_id to relative metadata path');
}

function pngDimensions(bytes) {
  assert.ok(bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10])), 'PNG signature');
  assert.equal(bytes.subarray(12, 16).toString(), 'IHDR');
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}

function loadAsset(id) {
  const metadata = json(`${base}${id}/asset.json`);
  const bytes = Object.fromEntries(files.map(name => [name, read(`${base}${id}/${name}`)]));
  return { metadata, bytes };
}

function validateDrawing(id, scene, lua, metadata) {
  const actual = drawing(lua);
  assert.deepEqual([scene.canvas.width, scene.canvas.height], [144, 64], 'editable canvas');
  assert.deepEqual(scene.library.savedItems, [], 'no hidden embedded image resources');
  assert.doesNotMatch(JSON.stringify(scene), /data:image|iVBORw0KGgo/);
  assert.deepEqual(actual.ROOT, [0,0,144,64,0.5,0.5,0.5,0.5,0.5,0.5,1,1,0], 'literal canvas');
  assert.equal(scene.elements.length, counts[id][0]);
  assert.equal(actual.ELEMENTS.length, scene.elements.length, 'literal image count');
  assert.equal(actual.ROTATIONS.length, scene.elements.length);
  assert.equal(actual.IMAGE_TYPES.length, scene.elements.length);
  assert.ok(actual.IMAGE_TYPES.every(type => ['basic', 'stretch'].includes(type)), 'pinned editor image types only');
  assert.ok(actual.IMAGE_MASKS.length === 0 || actual.IMAGE_MASKS.length === scene.elements.length);
  const maskIndices = scene.elements.flatMap((element, i) => element.luaMask?.enabled ? [i] : []);
  assert.deepEqual(actual.IMAGE_MASKS.flatMap((mask, i) => mask.enabled ? [i] : []), maskIndices, 'literal mask positions');
  assert.equal(maskIndices.length, counts[id][1], 'literal mask count');
  assert.deepEqual(maskIndices, id === 'heavy_blade' ? [1396] : []);
  let galleryControls = 0;
  scene.elements.forEach((element, i) => {
    assert.ok(['rectangle', 'ellipse', 'triangle', 'image'].includes(element.type), 'no text elements');
    assert.equal(element.textBox, null);
    assert.equal(element.prefabId, null);
    assert.equal(element.prefabVariable, null);
    const expectedId = {rectangle:100001, ellipse:100002, triangle:100003}[element.type] ?? element.imageAssetId;
    assert.ok([100001,100002,100003,106056,106057].includes(expectedId), 'only declared native gallery IDs');
    const row = actual.ELEMENTS[i];
    assert.equal(row.length, 18);
    assert.equal(row[0], expectedId, `image ${i}`);
    assert.equal(actual.IMAGE_TYPES[i], element.type === 'image' ? element.imageType : 'stretch', `image type ${i}`);
    if (element.type === 'image') galleryControls++;
    const editable = [element.x-72, 32-element.y, element.width, element.height, element.rotationX, element.rotationY, element.rotation];
    const exported = [...row.slice(1,5), ...actual.ROTATIONS[i], row[13]];
    editable.forEach((value, j) => assert.ok(Math.abs(value-exported[j]) < 0.0001, `literal geometry ${i}/${j}`));
    assert.deepEqual(row.slice(5,13), [0.5,0.5,0.5,0.5,0.5,0.5,1,1]);
    const rgb = element.color.match(/^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
    assert.ok(rgb);
    assert.deepEqual(row.slice(14,18), [...rgb.slice(1).map(part => parseInt(part,16)), Math.round(element.opacity*255)], `RGBA ${i}`);
    if (element.luaMask?.enabled) assert.deepEqual(actual.IMAGE_MASKS[i], Object.fromEntries(Object.entries(element.luaMask).filter(([, value]) => value !== null)), 'exact authored mask declaration');
  });
  assert.deepEqual(metadata.controls, { images: counts[id][0], masks: counts[id][1], artworkTotal: counts[id][0]+counts[id][1], nativeGalleryImages: galleryControls, text: 0, hostIncluded: false });
  assert.equal(galleryControls, 3);
  assert.deepEqual(metadata.mask, { imageIndices: maskIndices, canvasEditorMask: 'editor-only-not-an-extra-runtime-control', deviceValidation: 'unverified' });
  return actual;
}

function validateAsset(id, { metadata, bytes }) {
  assert.equal(metadata.schemaVersion, 1);
  assert.equal(metadata.card_id, id, 'correct card_id');
  assert.deepEqual(Object.keys(metadata.files), files);
  for (const name of files) {
    const record = metadata.files[name];
    assert.equal(safePath(record.path), `${id}/${name}`);
    assert.ok(Buffer.isBuffer(bytes[name]), `missing resource ${name}`);
    assert.equal(record.sha256, digest(bytes[name], name), `resource hash ${name}`);
    assert.equal(record.sha256, frozen[id][name], `frozen reviewed bytes ${id}/${name}`);
    // Text hashes/counts use repository LF text; original Lua bytes are recorded separately.
    assert.equal(record.bytes, /\.(json|lua|txt)$/.test(name) ? Buffer.byteLength(text(bytes[name])) : bytes[name].length, `resource bytes ${name}`);
  }
  assert.deepEqual(pngDimensions(bytes['source.png']), [1881,836], 'actual source dimensions');
  assert.deepEqual(pngDimensions(bytes['preview-native.png']), [576,256], 'actual 4x preview dimensions');
  assert.deepEqual(metadata.sourceSize, [1881,836]);
  assert.deepEqual(metadata.nativeSize, [144,64]);
  assert.deepEqual(metadata.previewSize, [576,256]);
  assert.deepEqual(metadata.adaptation, { mode: 'contain', scale: 144/1881, offset: [0,0], crop: null, stretch: false });
  assert.equal(metadata.generation.tool, 'builtin imagegen');
  assert.equal(metadata.toolchain.editorCommit, editorCommit);
  assert.deepEqual(metadata.validation, state);
  assert.deepEqual(metadata.approval, { date: '2026-10-27', status: 'owner-reviewed-offline-visual', scope: ['source-design','native-redraw','full-card-offline-preview'], productionRuntimeApproved: false });
  assert.equal(metadata.runtimeFallback, 'placeholder-type-icon');
  assert.deepEqual(metadata.fullCardAssembly, { oneXArtPixels: 'matched-offline', fourXExactPixels: 'failed-quantization-difference', fourXChangedPixels: id === 'armaments' ? 25 : 47, thresholdRelaxed: false, cardTextIncludedInAsset: false });
  assert.deepEqual(metadata.preview, { kind: 'literal-lua-readback', scale: 4, editorSnapshotUsed: false, officialClient: false });
  assert.ok(text(bytes['prompt.txt']).startsWith('Use case: stylized-concept.'));
  assert.doesNotMatch(JSON.stringify(metadata), /\/workspace\/|\/home\/|Sentinel_|file_[a-z0-9]|library_id|agent_name/i, 'no private execution identifiers');
  validateDrawing(id, JSON.parse(text(bytes['native-art.json'])), text(bytes['native-art.lua']), metadata);
}

test('reviewed asset catalog exists independently from legacy candidates and runtime theme', () => {
  assert.ok(existsSync(new URL(`${base}catalog.json`, root)), 'reviewed formal source catalog is missing');
  const catalog = json(`${base}catalog.json`);
  validateCatalog(catalog);
  const theme = json('data/presentation/ui_theme.json');
  for (const id of ids) assert.equal(theme.icon.cardPortraits[id], undefined, 'do not masquerade as a native image binding');
  const directory = realpathSync(new URL(base, root));
  for (const id of ids) assert.deepEqual(readdirSync(new URL(`${base}${id}/`, root)).sort(), ['asset.json', ...files].sort(), 'only reviewed resource set, no full-card or third-party originals');
  for (const id of ids) for (const name of ['asset.json', ...files]) {
    const path = relative(directory, realpathSync(new URL(`${base}${id}/${name}`, root)));
    assert.ok(!isAbsolute(path) && !path.startsWith(`..${sep}`), 'no escaped symlink resource');
  }
});

for (const id of ids) test(`${id}: frozen source, prompt, native tables, preview and metadata are coherent`, () => validateAsset(id, loadAsset(id)));

test('new metadata and assets have real LF-canonical legal inventory hashes', () => {
  const legal = json('docs/legal/assets.json');
  for (const path of [`${base}catalog.json`, ...ids.flatMap(id => ['asset.json', ...files.filter(name => name !== 'prompt.txt')].map(name => `${base}${id}/${name}`))]) {
    assert.ok(legal.files[path], `missing legal record ${path}`);
    assert.equal(legal.files[path].category, path.endsWith('.lua') ? 'editor-runtime' : 'game-ip-ai-redraw');
    assert.equal(legal.files[path].sha256, digest(read(path), path), `legal hash ${path}`);
  }
});

test('negative controls reject wrong IDs, escaping paths, hashes, dimensions and missing resources', () => {
  for (const mutate of [c => { c.cards.wrong_card = c.cards.armaments; delete c.cards.armaments; }, c => { c.cards.armaments = '../armaments/asset.json'; }, c => { c.runtime.status = 'bound'; }]) {
    const catalog = structuredClone(json(`${base}catalog.json`)); mutate(catalog); assert.throws(() => validateCatalog(catalog));
  }
  for (const [mutate, reason] of [
    [b => { b.metadata.card_id = 'cleave'; }, /correct card_id/],
    [b => { b.metadata.files['source.png'].sha256 = '0'.repeat(64); }, /resource hash/],
    [b => { b.metadata.nativeSize[1] = 34; }, /64/],
    [b => { delete b.bytes['preview-native.png']; }, /missing resource/],
    [b => { b.metadata.sourceSize[0] = 2304; }, /1881/],
    [b => { b.metadata.controls.masks = 0; }, /masks/],
    [b => { b.metadata.validation.repeatedEntryCleanup = 'passed'; }, /unverified/],
    [b => { b.metadata.files['native-art.lua'].path = '../native-art.lua'; }, /inside catalog/],
  ]) { const bundle = loadAsset('heavy_blade'); mutate(bundle); assert.throws(() => validateAsset('heavy_blade', bundle), reason); }
});

test('a retained editor snapshot cannot hide corrupt real Lua geometry, mask or gallery ID', () => {
  const bundle = loadAsset('heavy_blade');
  const scene = JSON.parse(text(bundle.bytes['native-art.json']));
  const original = text(bundle.bytes['native-art.lua']);
  // Frozen Lua omits the optional snapshot. Add an unchanged editor-format scene
  // comment to exercise the tempting stale-snapshot fallback without editing assets.
  const snapshot = `\n-- MILIASTRA_EDITOR_SCENE_V1 ${Buffer.from(JSON.stringify({ version: 1, scene })).toString('base64')}\n`;
  validateDrawing('heavy_blade', scene, original+snapshot, bundle.metadata);
  for (const [mutant, reason] of [
    [original.replace('{100001,0.0,0.0,144.0,64.0,', '{100001,1.0,0.0,144.0,64.0,'), /literal geometry/],
    [original.replace('{106057,', '{999999,'), /image /],
    [original.replace('["enabled"]=true', '["enabled"]=false'), /literal mask positions/],
    [original.replace('["offsetX"]=43.0', '["offsetX"]=44.0'), /exact authored mask/],
    [original.replace('local ROOT = {0,0,144.0,64.0,', 'local ROOT = {0,0,144.0,34.0,'), /literal canvas/],
  ]) { assert.notEqual(mutant, original); assert.throws(() => validateDrawing('heavy_blade', scene, mutant+snapshot, bundle.metadata), reason); }
});

test('LF-canonical frozen text hashes survive a CRLF checkout without rewriting sources', () => {
  for (const id of ids) {
    const bundle = loadAsset(id);
    for (const name of files.filter(name => /\.(json|lua|txt)$/.test(name))) bundle.bytes[name] = Buffer.from(text(bundle.bytes[name]).replace(/\n/g, '\r\n'));
    validateAsset(id, bundle);
  }
});

for (const id of ids) test(`${id}: Lua EOF normalization preserves the recoverable original export and AST`, () => {
  const canonical = text(read(`${base}${id}/native-art.lua`));
  assert.ok(/[^\n]\n$/.test(canonical), 'exactly one final LF; no extra EOF blank line');
  const record = json(`${base}${id}/asset.json`).files['native-art.lua'];
  assert.deepEqual(record.originalExport, originalLua[id], 'retain raw export provenance and exact removed bytes');
  const restored = canonical + '\n'.repeat(record.originalExport.removedTrailingLf);
  assert.equal(Buffer.byteLength(restored), record.originalExport.bytes);
  assert.equal(digest(Buffer.from(restored), 'raw'), record.originalExport.sha256, 'canonical plus removed LF restores raw export bytes');
  assert.deepEqual(luaparse.parse(canonical, { luaVersion: '5.3' }), luaparse.parse(restored, { luaVersion: '5.3' }), 'all Lua AST nodes unchanged');
  assert.deepEqual(drawing(canonical), drawing(restored), 'all real drawing tables unchanged');
});
