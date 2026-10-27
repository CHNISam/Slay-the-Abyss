import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import luaparse from 'luaparse';

const root = new URL('../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8').replace(/\r\n/g, '\n');
const json = path => JSON.parse(read(path));
const sha256 = text => createHash('sha256').update(text).digest('hex');
const base = 'art/cards/geo-samples/';
const fixture = json('tests/fixtures/native-bloodletting-fine-strokes.json');
const scene = json(`${base}bloodletting/native-art.json`);
const layout = json(`${base}native-layout.json`);
const legal = json('docs/legal/assets.json');

// Parse only literal drawing tables, never execute exporter code or trust its
// embedded editor snapshot. luaparse is an existing locked test dependency.
function literal(node) {
  if (['NumericLiteral', 'BooleanLiteral'].includes(node.type)) return node.value;
  if (node.type === 'StringLiteral') return JSON.parse(node.raw);
  if (node.type === 'NilLiteral') return null;
  if (node.type === 'UnaryExpression' && node.operator === '-') return -literal(node.argument);
  assert.equal(node.type, 'TableConstructorExpression', 'drawing must contain literal values');
  if (node.fields.every(field => field.type === 'TableValue')) return node.fields.map(field => literal(field.value));
  return Object.fromEntries(node.fields.map(field => {
    assert.ok(['TableKey', 'TableKeyString'].includes(field.type));
    return [field.type === 'TableKeyString' ? field.key.name : literal(field.key), literal(field.value)];
  }));
}

function drawing(source) {
  const bare = source.replace(/^-- MILIASTRA_EDITOR_SCENE_V1 .*$/gm, '');
  assert.ok(!bare.includes('MILIASTRA_EDITOR_SCENE_V1'));
  const ast = luaparse.parse(bare, { luaVersion: '5.3' });
  return Object.fromEntries(['ROOT', 'ELEMENTS', 'ROTATIONS', 'IMAGE_MASKS'].map(name => {
    const declaration = ast.body.find(node => node.type === 'LocalStatement' && node.variables[0]?.name === name);
    assert.ok(declaration, `missing literal ${name}`);
    return [name, literal(declaration.init[0])];
  }));
}

const actual = drawing(read(`${base}bloodletting/native-art.lua`));
const rad = value => value * Math.PI / 180;

function projectedEdges(row, xy) {
  // Independent transcription of the documented pinned-editor Y-up policy
  // Ry * Rx * Rz. This is NOT evidence for official-client mixed XYZ rendering.
  const [rx, ry, rz] = [xy[0], xy[1], row[13]].map(rad);
  const [cx, sx, cy, sy, cz, sz] = [Math.cos(rx), Math.sin(rx), Math.cos(ry), Math.sin(ry), Math.cos(rz), Math.sin(rz)];
  return [(cy*cz+sy*sx*sz)*row[3], cx*sz*row[3],
    (-cy*sz+sy*sx*cz)*row[4], cx*cz*row[4]];
}

function authored(stroke) {
  const scale = 144 / 2048;
  const [p,q] = stroke.sourceEndpoints;
  const dx = (q[0]-p[0])*scale, dy = -(q[1]-p[1])*scale;
  const length = Math.hypot(dx,dy);
  return {
    // Source P() adds8; 34-high crop subtracts15; native origin is center/Y-up.
    center: [(p[0]+q[0])*scale/2-72, 24-(p[1]+q[1])*scale/2],
    edges: [dx,dy,-dy/length*stroke.thickness,dx/length*stroke.thickness],
  };
}

function assertStroke(data, stroke) {
  const row = data.ELEMENTS[stroke.index], xy = data.ROTATIONS[stroke.index];
  assert.equal(row[0],100001, `${stroke.name}: still a native rectangle`);
  const expected = authored(stroke);
  for (const [i,value] of projectedEdges(row,xy).entries()) {
    assert.ok(Math.abs(value-expected.edges[i]) < 0.002,
      `${stroke.name}: source-intent edge ${i}: ${value} != ${expected.edges[i]}`);
  }
  expected.center.forEach((value,i) => assert.ok(Math.abs(row[i+1]-value)<0.002, `${stroke.name}: center`));
}

const stable = value => Array.isArray(value) ? value.map(stable) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key,stable(value[key])])) : value;

function preservedSceneDigest(value) {
  const keep = structuredClone(value);
  for (const stroke of fixture.strokes) {
    for (const key of ['width','height','rotation','rotationX','rotationY']) delete keep.elements[stroke.index][key];
  }
  return sha256(JSON.stringify(stable(keep)));
}

function preservedDrawingDigest(value) {
  const keep = structuredClone(value);
  for (const stroke of fixture.strokes) {
    for (const index of [3,4,13]) keep.ELEMENTS[stroke.index][index] = null;
    keep.ROTATIONS[stroke.index] = null;
  }
  return sha256(JSON.stringify(stable(keep)));
}

