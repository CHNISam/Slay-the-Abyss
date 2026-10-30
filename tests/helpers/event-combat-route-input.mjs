import {readFileSync} from 'node:fs';
import {relative,resolve} from 'node:path';
import {toLua} from '../../scripts/build-lua-data.mjs';

export const eventCombatRouteFixtures=Object.freeze([
  'tests/lua/event_combat_route_reducers.lua',
  'tests/lua/event_combat_route_enemies.lua',
]);
export const eventCombatRouteInput='tests/fixtures/event-combat-routes-vectors.json';

export function eventCombatRoutePrelude(script,{cwd=process.cwd()}={}){
  const path=relative(resolve(cwd),resolve(cwd,script)).replaceAll('\\','/');
  if(!eventCombatRouteFixtures.includes(path))return '';
  const vectors=JSON.parse(readFileSync(resolve(cwd,eventCombatRouteInput),'utf8'));
  return `package.preload['event_combat_routes_vectors']=function() return ${toLua(vectors)} end;`;
}
