// Art-specific tests compile the explicit developer opt-in; the normal build
// remains dependency-free with all art categories disabled.
import {after} from 'node:test';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {buildUI} from '../../scripts/build-ui.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
export function monsterEnabledLua(){
 const directory=mkdtempSync(join(tmpdir(),'abyss-enabled-monster-ui-'));
 try{buildUI(directory,undefined,{artFeatures:{monsters:true}});}catch(error){rmSync(directory,{recursive:true,force:true});throw error;}
 after(()=>rmSync(directory,{recursive:true,force:true}));
 let serial=0;
 return (script,options={})=>{
  const wrapper=join(directory,`case-${serial++}.lua`);
  writeFileSync(wrapper,`package.path=${luaString(directory+'/?.lua;')}..package.path\ndofile(${luaString(resolve(script))})\n`);
  return runLua(wrapper,options);
 };
}
