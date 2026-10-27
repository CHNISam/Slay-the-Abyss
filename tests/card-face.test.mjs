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

test('approved card aperture stays 144 by 64 while native text boxes remain independent of visual bands',()=>{
  for(const context of ['battle','deck','node']) {
    const face=cardFaceChildren(nativeTheme,context), part=name=>face.find(c=>c.name===name);
    assert.deepEqual(part('nameBand').size,[144,30],context+' approved title background');
    assert.deepEqual(part('artPlate').size,[144,64],context+' approved artwork aperture');
    assert.deepEqual(part('artPlate').position,[0,40],context+' art position');
    assert.equal(part('name').position[1],87,context+' short title centre');
    for(const name of ['name','type','cost']) assert(part(name).size[1]>=40,context+'/'+name+' native compatibility');
    assert.deepEqual(part('type').position,[0,-1],context+' approved type glyph centre');
    for(const art of face.filter(c=>/^art(?:_|$)/.test(c.name)))
      assert.deepEqual(art.size,[40,40],context+'/'+art.name+' explicitly square placeholder');
    const name=part('name'),cost=part('cost');
    assert(name.position[0]-name.size[0]/2>cost.position[0]+cost.size[0]/2,'title never touches cost disc');
    assert.equal(part('type').text.fontSize,14);
    assert.deepEqual(part(context==='node'?'description':'label').size,[132,92]);
  }
});

test('card glyph budgets remain separate even when transparent native text boxes overlap',()=>{
  for(const context of ['battle','deck','node']) {
    const face=cardFaceChildren(nativeTheme,context),part=name=>face.find(c=>c.name===name);
    const title=part('name'),art=part('artPlate'),type=part('type'),body=part(context==='node'?'description':'label');
    // One readable title line (17, or 14 for the six long names) must stay in
    // the approved 30-high band, never in the picture. Native frame is 40 high.
    for(const font of [17,14]) {
      assert(title.position[1]-font*1.65/2>=art.position[1]+art.size[1]/2);
      assert(title.position[1]+font*1.65/2<=102);
    }
    // The fixed 14px type line sits in its 18px visual region; a maximal body
    // never crosses its bottom glyph edge. Frame overlap alone is permitted.
    assert(type.position[1]+14/2<=8);
    assert(type.position[1]-14/2>=body.position[1]+body.size[1]/2);
    assert(type.size[1]>18 && title.size[1]>30);
  }
});
