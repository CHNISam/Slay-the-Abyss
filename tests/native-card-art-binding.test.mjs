import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync, mkdirSync, symlinkSync, linkSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runLua } from '../scripts/test-lua.mjs';
import { toLua } from '../scripts/build-lua-data.mjs';
import { nativeCardArtArgs, prepareNativeCardArt, attachNativeCardArt } from '../scripts/card-art-samples.mjs';
import { buildUI, assertNativeUiCapacity } from '../scripts/build-ui.mjs';

const row=(image=100003)=>({image,position:[1.125,-2.25],size:[3.5,4.75],anchorMin:[.5,.5],anchorMax:[.5,.5],pivot:[.5,.5],scale:[1,1],rotation:[23.125,-45.25,9.75],colour:[12,34,56,78],imageType:image===100003?'stretch':'basic'});
export const registry=()=>({schemaVersion:2,editorCommit:'103025f9095d8089e3f9bf097f4d0c5fe039d546',canvas:[144,64],assets:{
 cleave:{cardId:'cleave',luaSha256:'a'.repeat(64),jsonSha256:'b'.repeat(64),slots:[row(),row(106057)]},
 heavy_blade:{cardId:'heavy_blade',luaSha256:'c'.repeat(64),jsonSha256:'d'.repeat(64),slots:[row(106056)]}}});
function pools(tree){const out=[];function visit(n,p=''){if(n.name==='artSamples')out.push([p,n]);for(const c of n.children??n.controls??[])visit(c,p+'/'+(n.name??''));}visit(tree);return out;}
function directory(fn){const p=mkdtempSync(join(tmpdir(),'abyss-controlled-art-'));try{return fn(p);}finally{rmSync(p,{recursive:true,force:true});}}

test('explicit art candidate uses exactly the selected real card hosts, never all 26',()=>directory(output=>{
 buildUI(output,undefined,{nativeCardArt:{registry:registry(),hosts:['battlePanel/card1']}});
 const game=JSON.parse(readFileSync(join(output,'game-ui.json'))),battle=JSON.parse(readFileSync(join(output,'battle-ui.json')));
 assert.equal(pools(game).length,1,'missing explicit real card pool');assert.equal(pools(battle).length,1);
 assert.equal(pools(game)[0][0].endsWith('/battlePanel/card1'),true);
 assert.deepEqual(pools(game)[0][1].position,[0,40]);assert.deepEqual(pools(game)[0][1].size,[144,64]);
 assertNativeUiCapacity(game);
 assert.match(readFileSync(join(output,'abyss_presentation.lua'),'utf8'),/\["nativeArt"\]/);
 const receipt=JSON.parse(readFileSync(join(output,'native-card-art-receipt.json')));
 assert.equal(receipt.staticPools,1);assert.equal(receipt.controlsPerPool,4);assert.equal(receipt.staticAddedControls,4);
 assert.equal(receipt.deckTemplateEnabled,false);
}));

test('ordinary build remains byte-identical after a candidate build',()=>directory(output=>{
 const first=join(output,'first'),candidate=join(output,'candidate'),last=join(output,'last');
 buildUI(first);buildUI(candidate,undefined,{nativeCardArt:{registry:registry(),hosts:['nodePanel/shopView/card1']}});buildUI(last);
 for(const name of readdirSync(first))assert.equal(readFileSync(join(first,name),'utf8'),readFileSync(join(last,name),'utf8'),name);
 assert.equal(pools(JSON.parse(readFileSync(join(first,'game-ui.json')))).length,0);
 const game=JSON.parse(readFileSync(join(candidate,'game-ui.json')));
 assert.equal(pools(game).length,1,'node art_* must not be missed');
 const sample=pools(game)[0];assert(sample[0].endsWith('/shopView/card1'));
}));

test('invalid candidate identities and unbounded host selection fail before writing',()=>directory(output=>{
 for(const change of [c=>c.hosts.push(c.hosts[0]),c=>c.hosts=['unknown/card1'],c=>c.hosts=['AbyssDeckCard/face'],
 c=>c.hosts=Array.from({length:11},(_,i)=>'battlePanel/card'+(i+1)),c=>c.registry.assets.cleave.cardId='heavy_blade',
 c=>c.registry.assets.cleave.slots[0].rotation[0]=NaN,c=>c.registry.assets.cleave.slots[0].image='external.png',
 c=>c.registry.assets.cleave.slots[0].imageType='invented']){
  const candidate={registry:registry(),hosts:['battlePanel/card1']};change(candidate);
  assert.throws(()=>buildUI(output,undefined,{nativeCardArt:candidate}),/native|candidate|art|host|slot/i);
  assert.deepEqual(readdirSync(output),[],'failed candidate must not leave partial output');
 }
}));

test('real shared Lua hosts bind battle, reward, deck and shop art under strict native contracts',()=>{
 const result=runLua('tests/lua/support/native_card_art_contexts.lua',{timeout:60000});
 assert.equal(result.status,0,result.stdout+'\n'+result.stderr);
 assert.match(result.stdout,/NATIVE_CARD_ART_CONTEXTS_PASS battle\/reward\/deck\/shop/);
});

