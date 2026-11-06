import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {runLua} from '../../scripts/test-lua.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';

export const actorLifecycleBeforePath='tests/helpers/actor-lifecycle-before.lua';
export const actorLifecycleBeforeSha256='3ca585adaf351ef9fde31575e121c69186d2f2dfdd451a8ca32bf4ba0855ac94';
export function verifyActorLifecycleBefore(bytes){
  const source=bytes.toString('utf8').replaceAll('\r\n','\n');
  assert.equal(createHash('sha256').update(source).digest('hex'),actorLifecycleBeforeSha256,'complete frozen Actor source');
  return source;
}
export function actorLifecycleBefore(){return verifyActorLifecycleBefore(readFileSync(actorLifecycleBeforePath));}
export function runActorLifecycle(source,rulesSource){
  const directory=mkdtempSync(join(tmpdir(),'actor-lifecycle-'));
  try{
    const actor=join(directory,'actor.lua'),rules=join(directory,'rules.lua'),driver=join(directory,'driver.lua');
    if(source!==undefined)writeFileSync(actor,source);
    if(rulesSource!==undefined)writeFileSync(rules,rulesSource);
    writeFileSync(driver,`ACTOR_LIFECYCLE_TRACE=true;package.path='src/lua/?.lua;build/lua/?.lua;'..package.path;${rulesSource===undefined?'':`package.loaded.abyss_actor_power_rules=dofile(${luaString(rules.replaceAll('\\','/'))});`}${source===undefined?'':`package.loaded.abyss_actor=dofile(${luaString(actor.replaceAll('\\','/'))});`}dofile(${luaString(resolve('tests/lua/actor_lifecycle.lua').replaceAll('\\','/'))})`);
    return runLua(driver,{maxBuffer:32*1024*1024});
  }finally{rmSync(directory,{recursive:true,force:true});}
}
