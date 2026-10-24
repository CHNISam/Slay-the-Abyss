import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync('docs/design/prototype/index.html', 'utf8');
function fixture(targeted = false) {
  const calls = [];
  const el = { style: { left: '550px', top: '506px' }, classList: { add() {}, remove() {}, toggle() {} }, setPointerCapture() {} };
  const enemy = { style: { left: '900px', top: '220px', width: '120px', height: '160px' }, classList: { toggle() {}, remove() {} } };
  const context = vm.createContext({
    B: { busy: false, sel: -1, hand: [{ targeted }], foes: [{ hp: 50 }] }, el, i: 0,
    cv: { getBoundingClientRect: () => ({ left: 0, top: 0, width: 1280 }) },
    document: { getElementById: id => id === 'playline' ? el : enemy },
    performance: { now: () => 1 }, setTimeout() {}, renderBattle() {}, SPEED: 1,
    needsTarget: c => c.targeted, playable: () => true, eff: () => ({ cost: 1 }), pop() {},
    play: (slot, target) => calls.push({ slot, target }),
  });
  context.card = context.B.hand[0];
  vm.runInContext(html.slice(html.indexOf('let drag=null,dragJustEnded=false;'), html.indexOf('function blockBadge(')), context);
  const pointer = (fn, x, y, id = 7, type = 'pointerup') => {
    context.event = { clientX: x, clientY: y, pointerId: id, type };
    vm.runInContext(`${fn}(event${fn === 'dragStart' ? ',el,0,0,0' : ''})`, context);
  };
  return { context, calls, pointer };
}

test('prototype same-card clicks select then cancel without issuing a play', () => {
  const { context, calls } = fixture();
  const start = html.indexOf('el.onclick=(e)=>', html.indexOf('function renderBattle('));
  const end = html.indexOf('\n    cv.append(el)', start);
  vm.runInContext(html.slice(start, end), context);
  context.event = { stopPropagation() {} };
  vm.runInContext('el.onclick(event)', context);
  assert.equal(context.B.sel, 0);
  vm.runInContext('el.onclick(event)', context);
  assert.equal(context.B.sel, -1);
  assert.equal(calls.length, 0);
});

test('prototype no-target drag submits once on the field and ignores foreign pointer releases', () => {
  const { calls, pointer } = fixture();
  pointer('dragStart', 620, 600);
  pointer('dragMove', 500, 300);
  pointer('dragEnd', 500, 300, 8);
  assert.equal(calls.length, 0);
  pointer('dragEnd', 500, 300);
  pointer('dragEnd', 500, 300);
  assert.deepEqual(calls, [{ slot: 0, target: null }]);
});

test('prototype explicit field requires a fresh stationary tap and consumes its click', () => {
  for (const mode of ['tap', 'swipe', 'cancel', 'outside']) {
    const { context, calls } = fixture();
    context.area = {};
    vm.runInContext('B.sel=0;bindPlayArea(area)', context);
    const event = (x, y) => ({ pointerId: 7, clientX: x, clientY: y, stopPropagation() {} });
    context.area.onpointerdown(event(500, 300));
    if (mode === 'swipe') context.area.onpointermove(event(600, 300));
    if (mode === 'cancel') context.area.onpointercancel(event(500, 300));
    context.area.onpointerup(event(mode === 'outside' ? 1300 : 500, 300));
    context.area.onclick({ ...event(500, 300), pointerId: 8 });
    assert.equal(calls.length, 0, 'foreign click must not submit or consume the owned click');
    context.area.onclick(event(500, 300));
    context.area.onclick(event(500, 300));
    assert.equal(calls.length, mode === 'tap' ? 1 : 0, mode);
  }
});

test('prototype cancellation and outside-field releases never submit a no-target card', () => {
  for (const [x, y, type] of [[500, 300, 'pointercancel'], [500, 600, 'pointerup'], [1300, 300, 'pointerup'], [500, 50, 'pointerup']]) {
    const { calls, pointer } = fixture();
    pointer('dragStart', 620, 600);
    pointer('dragMove', 500, 300);
    pointer('dragEnd', x, y, 7, type);
    assert.equal(calls.length, 0, `${x},${y},${type}`);
  }
});

test('prototype target cards cancel on open ground and play only on an enemy', () => {
  for (const [x, y, expected] of [[500, 300, 0], [950, 280, 1]]) {
    const { calls, pointer } = fixture(true);
    pointer('dragStart', 620, 600);
    pointer('dragMove', x, y);
    pointer('dragEnd', x, y);
    assert.equal(calls.length, expected);
    if (expected) assert.equal(calls[0].target, 0);
  }
});
