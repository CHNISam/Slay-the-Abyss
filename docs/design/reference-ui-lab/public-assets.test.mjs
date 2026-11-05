import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readdirSync,readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=fileURLToPath(new URL('./',import.meta.url));
const files=readdirSync(root);
// Reject the private upstream image payloads, including embedded copies.
test('public source excludes private comparison raster assets and captures',()=>{
 assert.equal(files.some(f=>/^sts-(base-|rarity-|logo-gog|mana-colorless).*\.png$/.test(f)),false);
 assert.equal(existsSync(path.join(root,'evidence')),false);
 for(const file of files.filter(f=>/\.(css|js|html|svg)$/.test(f)))assert.doesNotMatch(readFileSync(path.join(root,file),'utf8'),/data:image\/(?:png|jpe?g|webp);base64,/i,file);
});
test('literal local image references resolve inside the snapshot',()=>{
 for(const file of files.filter(f=>/\.(css|js|html|svg)$/.test(f))){
  const source=readFileSync(path.join(root,file),'utf8');
  const names=[...source.matchAll(/(?:src=|url\()?["'](?:\.\/)?([a-zA-Z0-9_-]+\.(?:png|jpeg|jpg|svg))["']/g)].map(m=>m[1]);
  for(const name of names)assert.ok(existsSync(path.join(root,name)),`${file} references missing ${name}`);
 }
});
test('supplied constellation shape stays byte identical',()=>{
 assert.equal(createHash('sha256').update(readFileSync(path.join(root,'constellation-exact.png'))).digest('hex'),'5780bc541d322b369b61f656908da59bdeee7f3ad83988edca8be23776720ecd');
});

test('excluded raster payloads cannot be reintroduced under other names',()=>{
 const manifest=JSON.parse(readFileSync(path.join(root,'excluded-private-assets.json'),'utf8'));
 const hashes=new Set(Object.values(manifest.excludedRasterSha256));
 for(const file of files.filter(f=>/\.(png|jpe?g|webp|svg)$/.test(f))){
  assert.equal(hashes.has(createHash('sha256').update(readFileSync(path.join(root,file))).digest('hex')),false,file);
 }
});
test('dynamic image families include every runtime variant',()=>{
 const names=[...[100114,102002,102025,102028,102033,102034,102044].map(id=>`icon-${id}.svg`),...['attack','skill','power'].flatMap(kind=>[`card-native-${kind}.svg`,`sts-base-ironclad_${kind}.svg`,`sts-base-colorless_${kind}.svg`,`sts-rarity-frame_common_${kind}.svg`])];
 for(const name of names)assert.ok(existsSync(path.join(root,name)),name);
});

test('new card variants and licensed font assets are complete',()=>{
 for(const kind of ['attack','skill','power']){
  assert.ok(existsSync(path.join(root,`geo-card-zhongli-${kind}.svg`)));
  for(const rarity of ['common','uncommon','rare'])assert.ok(existsSync(path.join(root,`sts-rarity-frame_${rarity}_${kind}.svg`)));
 }
 for(const f of ['card-zh-sans.woff','card-zh-type.woff','FONT-LICENSES.txt','geo-cost-icon-priority.svg'])assert.ok(existsSync(path.join(root,f)));
 assert.match(readFileSync(path.join(root,'FONT-LICENSES.txt'),'utf8'),/SIL OPEN FONT LICENSE/);
});

test('rendered card icons resolve to the shipped public assets for all types',async()=>{
 const previous=globalThis.document;
 // Only suppress the browser stylesheet insertion while importing the renderer.
 globalThis.document={querySelector:()=>({})};
 let cardMarkup;
 try{({cardMarkup}=await import('./battle.js'))}finally{globalThis.document=previous}
 for(const type of ['attack','skill','power']){
  const markup=cardMarkup({type,id:type,name:'测试',text:'说明',cost:1,rarity:'common'},false);
  const image=markup.match(/class="native-card-icon" src="([^"]+)"/);
  assert.ok(image,`missing rendered illustration for ${type}`);
  assert.ok(existsSync(path.join(root,image[1])),`rendered card requests missing ${image[1]}`);
 }
});
