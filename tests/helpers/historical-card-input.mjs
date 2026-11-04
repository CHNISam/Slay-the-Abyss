// These three immutable input archives retain pre-browsing semantics only.
// Live hand-fan/flick/aim fixtures continue to load the production gesture owner.
import assert from 'node:assert/strict';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import {luaString} from '../../scripts/build-lua-data.mjs';
const require=createRequire(import.meta.url);
export const historicalCardInputFixtures=Object.freeze(['tests/lua/card_input_port.lua','tests/lua/card_input_port_slice_2.lua','tests/lua/card_input_port_slice_3.lua']);
const root=fileURLToPath(new URL('../..',import.meta.url));
export function historicalCardInputPrelude(script,{cwd=process.cwd(),readSource}={}){
 if(resolve(cwd)!==resolve(root)||!historicalCardInputFixtures.includes(script))return '';
 // Ordinary Lua invocations need only the routing metadata. Load the original
 // proof closure synchronously once a real historical entry has been selected.
 const {integrationSources,preIntegrationSource}=require('./pr372-integration-source.mjs');
 // These frozen gestures belong to the registered original source epoch.
 // One call-local reader owns both the host and every linked dependency; an
 // injected reader remains fresh and can never fall back to the archive.
 if(!readSource){
  const {loadHistoricalBaselineInputs}=require('./historical-baseline-inputs.mjs');
  const inputs=loadHistoricalBaselineInputs();
  readSource=path=>{assert.ok(Object.hasOwn(inputs,path),'registered original source-input dependency: '+path);return inputs[path].toString('utf8');};
 }
 const path='src/lua/abyss_battle_card_gestures.lua',binding=integrationSources[path];
 const source=readSource(path).replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(source).digest('hex'),binding.sha256,'unreviewed source-input gesture host');
 const prior=preIntegrationSource(path,source,'base',{readSource});
 return `print('HISTORICAL_CARD_INPUT_PRE_BROWSE')\npackage.preload.abyss_battle_card_gestures=function()return assert(load(${luaString(prior)},'@pre-browse-gesture'))()end\n`;
}