for (const stroke of fixture.strokes) {
  test(`Bloodletting source-intent stroke survives literal Lua: ${stroke.name}`, () => {
    assertStroke(actual, stroke);
    const element = scene.elements[stroke.index], row = actual.ELEMENTS[stroke.index];
    const editable = [element.x-72,17-element.y,element.width,element.height,
      element.rotationX,element.rotationY,element.rotation];
    const exported = [...row.slice(1,5),...actual.ROTATIONS[stroke.index],row[13]];
    editable.forEach((value,index) => assert.ok(Math.abs(value-exported[index])<0.002,
      `${stroke.name}: editable JSON must retain the same geometry as actual Lua`));
  });
}

test('all19 actual pre-fix clamped records fail the same source-intent oracle', () => {
  assert.equal(fixture.strokes.length,19);
  const negative = structuredClone(actual);
  for (const stroke of fixture.strokes) {
    assert.equal(scene.elements[stroke.index].name, stroke.name);
    negative.ELEMENTS[stroke.index] = stroke.originalClampedRow;
    negative.ROTATIONS[stroke.index] = stroke.originalClampedXY;
    assert.equal(stroke.originalClampedRow[4],1);
    assert.deepEqual(stroke.originalClampedXY,[0,0]);
  }
  for (const stroke of fixture.strokes) assert.throws(() => assertStroke(negative,stroke), /source-intent edge/);
});

test('precision repair preserves all other geometry, palette, masks and JSON metadata', () => {
  assert.equal(scene.elements.length,138);
  assert.equal(actual.ELEMENTS.length,138);
  assert.equal(actual.ROTATIONS.length,138);
  assert.equal(actual.IMAGE_MASKS.length,138);
  assert.equal(actual.IMAGE_MASKS.filter(mask => mask.enabled).length,3);
  assert.equal(preservedSceneDigest(scene),fixture.preservedSceneSha256);
  assert.equal(preservedDrawingDigest(actual),fixture.preservedDrawingSha256);
});

test('four current literal Lua samples drive every slot in the frozen138-capacity143-control pool', () => {
  const ids = ['heavy_blade','bloodletting','iron_wave','shockwave'];
  assert.deepEqual(Object.keys(layout.samples),ids, 'explicit card_id mapping; no positional fallback');
  assert.equal(layout.capacity,138);
  assert.equal(sha256(JSON.stringify(stable(layout.pool))),fixture.unchangedPoolSha256);
  assert.equal(sha256(JSON.stringify(stable(layout.samples.heavy_blade))),fixture.unchangedHeavyLayoutSha256);
  const count = node => 1+(node.children??[]).reduce((sum,child)=>sum+count(child),0);
  assert.equal(count(layout.pool),143);
  for (const name of ids) {
    const source = `${base}${name}/native-art.lua`;
    const data = drawing(read(source)), sample = layout.samples[name];
    const counts = {heavy_blade:[125,17],bloodletting:[138,3],iron_wave:[138,5],shockwave:[123,43]};
    assert.deepEqual([sample.sourceCounts.images,sample.sourceCounts.masks],counts[name]);
    assert.deepEqual(sample.source,{path:source,sha256:sha256(read(source))}, 'source is actual current export (LF canonical bytes)');
    assert.equal(sample.slots.length,138);
    assert.deepEqual(sample.sourceCounts,{images:data.ELEMENTS.length,masks:data.IMAGE_MASKS.filter(mask=>mask.enabled).length});
    data.ELEMENTS.forEach((row,index) => assert.deepEqual(sample.slots[index],{
      path:['clip',`group${String(Math.floor(index/60)).padStart(3,'0')}`,`shape${String(index).padStart(3,'0')}`],
      image:row[0],position:row.slice(1,3),size:row.slice(3,5),scale:row.slice(11,13),
      rotation:[...data.ROTATIONS[index],row[13]],colour:row.slice(14,18),
    }, `${name}: slot${index} must not come from stale layout fallback`));
    for (let index=data.ELEMENTS.length;index<138;index++) {
      assert.deepEqual(sample.slots[index],{
        path:['clip',`group${String(Math.floor(index/60)).padStart(3,'0')}`,`shape${String(index).padStart(3,'0')}`],visible:false,
      });
    }
  }
});

test('heavy asset bytes stay fixed and changed resource hashes match the legal inventory', () => {
  for (const [path,hash] of Object.entries(fixture.unchangedHeavyAssets)) assert.equal(sha256(read(path)),hash,path);
  for (const path of ['bloodletting','iron_wave','shockwave'].flatMap(name =>
    ['json','lua'].map(extension => `${base}${name}/native-art.${extension}`)).concat(`${base}native-layout.json`)) {
    assert.ok(legal.files[path], `missing legal inventory: ${path}`);
    assert.equal(legal.files[path].sha256,sha256(read(path)),path);
  }
});
