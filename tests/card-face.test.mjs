import test from 'node:test';
import assert from 'node:assert/strict';
import {cardFaceChildren} from '../scripts/card-face.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
import {battleLayout} from '../scripts/ui-layout.mjs';
import {deckCardTemplate} from '../scripts/deck-ui-layout.mjs';
import {nodeLayout} from '../scripts/node-ui-layout.mjs';

test('every card face uses native library images and one set of live text slots',()=>{
  for(const context of ['battle','deck','node']) {
    const face=cardFaceChildren(nativeTheme,context);
    for(const name of ['name','type','cost',context==='node'?'description':'label'])
      assert.equal(face.filter(c=>c.name===name && c.kind==='text').length,1,context+'/'+name);
    for(const image of face.filter(c=>c.kind==='image')) assert(Number.isInteger(image.image));
    assert(face.findIndex(c=>c.name==='artPlate')<face.findIndex(c=>c.name=== (context==='node'?'art_attack':'art')));
    assert.equal(face.filter(c=>c.name==='hit').length,context==='deck'?0:1);
  }
});

test('hand, reward, library and node assembly consume the same editable face contract',()=>{
  const theme=structuredClone(nativeTheme);
  theme.layout.card.art=58;
  theme.font.cardName=19;
  const sources=[cardFaceChildren(theme,'battle'),deckCardTemplate(theme).children.find(c=>c.name==='face').children];
  const node=nodeLayout(theme).controls[0];
  sources.push(node.children.find(c=>c.name==='shopView').children.find(c=>c.name==='card1').children);
  for(const face of sources) {
    assert.equal(face.find(c=>c.name==='artPlate').size[1],58);
    assert.equal(face.find(c=>c.name==='name').text.fontSize,19);
  }
  const tree=battleLayout().controls.find(c=>c.name==='stage');
  assert.deepEqual(tree.children.find(c=>c.name==='card1').children,cardFaceChildren(nativeTheme,'battle'));
});

test('a reused card template cannot mutate another card or the theme',()=>{
  const before=structuredClone(nativeTheme),one=cardFaceChildren(nativeTheme,'battle'),two=cardFaceChildren(nativeTheme,'battle');
  one.find(c=>c.name==='label').text.content='changed';
  one.find(c=>c.name==='artPlate').size[0]=1;
  assert.equal(two.find(c=>c.name==='label').text.content,'');
  assert.equal(two.find(c=>c.name==='artPlate').size[0],nativeTheme.layout.card.size[0]-nativeTheme.space.border*2);
  assert.deepEqual(nativeTheme,before);
});