for(const {name,module,before,after,error} of [
 {name:'unsupported CursorArea field',module:'abyss_battle_render_hud',
  before:'hit.raycastTarget=host.options.onPile~=nil and frame.active==true',
  after:'hit.interactable=host.options.onPile~=nil and frame.active==true',error:/CursorArea has no interactable/},
 {name:'missing root GameUI enum forwarding',module:'abyss_game_ui',
  before:'imageTypes = platform.imageTypes,',after:'',error:/real shared host was not bound/},
])test(`strict shared-host regression rejects ${name}`,()=>directory(output=>{
 const source=readFileSync(`src/lua/${module}.lua`,'utf8');
 assert.equal(source.split(before).length,2,`${name} mutation must have exactly one target`);
 const bootstrap=join(output,'mutated-contexts.lua');
 // Only negative controls substitute a module; the positive run uses unmodified source.
 writeFileSync(bootstrap,`package.preload[${toLua(module)}]=function()return assert(load(${toLua(source.replace(before,after))},'@mutated-${module}'))()end\ndofile('tests/lua/support/native_card_art_contexts.lua')\n`);
 const result=runLua(bootstrap,{timeout:60000});
 assert.notEqual(result.status,0,`${name} escaped regression`);
 assert.match(result.stderr,error);
 assert.doesNotMatch(result.stdout,/NATIVE_CARD_ART_CONTEXTS_PASS/);
}));

test('CLI accepts only explicit 0/1/5/10 or chosen hosts; disabling cleans prior receipt',()=>directory(output=>{
 const r=join(output,'registry.json');writeFileSync(r,JSON.stringify(registry()));
 for(const count of [0,1,5,10]) {
  const options=nativeCardArtArgs([`--native-card-art-count=${count}`,`--native-card-art-registry=${r}`]);
  assert.equal(options.nativeCardArt?.hosts.length??0,count);
 }
 assert.deepEqual(nativeCardArtArgs([]),{args:[],nativeCardArt:undefined});
 for(const args of [['--native-card-art-count=1=junk'],['--native-card-art-count=2'],['--native-card-art-count=1'],[`--native-card-art-registry=${r}`],
  ['--native-card-art-count=0','--native-card-art-host=nodePanel/shopView/card1']])assert.throws(()=>nativeCardArtArgs(args));
 const dest=join(output,'build');buildUI(dest,undefined,{nativeCardArt:{registry:registry(),hosts:['battlePanel/card1']}});
 buildUI(dest);assert(!readdirSync(dest).includes('native-card-art-receipt.json'),'disabled candidate left stale receipt');
 assert.equal(pools(JSON.parse(readFileSync(join(dest,'game-ui.json')))).length,0);
}));


test('derived registry protects original frozen inputs from output aliases',()=>directory(output=>{
 const r=registry();r.sourceInputs=[];
 for(const [id,a] of Object.entries(r.assets))for(const kind of ['lua','json']) {
  const path=join(output,`${id}.${kind}`),bytes=`frozen ${id} ${kind}`;writeFileSync(path,bytes);
  const sha256=createHash('sha256').update(bytes).digest('hex');a[kind+'Sha256']=sha256;
  r.sourceInputs.push({cardId:id,kind,path,sha256});
 }
 const file=join(output,'registry.json');writeFileSync(file,JSON.stringify(r));
 for(const [mode,link]of [['symbolic',symlinkSync],['hard',linkSync]]) {
  const dest=join(output,mode);mkdirSync(dest);const source=r.sourceInputs[0].path,before=readFileSync(source);
  link(source,join(dest,'game-ui.json'));
  assert.throws(()=>buildUI(dest,undefined,{nativeCardArt:{registry:file,hosts:['battlePanel/card1']}}),/overwrite an input/);
  assert.deepEqual(readFileSync(source),before,'frozen source was changed');
 }
}));


test('candidate layer preserves adjacent PR256-style art well and type trims',()=>directory(output=>{
 buildUI(output);const tree=JSON.parse(readFileSync(join(output,'battle-ui.json')));
 const face=tree.controls.find(c=>c.name==='stage').children.find(c=>c.name==='card1');
 face.children.splice(face.children.findIndex(c=>c.name==='artPlate')+1,0,{name:'artWell',kind:'image',image:100001,size:[140,60]});
 face.children.splice(face.children.findIndex(c=>c.name==='type'),0,{name:'typeEdge',kind:'image',image:100001},{name:'typeTag',kind:'image',image:100001});
 const before=structuredClone(tree);
 attachNativeCardArt(tree,prepareNativeCardArt({registry:registry(),hosts:['battlePanel/card1']}),{battleOnly:true});
 const names=face.children.map(c=>c.name);
 assert(names.indexOf('artSamples')>names.indexOf('art')&&names.indexOf('artSamples')<names.indexOf('typeEdge'));
 face.children=face.children.filter(c=>c.name!=='artSamples');assert.deepEqual(tree,before);
}));
