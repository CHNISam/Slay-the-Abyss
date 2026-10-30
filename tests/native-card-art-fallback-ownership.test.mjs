import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {buildUI} from '../scripts/build-ui.mjs';
import {toLua} from '../scripts/build-lua-data.mjs';

test('real NodeUI face replacements retain only the latest fallback/publication owner',()=>{
 const directory=mkdtempSync(join(tmpdir(),'native-art-fallback-owner-'));
 try {
  buildUI(directory,undefined,{artFeatures:{cards:true}});
  const entry=join(directory,'entry.lua');
  const modules=['abyss_presentation','abyss_ui_layout','abyss_ui_templates'];
  writeFileSync(entry,modules.map(name=>`package.loaded[${toLua(name)}]=dofile(${toLua(join(directory,name+'.lua'))})`).join('\n')
   +"\ndofile('tests/lua/support/native_card_art_fallback_ownership.lua')\n");
  const result=runLua(entry,{timeout:30000});
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/NATIVE_CARD_ART_FALLBACK_OWNERSHIP_PASS 30/);
 } finally {rmSync(directory,{recursive:true,force:true});}
});
