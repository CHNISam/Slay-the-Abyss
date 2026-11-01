import {mkdtempSync,readdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {buildLuaData,luaString} from '../../scripts/build-lua-data.mjs';
import {buildUI} from '../../scripts/build-ui.mjs';
import {bindBackgroundTemplate} from '../../scripts/official-background.mjs';
import {bindPortraitTemplates} from '../../scripts/official-portraits.mjs';
import {runLua} from '../../scripts/test-lua.mjs';

// Generated modules belong to this fixture, never the default all-off build/lua.
export function createOptInArtFixture({artFeatures={menuBackground:true,selectionAvatar:true,battlePortrait:true},bindTemplates=false}={}) {
 const root=process.cwd(),prefix=join(tmpdir(),'abyss-opt-in-art-'),directory=mkdtempSync(prefix);
 const dispose=()=>{
  if(!resolve(directory).startsWith(resolve(prefix)))throw Error('Unexpected art fixture directory');
  rmSync(directory,{recursive:true,force:true});
 };
 try {
  buildLuaData(join(root,'data'),join(directory,'abyss_data.lua'));
  buildUI(directory,undefined,{artFeatures});
  if(bindTemplates){
   if(artFeatures.menuBackground)bindBackgroundTemplate(directory,{templateIndex:41},{containerTemplateIndex:73});
   if(artFeatures.selectionAvatar||artFeatures.battlePortrait)bindPortraitTemplates(directory,
    {image:{templateIndex:41},container:{templateIndex:73}},artFeatures);
  }
  const modules=readdirSync(directory).filter(name=>name.endsWith('.lua'));
  let serial=0;
  return {directory,dispose,runLua(script,options={}) {
   const entry=join(directory,`fixture-entry-${++serial}.lua`);
   const path=directory.replaceAll('\\','/')+'/?.lua;'+root.replaceAll('\\','/')+'/src/lua/?.lua;';
   // Some historical Lua fixtures prepend build/lua themselves. Preload these
   // exact generated files so even those fixtures cannot consume stale defaults.
   const preloads=modules.map(file=>`package.preload[${luaString(file.slice(0,-4))}]=function()return dofile(${luaString(join(directory,file))})end`);
   writeFileSync(entry,`package.path=${luaString(path)}\n${preloads.join('\n')}\ndofile(${luaString(resolve(root,script))})\n`);
   return runLua(entry,{...options,cwd:root});
  }};
 }catch(error){dispose();throw error;}
}
