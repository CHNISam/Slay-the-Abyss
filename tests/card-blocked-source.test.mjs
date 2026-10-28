import test from 'node:test';
import assert from 'node:assert/strict';
import {cardFaceChildren} from '../scripts/card-face.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';

test('blocked cards retain the source inset veil and lock/reason capsule without shrinking native text',()=>{
 for(const context of ['battle','deck','node']){
  const face=cardFaceChildren(nativeTheme,context),parts=Object.fromEntries(face.map(c=>[c.name,c]));
  assert(parts.blockedVeil,'source blocked-card veil is required');
  assert.equal(parts.blockedVeil.visible,false);
  assert.deepEqual(parts.blockedVeil.size,[142,202]);
  assert.equal(parts.blockedVeil.kind,'image','a single opacity layer must not compound to 75% in overlapping rounded parts');
  assert.equal(parts.blockedVeil.colour,'#08090C');
  assert(Math.abs(parts.blockedVeil.opacity-128/255)<1e-9);
  assert(parts.blockedPill.children.some(c=>c.name==='edge'));
  assert.equal(parts.blockedLock.image,nativeTheme.icon.lock);
  assert.deepEqual(parts.blockedLock.size,[7,8]);
  assert(parts.blockedReason.size[1]>=40);
  assert.equal(parts.blockedReason.text.fontSize,14);
  const type=parts.tagEdge;
  assert(parts.blockedPill.position[1]-parts.blockedPill.size[1]/2>=type.position[1]+type.size[1]/2+2,'native-14px compatibility keeps a two-pixel gap above the type pill');
  assert(face.indexOf(parts.blockedVeil)>face.indexOf(parts.label),'source veil shades the card text');
  assert(face.indexOf(parts.blockedReason)<face.indexOf(parts.cost),'source cost is painted after the veil and reason so its state colour remains readable');
 }
});

import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {toLua,luaString} from '../scripts/build-lua-data.mjs';
import {buildUiTheme} from '../scripts/build-ui-theme.mjs';
import {runLua} from '../scripts/test-lua.mjs';
test('node card adapter suppresses the new blocked layer whenever its existing veil or stamp owns the overlay',()=>{
 const root=readFileSync('src/lua/abyss_node_ui.lua','utf8');
 const dependency=root.match(/require\("(abyss_node_ui_faces)"\)\.install\(ctx\)/);
 assert(dependency,'real composition root must install card faces');
 const module=dependency[1];
 const source=readFileSync('src/lua/'+module+'.lua','utf8');
 const call=source.match(/CardSkin\.apply\(box,definition,ctx\.options,\{([\s\S]*?)\}\)/);
 assert(call,'real node fillCard must call the shared skin');
 assert.match(source,/local covered\s*=\s*look\.veil\s+or\s+look\.stamp\s*~=\s*nil/,
  'both pre-existing node overlay owners must reach the scoped value; dim alone is not enough');
 assert.match(call[1],/overlayCovered\s*=\s*covered/,'the exact scoped overlay value must reach CardSkin');
 assert.match(source,/local reason=look\.reason or look\.stamp or '当前不可选择'/);
 assert.match(call[1],/reason=reason/);
});
test('actual core refusal codes survive the card adapter and only energy refusal changes the cost to red',()=>{
 const directory=mkdtempSync(join(tmpdir(),'card-blocked-'));
 try{
  buildUiTheme(undefined,undefined,join(directory,'abyss_theme.lua'));
  const definitions=JSON.parse(readFileSync('data/cards.json','utf8')).cards.filter(c=>['strike','defend'].includes(c.id));
  const script=join(directory,'case.lua');
  writeFileSync(script,`package.path=${luaString(directory+'/?.lua;src/lua/?.lua;')}..package.path\nCARD_BLOCKED_FACE=${toLua(cardFaceChildren(nativeTheme,'battle'))}\nCARD_BLOCKED_DEFS=${toLua(definitions)}\ndofile('tests/lua/support/card_blocked_display.lua')\n`);
  const result=runLua(script,{timeout:10000});
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/CARD_BLOCKED_DISPLAY_PASS/);
 }finally{rmSync(directory,{recursive:true,force:true});}
});
