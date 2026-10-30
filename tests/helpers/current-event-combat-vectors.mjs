import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {toLua} from '../../scripts/build-lua-data.mjs';
export const currentEventCombatVectorFixtures=Object.freeze([
 'tests/lua/event_combat_route_enemies.lua',
 'tests/lua/event_combat_route_reducers.lua',
]);
const root=resolve(fileURLToPath(new URL('../..',import.meta.url)));
export function currentEventCombatVectorPrelude(script,{cwd=process.cwd(),readSource=p=>readFileSync(p,'utf8')}={}){
 if(resolve(cwd)!==root||!currentEventCombatVectorFixtures.includes(script))return '';
 // The same reviewed JSON/toLua input as the Node wrappers, without a dependency
 // on which shard happened to generate build/lua first. Each Lua VM gets its own table.
 const vectors=JSON.parse(readSource(resolve(cwd,'tests/fixtures/event-combat-routes-vectors.json')));
 return `package.preload['event_combat_routes_vectors']=function() return ${toLua(vectors)} end;`;
}
