import test from 'node:test';
import assert from 'node:assert/strict';
import { assertNativeUiCapacity } from '../scripts/build-ui.mjs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { deckCardTemplate } from '../scripts/deck-ui-layout.mjs';
import { nativeControls, nativeTheme } from '../scripts/native-ui-theme.mjs';

const children = count => Array.from({ length: count }, (_, i) => ({ name: `control${i}` }));
test('every exported UI and template uses readable integer native font fields', () => {
  let count=0;
  const visit=control=>{
    for(const key of ['fontSize','minFontSize'])if(control.text?.[key]!==undefined){
      assert(Number.isInteger(control.text[key])&&control.text[key]>=14,`${control.name}.text.${key}: ${control.text[key]}`);
      count++;
    }
    for(const child of control.controls??control.children??[])visit(child);
  };
  visit(gameLayout());visit(deckCardTemplate());assert(count>100);
  assert.equal(nativeTheme.layout.energy.numberSize,29);
  assert.equal(nativeTheme.layout.intent.numberSize,15);
});
test('native text helper rounds fonts without rounding position or size',()=>{
  const text=nativeControls().text('scaled',[0.25,1.5,100.75,40.5],'',29.333333333333332);
  assert.equal(text.text.fontSize,29);assert.deepEqual(text.position,[0.25,1.5]);assert.deepEqual(text.size,[100.75,40.5]);
  assert.equal(nativeControls().text('small',[0,0,1,1],'',10.2).text.fontSize,14);
});
test('native export rejects fractional or unreadable font fields before scene-save varint conversion',()=>{
  for(const key of ['fontSize','minFontSize'])for(const value of [29.333333333333332,13,NaN]){
    assert.throws(()=>assertNativeUiCapacity({controls:[{name:'badFont',kind:'text',text:{[key]:value}}]}),/badFont.*text\.(fontSize|minFontSize).*integer/);
  }
  assert.doesNotThrow(()=>assertNativeUiCapacity({controls:[{name:'fractionalGeometry',kind:'text',position:[0.2,0.3],size:[88/3,40.5],text:{fontSize:29,minFontSize:14}}]}));
});
test('native export accepts the platform boundary of 60 direct controls', () => {
  assert.doesNotThrow(() => assertNativeUiCapacity({ name: 'layout', controls: [{ name: 'stage', kind: 'container', children: children(60) }] }));
});
test('native export rejects 61 controls even when the overflowing container is hidden', () => {
  assert.throws(() => assertNativeUiCapacity({ name: 'layout', controls: [{ name: 'battlePanel', kind: 'container', visible: false, children: children(61) }] }),
    /layout\/battlePanel: 61 direct children.*60/);
});
test('native export checks nested template containers and reports the offending path', () => {
  assert.throws(() => assertNativeUiCapacity({ name: 'template', children: [{ name: 'inner', kind: 'container', children: children(61) }] }),
    /template\/inner: 61 direct children.*60/);
});
test('native export rejects children under leaf controls including hidden icons', () => {
  for (const kind of ['image', 'text', 'cursorArea', 'grid']) {
    assert.throws(() => assertNativeUiCapacity({ name: 'layout', controls: [
      { name: 'bad', kind, visible: false, children: children(1) },
    ] }), /layout\/bad: only a container or presetButton may hold child controls/);
  }
  assert.doesNotThrow(() => assertNativeUiCapacity({ controls: [
    { name: 'button', kind: 'presetButton', children: children(1) },
  ] }));
});
