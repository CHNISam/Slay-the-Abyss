import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {buildUI} from '../scripts/build-ui.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';
function runBackgroundFixture(path) {
 const dir=mkdtempSync(join(tmpdir(),'background-enabled-flow-'));
 try {
  buildUI(dir,undefined,{artFeatures:{menuBackground:true}});
  const entry=join(dir,'entry.lua');
  const modules=['abyss_presentation','abyss_ui_layout','abyss_ui_templates','abyss_menu_background_asset'];
  writeFileSync(entry,modules.map(name=>`package.loaded[${toLua(name)}]=dofile(${toLua(join(dir,name+'.lua'))})`).join('\n')
   +`\ndofile(${toLua(path)})\n`);
  return runLua(entry);
 } finally {rmSync(dir,{recursive:true,force:true});}
}
test('real native entry lazily opens victory artwork, pauses its cache and retires it with the engine world',()=>{
 const r=runBackgroundFixture('tests/lua/support/official_background_flow.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/OFFICIAL_BACKGROUND_FLOW_PASS/);
});
test('real native entry keeps fallback interactive on template/create errors and retires callbacks on engine teardown',()=>{
 const r=runBackgroundFixture('tests/lua/support/official_background_errors.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/OFFICIAL_BACKGROUND_ERRORS_PASS/);
});
