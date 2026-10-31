import test from 'node:test';
import assert from 'node:assert/strict';
import { nodeLayout } from '../scripts/node-ui-layout.mjs';
import { nativeTheme } from '../scripts/native-ui-theme.mjs';

const panel = nodeLayout().controls[0];
const find = (controls, name) => controls.find(c => c.name === name);
const views = ['shopView', 'campView', 'pickerView', 'eventView', 'treasureView'];
const bounds = (c, [x, y] = [0, 0]) => ({ left: x + c.position[0] - c.size[0] / 2, right: x + c.position[0] + c.size[0] / 2,
  bottom: y + c.position[1] - c.size[1] / 2, top: y + c.position[1] + c.size[1] / 2 });
const overlaps = (a, b) => a.left < b.right && a.right > b.left && a.bottom < b.top && a.top > b.bottom;
function walk(control, visit, origin = [0, 0]) {
  visit(control, origin);
  const next = [origin[0] + (control.position?.[0] ?? 0), origin[1] + (control.position?.[1] ?? 0)];
  for (const child of control.children ?? []) walk(child, visit, next);
}
const headerDecoration = ['headerShade', 'headerDivider', 'titleLineLeft', 'titleLineRight'];
const clickable = c => c.kind === 'container' && (c.children ?? []).some(child => child.kind === 'cursorArea');
// What the player sees together: shared chrome plus one view. The merchant appears only with the shop.
const screen = view => [...panel.children.filter(c => (c.visible !== false || c.name==='merchant' && view==='shopView') && !views.includes(c.name) && !['backdrop', 'topBar', ...headerDecoration].includes(c.name)
    && (c.name !== 'merchant' || view === 'shopView') && !(view==='shopView' && c.name==='back')),
  ...find(panel.children, view).children.filter(c => c.visible !== false && (c.kind !== 'image' || !['glow', 'plate', 'plateBorder'].includes(c.name)))];

test('node panel composes one container per approved node screen within the MCP child limit', () => {
  assert.equal(panel.name, 'nodePanel');
  assert.deepEqual(panel.size, [1280, 720]);
  for (const name of [...views, 'title', 'hp', 'gold', 'deck', 'relics', 'potions', 'notice', 'back', 'confirm']) {
    assert.ok(find(panel.children, name), name);
  }
  walk(panel, control => {
    assert.ok((control.children ?? []).length <= 50, control.name);
    const names = (control.children ?? []).map(c => c.name);
    assert.equal(new Set(names).size, names.length, `duplicate child in ${control.name}`);
  });
  for (const view of views) assert.equal(find(panel.children, view).visible, false, view);
});

test('framed node buttons preserve direct paths and have hidden hover and pressed face layers', () => {
  let count = 0;
  walk(panel, control => {
    if (!find(control.children ?? [], 'normal')) return;
    count++;
    for (const name of ['border','normal','hover','pressed','disabled','selected','hit']) {
      assert.ok(find(control.children,name), `${control.name}/${name}`);
    }
    assert.equal(find(control.children,'hit').kind,'cursorArea');
    for (const name of ['hover','pressed']) {
      const face=find(control.children,name);
      assert.equal(face.visible,false);
      assert.deepEqual(face.size,control.size.map(value=>value-nativeTheme.space.border*2));
    }
    const primary = find(control.children,'normal').colour === nativeTheme.color.geo;
    assert.equal(find(control.children,'hover').colour,primary ? nativeTheme.color.goldBright : nativeTheme.color.buttonHover);
    assert.equal(find(control.children,'pressed').colour,nativeTheme.color.goldDim);
  });
  assert.ok(count >= 15);
  assert.equal(nativeTheme.layout.nativeNode.buttonStates.pressedScale,0.96);
});

test('every interactive control is a full-size focusable touch target inside the safe area', () => {
  const [w, h] = nativeTheme.canvas.base, safe = nativeTheme.canvas.safe;
  let count = 0;
  walk(panel, (control, origin) => {
    if (!clickable(control)) return;
    count += 1;
    const hit = control.children.find(c => c.kind === 'cursorArea');
    assert.equal(hit.focusable, true, control.name);
    assert.deepEqual(hit.size, control.size, control.name);
    assert.ok(hit.size.every(value => value >= 44), control.name);
    const box = bounds(control, origin);
    assert.ok(box.left >= -w / 2 + safe.x && box.right <= w / 2 - safe.x, control.name);
    assert.ok(box.bottom >= -h / 2 + safe.y && box.top <= h / 2 - safe.y, control.name);
  });
  assert.ok(count >= 30);
});

