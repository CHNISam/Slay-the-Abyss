// These three immutable input archives retain pre-browsing semantics only.
// Live hand-fan/flick/aim fixtures continue to load the production gesture owner.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {integrationSources,preIntegrationSource} from './pr372-integration-source.mjs';
export const historicalCardInputFixtures=Object.freeze(['tests/lua/card_input_port.lua','tests/lua/card_input_port_slice_2.lua','tests/lua/card_input_port_slice_3.lua']);
const root=fileURLToPath(new URL('../..',import.meta.url));
export function historicalCardInputPrelude(script,{cwd=process.cwd(),readSource=path=>readFileSync(path,'utf8')}={}){
 if(resolve(cwd)!==resolve(root)||!historicalCardInputFixtures.includes(script))return '';
 const path='src/lua/abyss_battle_card_gestures.lua',binding=integrationSources[path];
 const source=readSource(path).replaceAll('\r\n','\n');
 assert.equal(createHash('sha256').update(source).digest('hex'),binding.sha256,'unreviewed source-input gesture host');
 const prior=preIntegrationSource(path,source);
 return `print('HISTORICAL_CARD_INPUT_PRE_BROWSE')\npackage.preload.abyss_battle_card_gestures=function()return assert(load(${luaString(prior)},'@pre-browse-gesture'))()end\n`;
}
