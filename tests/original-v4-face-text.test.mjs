import test from 'node:test';
import assert from 'node:assert/strict';
import {runLua} from '../scripts/test-lua.mjs';
import {cardFaceChildren} from '../scripts/card-face.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';

test('generated battle, library and node body frames leave a real type-glyph gap and stay within the card',()=>{
  for(const context of ['battle','deck','node']){
    const face=cardFaceChildren(nativeTheme,context);
    const body=face.find(c=>c.name===(context==='node'?'description':'label'));
    const type=face.find(c=>c.name==='type');
    assert.equal(body.position[1],-56,context+' uses the 92-high body, not its 132-wide extent');
    assert(type.position[1]-type.text.fontSize/2-(body.position[1]+body.size[1]/2)>=1,context+' type-glyph gap');
    assert(body.position[1]-body.size[1]/2>=-nativeTheme.layout.card.size[1]/2+nativeTheme.space.border,context+' inner bottom');
  }
});

test('all 150 Raiden base and upgraded faces expose complete actions and fit at readable font size',()=>{
  const result=runLua('tests/lua/original_v4_face_text.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/ORIGINAL_V4_FACE_TEXT_PASS 150/);
});

test('real native faces fit, recycle and expose bound reward keywords without changing rewards',()=>{
  const result=runLua('tests/lua/original_v4_face_native.lua');
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/ORIGINAL_V4_FACE_NATIVE_PASS 150 \d+ compact/);
});
