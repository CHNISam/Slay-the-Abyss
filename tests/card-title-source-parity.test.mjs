import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync,writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {luaString} from '../scripts/build-lua-data.mjs';
import {buildUiTheme} from '../scripts/build-ui-theme.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {nativeInlinePreview} from '../scripts/native-inline-preview.mjs';

// Only the real display/deck modules run. A tiny native control/Combat fixture
// isolates title ink from full UI construction and unrelated combat rules.
test('approved white card name keeps only the upgrade marker green, including recycled and relocated markers',()=>{
 const source=readFileSync('docs/design/ui-canvas/Card.dc.html','utf8');
 assert.match(source,/color: #FFFFFF; text-shadow/);
 assert.match(source,/span style="color: #8DE08A; margin-left: 2px">＋/);
 const directory=mkdtempSync(join(tmpdir(),'card-title-ink-'));
 try{
  buildUiTheme(undefined,undefined,join(directory,'abyss_theme.lua'));
  const path=join(directory,'title.lua');
  writeFileSync(path,`package.path=${luaString(directory+'/?.lua;src/lua/?.lua;')}..package.path
dofile('tests/helpers/card-title-source-parity.lua')
`);
  const result=runLua(path,{timeout:10000});
  assert.equal(result.status,0,result.stderr);
  assert.match(result.stdout,/CARD_TITLE_INK_PASS/);
  const inline=result.stdout.match(/CARD_TITLE_INLINE (.+)/)[1];
  assert.equal(nativeInlinePreview(inline),'防御<span style="color:#8DE08A">＋</span>');
 }finally{rmSync(directory,{recursive:true,force:true});}
});