test('node header decoration stays below readable content and has no input receivers', () => {
  const header = nativeTheme.layout.map.presentation.header;
  const specs = [
    ['headerShade', header.shade, nativeTheme.color.mapHeader.shade, nativeTheme.image.rect],
    ['headerDivider', header.divider, nativeTheme.color.mapHeader.border, nativeTheme.image.fadeLine],
    ['titleLineLeft', header.titleLineLeft, nativeTheme.color.mapHeader.title, nativeTheme.image.fadeLine],
    ['titleLineRight', header.titleLineRight, nativeTheme.color.mapHeader.title, nativeTheme.image.fadeLine],
  ];
  const titleIndex = panel.children.findIndex(c => c.name === 'title');
  for (const [name, frame, colour, image] of specs) {
    const control = find(panel.children, name);
    assert.equal(control.kind, 'image', name);
    assert.equal(control.image, image, name);
    assert.equal(control.colour, colour, name);
    assert.deepEqual(control.position, frame.slice(0, 2), name);
    assert.deepEqual(control.size, frame.slice(2), name);
    assert.ok(panel.children.indexOf(control) < titleIndex, name);
    assert.equal(control.children?.length ?? 0, 0, name);
    assert.equal(control.focusable, undefined, name);
  }
  assert.equal(find(panel.children, 'headerShade').opacity, header.shadeOpacity);
});

test('each screen keeps its readable elements and buttons free of sibling overlap', () => {
  for (const view of views) {
    const content = screen(view);
    for (let i = 0; i < content.length; i++) for (let j = i + 1; j < content.length; j++) {
      const [a, b] = [content[i], content[j]];
      // Four-choice event INTRO/reward pages hide the completion footer.
      // Real generated-control assertions cover this exclusivity in potion_event_ui.lua.
      if (view === 'eventView' && [a.name,b.name].includes('option4') && [a.name,b.name].includes('confirm')) continue;
      // Normal shops never show the retained compatibility controls.
      if (view === 'shopView' && [a,b].some(c => ['previous','next','relicPrevious','relicNext'].includes(c.name) && c.visible === false)) continue;
      // Picker previews alternate: before/after for forging, a single target for removal.
      if ([a.name, b.name].includes('target') && [a.name, b.name].some(n => ['before', 'after', 'arrow', 'empty'].includes(n))) continue;
      if ([a.name, b.name].includes('empty') && [a.name, b.name].some(n => ['before', 'after', 'arrow'].includes(n))) continue;
      // The chest hit area deliberately covers the closed/open pictures; the hint is replaced by the reward row.
      if (view === 'treasureView' && ([a.name, b.name].includes('chest') || ([a.name, b.name].includes('hint') && [a.name, b.name].includes('reward')))) continue;
      if (view === 'treasureView' && ['closed', 'open'].includes(a.name) && ['closed', 'open'].includes(b.name)) continue;
      // Closed-chest copy disappears before the Boss candidate selector appears.
      if (view === 'treasureView' && [a.name, b.name].includes('hint') && [a.name, b.name].some(n => ['page', 'previous', 'next'].includes(n))) continue;
      assert.ok(!overlaps(bounds(a), bounds(b)), `${view}: ${a.name} overlaps ${b.name}`);
    }
  }
});

test('native text boxes use the verified 40-unit line height and the readable minimum font', () => {
  const line = nativeTheme.layout.nativeText.lineHeight;
  walk(panel, control => {
    if (control.kind !== 'text') return;
    assert.ok(control.size[1] >= line, `${control.name} height ${control.size[1]}`);
    assert.ok(control.text.fontSize >= nativeTheme.font.minimum, control.name);
    assert.equal(control.text.minFontSize, nativeTheme.font.minimum);
  });
});

test('shop ports five colored cards above two colorless cards, with prices and service beside them', () => {
  const shop = find(panel.children, 'shopView').children;
  const cards = [1, 2, 3, 4, 5, 6, 7].map(i => find(shop, `card${i}`));
  const card = nativeTheme.layout.card;
  for (const [i, c] of cards.entries()) {
    assert.deepEqual(c.size, card.size);
    assert.equal(c.position[1], i < 5 ? cards[0].position[1] : cards[5].position[1]);
    if (i && i !== 5) assert.ok(c.position[0] > cards[i - 1].position[0]);
    for (const name of ['border', 'nameBand', 'name', 'artPlate', 'type', 'description', 'costDisc', 'cost', 'veil', 'stamp', 'glow']) {
      assert.ok(find(c.children, name), `${c.name}.${name}`);
    }
    assert.deepEqual(find(c.children, 'description').size, card.textBox);
    assert.deepEqual(find(c.children, 'costDisc').size, [card.costDisc, card.costDisc]);
    const price = find(shop, `price${i + 1}`);
    assert.equal(price.position[0], c.position[0]);
    assert.ok(bounds(price).top <= bounds(c).bottom, 'price sits beneath its card');
    assert.ok(find(price.children, 'coin') && find(price.children, 'value'));
  }
  const removal = find(shop, 'removal');
  assert.ok(bounds(removal).top < bounds(cards[0]).bottom, 'removal service is in the second row');
  assert.equal(find(shop, 'removalPrice').position[0], removal.position[0]);
  const relics = [1, 2, 3].map(i => find(shop, `relic${i}`));
  for (const relic of relics) assert.ok(bounds(relic).top < bounds(find(shop, 'price1')).bottom, 'relic row below the shelf');
  assert.equal(find(panel.children, 'confirm').position[0] > 0, true, 'leave button bottom-right');
});

