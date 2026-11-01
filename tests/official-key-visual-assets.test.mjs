import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const base = new URL('../art/characters/key-visual/traveler-geo/official-landscape-v1/', import.meta.url);
const read = name => readFileSync(new URL(name,base));
const json = name => JSON.parse(read(name));
const asset = json('asset.json'), scene = json('native-art.json'), blocks = json('blocks.json').blocks;
const lua = read('native-art.lua').toString('utf8').replace(/\r\n/g,'\n');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const drawing = /local ELEMENTS = \{([\s\S]*?)\n\}/.exec(lua);
assert.ok(drawing, 'actual ELEMENTS must exist independently of editor snapshot');
const rows = drawing[1].trim().split('\n').map(line => JSON.parse(line.trim().replace(/^\{/,'[').replace(/\},?$/,']')));

function verifyGeometry(elements, data, literalRows) {
  assert.equal(elements.length,13201);
  assert.equal(data.length,13201);
  assert.equal(literalRows.length,13201);
  const coverage = new Uint8Array(480*270);
  for (let i=0; i<data.length; i++) {
    const [x,y,w,h,color] = data[i], e=elements[i];
    assert.ok([x,y,w,h,color].every(Number.isSafeInteger));
    assert.ok(x>=0 && y>=0 && w>0 && h>0 && x+w<=480 && y+h<=270);
    assert.ok(color>=0 && color<=0xffffff);
    assert.equal(e.type,'rectangle');
    assert.deepEqual([e.x,e.y,e.width,e.height,e.rotation,e.rotationX,e.rotationY,e.opacity,e.zIndex],
      [x+w/2,y+h/2,w,h,0,0,0,1,i]);
    assert.equal(e.color,`#${color.toString(16).padStart(6,'0')}`);
    assert.deepEqual(literalRows[i],[100001,e.x-240,135-e.y,w,h,0.5,0.5,0.5,0.5,0.5,0.5,1,1,0,
      (color>>16)&255,(color>>8)&255,color&255,255]);
    for(let yy=y;yy<y+h;yy++) for(let xx=x;xx<x+w;xx++) {
      const pixel=yy*480+xx;
      assert.equal(coverage[pixel],0,'rectangle overlap');
      coverage[pixel]=1;
    }
  }
  assert.ok(coverage.every(value=>value===1),'no missing source pixels');
}

test('official landscape data and actual Lua literal preserve all 13201 rectangles',()=>{
  assert.deepEqual([scene.canvas.width,scene.canvas.height],[480,270]);
  verifyGeometry(scene.elements,blocks,rows);
  assert.match(lua,/local IMAGE_PREFAB_ID = 0\b/);
  assert.ok(Buffer.byteLength(lua)<10*1024*1024,'complete original export must pass existing guard');
});

test('candidate approval is not native import, device approval or single-gallery-slot integration',()=>{
  assert.equal(asset.assetId,'traveler-geo.official-landscape.v1');
  assert.deepEqual(asset.logicalSize,[480,270]);
  assert.equal(asset.primitiveCount,13201);
  assert.equal(asset.approval.status,'visual-direction-accepted');
  assert.equal(asset.approval.approvedPreviewSha256,asset.files['preview-native-2x.png'].sha256);
  assert.equal(asset.runtime.enabled,false);
  assert.equal(asset.runtime.battleAllowed,false);
  assert.equal(asset.runtime.templateIndexId,null);
  for(const key of ['officialImport','pc','physicalAndroid']) assert.equal(asset.verification[key],'not-run');
  assert.equal(asset.production.expansionAllowed,false);
});

test('frozen assets bind real payloads or exact declared raster LFS pointers',()=>{
  for(const [name,record] of Object.entries(asset.files)) {
    const bytes=read(name), text=bytes.toString('utf8');
    const pointer=/^version https:\/\/git-lfs.github.com\/spec\/v1\noid sha256:([0-9a-f]{64})\nsize ([1-9]\d*)\n$/.exec(text);
    if(pointer) {
      assert.ok(['source.webp','preview-native.png','preview-native-2x.png'].includes(name));
      assert.deepEqual([pointer[1],Number(pointer[2])],[record.sha256,record.bytes]);
    } else {
      const raw=/\.(lua|json)$/.test(name)?Buffer.from(text.replace(/\r\n/g,'\n')):bytes;
      assert.equal(raw.length,record.bytes,name);
      assert.equal(sha(raw),record.sha256,name);
    }
  }
  assert.equal(asset.files['source.webp'].sha256,'a6cbdfbc71ab5bac40f6a126fef4093d4270edcb9ff61000d1fc0622c4d95045');
  assert.equal(asset.files['native-art.lua'].sha256,'fc0e4c50c0ed03a7a790731df5f5e10076d1418db615c41784210e9677c24ce3');
});

test('geometry guard rejects omissions, moved rectangles and literal-only color drift',()=>{
  assert.throws(()=>verifyGeometry(scene.elements,blocks.slice(1),rows));
  const changed=scene.elements.map((e,i)=>i===0?{...e,x:e.x+1}:e);
  assert.throws(()=>verifyGeometry(changed,blocks,rows));
  const recolored=rows.map((r,i)=>i===0?r.map((v,j)=>j===14?(v+1)%256:v):r);
  assert.throws(()=>verifyGeometry(scene.elements,blocks,recolored));
});
