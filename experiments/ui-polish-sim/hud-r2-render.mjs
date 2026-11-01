// Offline production-Host projection. Library assets become stand-in glyphs.
// Requires an existing Playwright installation via PLAYWRIGHT_ENTRY when not resolvable.
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {createRequire} from 'node:module';
import {runLua} from '../../scripts/test-lua.mjs';
import {page} from '../../scripts/node-ui-preview.mjs';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_ENTRY||'playwright');
const out=resolve(process.argv[2]||'.artifacts/hud-r2');
mkdirSync(out,{recursive:true});
const host=runLua('experiments/ui-polish-sim/hud-r2-capture.lua',{timeout:30000});
if(host.status!==0)throw Error(host.stdout+host.stderr);
const scenes=JSON.parse(host.stdout.split('PARITY_SCENES ')[1]);
const fix=c=>{if(c.children&&!Array.isArray(c.children))c.children=Object.values(c.children);(c.children??[]).forEach(fix);};
const browser=await chromium.launch({executablePath:process.env.CHROME||'chromium',headless:true,timeout:15000,
 args:['--no-sandbox','--disable-dev-shm-usage','--disable-gpu']});
try{
 for(const scene of scenes){
  fix(scene.tree);const html=page(scene.tree);
  writeFileSync(join(out,scene.name+'.html'),html);
  writeFileSync(join(out,scene.name+'.tree.json'),JSON.stringify(scene.tree));
  for(const [width,height] of [[1280,720],[2048,1150],[2048,1171],[2048,1152]]){
   const tab=await browser.newPage({viewport:{width,height}});
   // setContent avoids file:// policy differences; this document has no external resources.
   await tab.setContent(html,{waitUntil:'domcontentloaded',timeout:15000});
   const scale=Math.min(width/1280,height/720);
   await tab.addStyleTag({content:`#c{transform:scale(${scale});transform-origin:0 0;left:${(width-1280*scale)/2}px;top:${(height-720*scale)/2}px}`});
   await tab.screenshot({path:join(out,`${scene.name}-${width}x${height}.png`),timeout:15000});
   await tab.close();
  }
 }
}finally{await browser.close();}
console.log('HUD R2 Host projection: '+scenes.map(s=>s.name).join(', '));