test('camp, forge, event and treasure follow the approved composition', () => {
  const camp = find(panel.children, 'campView').children;
  const [rest, forge] = ['rest', 'forge'].map(name => find(camp, name));
  assert.deepEqual(rest.size, [240, 240]); assert.deepEqual(forge.size, [240, 240]);
  assert.equal(rest.position[1], forge.position[1]); assert.ok(rest.position[0] < 0 && forge.position[0] > 0);
  const picker = find(panel.children, 'pickerView').children;
  const [before, after, row] = ['before', 'after', 'card1'].map(name => find(picker, name));
  assert.ok(before.position[0] < 0 && after.position[0] > 0 && before.position[1] === after.position[1]);
  assert.ok(bounds(before).top < bounds(row).bottom, 'preview sits below the deck row');
  for (const preview of [before, after]) {
    assert.equal(find(preview.children, 'hit').kind, 'cursorArea', 'read-only rules inspector uses a cursor receiver');
    assert.ok(!preview.children.some(c => c.kind === 'presetButton'), 'inspection cannot submit an upgrade');
  }
  const event = find(panel.children, 'eventView').children;
  assert.ok(bounds(find(event, 'plate')).right < bounds(find(event, 'option1')).left, 'illustration left, options right');
  for (const i of [1, 2, 3]) assert.ok(find(find(event, `option${i}`).children, 'title') && find(find(event, `option${i}`).children, 'description'));
  const chest = find(panel.children, 'treasureView').children;
  assert.equal(find(chest, 'closed').position[0], 0);
  assert.equal(find(chest, 'closed').image, nativeTheme.icon.medallion.treasure);
  assert.equal(find(chest, 'open').image, nativeTheme.icon.medallion.chestOpen);
  assert.ok(bounds(find(chest, 'reward')).top <= bounds(find(chest, 'closed')).bottom);
});


test('each enlarged shop card keeps every price, the merchant and mobile cancel readable',()=>{
 const l=nativeTheme.layout.nativeNode.shop;
 const shop=find(panel.children,'shopView').children;
 for(let focus=1;focus<=7;focus++) {
  const items=shop.filter(c=>c.visible!==false && !['page','detail'].includes(c.name)).map(c=>structuredClone(c));
  for(const c of items){
   const card=/^card(\d+)$/.exec(c.name),price=/^price(\d+)$/.exec(c.name);
   const i=Number((card||price)?.[1]);
   if(card){c.position[1]-=i>5?l.focusRowShift:0;if(i===focus)c.size=c.size.map(v=>v*l.hoverScale);}
   if(price){c.position[1]-=i>5?l.focusRowShift:0;if(i===focus)c.position[1]-=(l.hoverScale-1)*nativeTheme.layout.card.size[1]/2;}
  }
  items.push(find(panel.children,'merchant'),find(panel.children,'notice'),find(panel.children,'confirm'),
   {name:'cancel',position:l.cancel.slice(0,2),size:l.cancel.slice(2)});
  for(let a=0;a<items.length;a++)for(let b=a+1;b<items.length;b++)
   assert.ok(!overlaps(bounds(items[a]),bounds(items[b])), 'focus '+focus+': '+items[a].name+' overlaps '+items[b].name);
  for(const c of items){const r=bounds(c);assert.ok(r.left>=-600 && r.right<=600 && r.bottom>=-340 && r.top<=340,c.name);}
 }
});
test('source reward rows and the twelve-card smithing grid fit without hiding neighboring content',()=>{
 const l=nativeTheme.layout.nativeNode;
 const items=l.rewardList.rows.map((y,i)=>({name:'reward'+i,position:[l.rewardList.x,y],size:l.rewardList.size}));
 for(const name of ['heading','note'])items.push({name,position:l.rewardList[name].slice(0,2),size:l.rewardList[name].slice(2)});
 items.push(find(panel.children,'notice'),find(panel.children,'back'));
 for(let a=0;a<items.length;a++)for(let b=a+1;b<items.length;b++)assert.ok(!overlaps(bounds(items[a]),bounds(items[b])),items[a].name+' / '+items[b].name);
 const grid=find(find(panel.children,'pickerView').children,'forgeGrid').children;
 assert.equal(grid.length,12);
 for(let a=0;a<grid.length;a++)for(let b=a+1;b<grid.length;b++)assert.ok(!overlaps(bounds(grid[a]),bounds(grid[b])));
 for(const card of grid){const r=bounds(card);assert.ok(r.left>=-600 && r.right<=600 && r.bottom>=-340 && r.top<=242);}
 const picker=find(panel.children,'pickerView').children;
 for(const name of ['forgePrevious','forgeNext']){
  const arrow=find(picker,name);
  for(const c of [...grid,find(panel.children,'back'),find(panel.children,'confirm')])
   assert.ok(!overlaps(bounds(arrow),bounds(c)),name+' overlaps '+c.name);
 }
});
