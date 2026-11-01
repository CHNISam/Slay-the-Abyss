import {buildReadyCardRegistry} from '../scripts/art/ready-card-registry.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,dirname,join} from 'node:path';
import {tmpdir} from 'node:os';
import {toLua} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {prepareNativeCardArt,nativeArtPool} from '../scripts/card-art-samples.mjs';
const input=process.env.ABYSS_NATIVE_ART_SOURCE_REGISTRY??'art/cards/traveler-geo/native-source-registry.json',
 literal=process.env.ABYSS_NATIVE_ART_LITERAL_REGISTRY??'art/cards/traveler-geo/native-runtime-registry.json';
for(const id of ['armaments','cleave','heavy_blade'])test(`frozen ${id} literal equals native CardDisplay API writes (explicit local input)`,{skip:!input||!literal},()=>{
 const sources=JSON.parse(readFileSync(input));
 // The legacy two-card registry remains immutable. Exercise the additional
 // precise card against its real validated export, without rewriting that registry.
 const extra=id==='armaments'&&!process.env.ABYSS_NATIVE_ART_SOURCE_REGISTRY;
 const registry=extra?buildReadyCardRegistry():literal;
 const data=prepareNativeCardArt({registry,hosts:['battlePanel/card1']});
 const asset=extra?{cardId:id,lua:id+'/native-art.lua',json:id+'/native-art.json',
  luaSha256:data.registry.assets[id].luaSha256,jsonSha256:data.registry.assets[id].jsonSha256}:sources.assets.find(a=>a.cardId===id);
 assert(asset,'missing frozen source');
 for(const kind of ['lua','json']) {
  const bytes=readFileSync(resolve(dirname(input),asset[kind]));
  assert.equal(createHash('sha256').update(bytes).digest('hex'),asset[kind+'Sha256']);
  assert.equal(data.registry.assets[id][kind+'Sha256'],asset[kind+'Sha256']);
 }
 const source=readFileSync(resolve(dirname(input),asset.lua),'utf8').replaceAll('\r\n','\n').split('-- 编辑器回导数据')[0];
 const folder=mkdtempSync(join(tmpdir(),'abyss-native-literal-'));
 try {
  const metadata={...data.registry.assets[id],capacity:data.capacity};
  const script=join(folder,'check.lua');
  const body=(m)=>`ABYSS_EXPORTED_ART=${toLua(source)}\nABYSS_NATIVE_POOL=${toLua(nativeArtPool(data.capacity))}\nABYSS_METADATA=${toLua(m)}\ndofile('tests/lua/support/native_card_art_source_equivalence.lua')\n`;
  writeFileSync(script,body(metadata));let result=runLua(script,{timeout:60000});
  assert.equal(result.status,0,result.stdout+result.stderr);console.log(result.stdout.trim());
  // A small XYZ mutation must fail; do not accept mere count/hash agreement.
  metadata.slots[21].rotation[0]+=.125;writeFileSync(script,body(metadata));result=runLua(script,{timeout:60000});
  assert.notEqual(result.status,0);assert.match(result.stderr,/native source mismatch rotation/);
 }finally{rmSync(folder,{recursive:true,force:true});}
});
