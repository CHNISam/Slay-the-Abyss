import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {gunzipSync} from 'node:zlib';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';

export const combatLifecycleFile='src/lua/abyss_combat.lua';
export const combatLifecycleFixture='tests/lua/combat-lifecycle.lua';
export const combatLifecycleHash=s=>createHash('sha256').update(s).digest('hex');
export const combatLifecycleCurrent=()=>readFileSync(combatLifecycleFile,'utf8').replaceAll('\r\n','\n');
const frozen=JSON.parse(readFileSync(new URL('./combat-lifecycle-before.json',import.meta.url),'utf8'));
export const combatLifecycleBefore=gunzipSync(Buffer.from(frozen.gzipBase64,'base64')).toString('utf8');
assert.equal(frozen.path,combatLifecycleFile);
assert.equal(frozen.revision,'dedb9ed5af52fc595031d64d3e8fd84bc908b2c8');
assert.equal(frozen.sha256,'6929906a274bc84dd2914083ae3d0019ef7ad5d89659f357ff979a89ee9e7805');
assert.equal(combatLifecycleHash(combatLifecycleBefore),frozen.sha256);

export function executeCombatLifecycle(source,group,trace=false,{actorSource}={}){
  const dir=mkdtempSync(join(tmpdir(),'combat-lifecycle-'));
  try{
    const module=join(dir,'combat.lua'),driver=join(dir,'driver.lua');writeFileSync(module,source);
    let actorPrelude='';
    if(actorSource!==undefined){
      const actor=join(dir,'actor.lua');writeFileSync(actor,actorSource);
      actorPrelude=`package.loaded.abyss_actor=dofile(${luaString(actor.replaceAll('\\','/'))});`;
    }
    writeFileSync(driver,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;${actorPrelude}package.loaded.abyss_combat=dofile(${luaString(module.replaceAll('\\','/'))});COMBAT_LIFECYCLE_GROUP=${luaString(group)};COMBAT_LIFECYCLE_TRACE=${trace?'true':'false'};dofile(${luaString(resolve(combatLifecycleFixture).replaceAll('\\','/'))})`);
    return runLua(driver,{maxBuffer:32*1024*1024});
  }finally{rmSync(dir,{recursive:true,force:true});}
}
