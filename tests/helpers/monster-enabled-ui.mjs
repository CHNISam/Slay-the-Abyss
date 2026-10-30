// Art-specific tests compile the explicit developer opt-in; the normal build
// remains dependency-free with all art categories disabled.
import {after} from 'node:test';
import {mkdtempSync,writeFileSync,rmSync,readFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {buildUI} from '../../scripts/build-ui.mjs';
import {prepareMonsterArt} from '../../scripts/monster-art.mjs';
import {luaString} from '../../scripts/build-lua-data.mjs';
import {runLua} from '../../scripts/test-lua.mjs';
// Explicit legacy full-catalog coverage; never change the candidate registry on disk.
export function fullMonsterArtFixture(){
 prepareMonsterArt(); // Retain the default full-catalog source/provenance validation.
 const registry=JSON.parse(readFileSync('data/presentation/native-monster-art.json','utf8'));
 delete registry.candidateAssets;
 return registry;
}
export function monsterEnabledLua({fullCatalog=false}={}){
 const directory=mkdtempSync(join(tmpdir(),'abyss-enabled-monster-ui-'));
 try{buildUI(directory,undefined,{artFeatures:{monsters:true},...(fullCatalog?{monsterArt:fullMonsterArtFixture()}: {})});}catch(error){rmSync(directory,{recursive:true,force:true});throw error;}
 after(()=>rmSync(directory,{recursive:true,force:true}));
 let serial=0;
 return (script,options={})=>{
  const wrapper=join(directory,`case-${serial++}.lua`);
  writeFileSync(wrapper,`package.path=${luaString(directory+'/?.lua;')}..package.path\ndofile(${luaString(resolve(script))})\n`);
  return runLua(wrapper,options);
 };
}
