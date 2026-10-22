// Five-floor pages keep every touch target on the 1280 x 720 phone canvas.
// MapUI.new receives the mapPanel control; merge mapLayout().controls into a host UI.
const text = (name, x, y, w, h, content = '', fontSize = 18, colour = '#ECE6DA') => ({
  name, kind: 'text', position: [x, y], size: [w, h],
  text: { content, fontSize, colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: 14 },
});
const plate = (name, x, y, w, h, colour) => ({ name, kind: 'image', position: [x, y],
  size: [w, h], image: 100001, colour });
const hit = (w, h) => ({ name: 'hit', kind: 'cursorArea', size: [w, h], focusable: true });
const button = (name, x, label) => ({ name, kind: 'container', position: [x, -314], size: [180, 48], children: [
  plate('plate', 0, 0, 180, 48, '#272A36'), text('label', 0, 0, 172, 44, label, 20), hit(180, 48),
] });
export const mapGeometry = { columns: [-420, -180, 60], firstY: 192, rowGap: 96, rows: 5 };

export function mapLayout() {
  const controls = [plate('backdrop', 0, 0, 1240, 680, '#0F1117'),
    text('title', 0, 312, 1160, 44, '杀戮深渊 · 路线', 30, '#E3B866'),
    text('notice', 0, 263, 1160, 42, '', 18),
    text('page', -180, -261, 760, 40, '', 18),
    plate('legendPanel', 410, 0, 330, 456, '#1C1E27'),
    text('legend', 410, 0, 306, 432,
      '路线图例\n\n亮金 · 当前位置\n暗金 · 已走过\n白色 · 可前往\n灰色 · 锁定\n金线 · 已走路线\n灰线 · 后续路线\n\n左 / 中 / 右为路线列\n跨页去向见节点下方\n完成当前节点后继续', 18),
  ];
  // All possible neighboring edges are prebuilt. Lua shows only graph edges.
  for (let row = 1; row < 5; row++) for (let from = 1; from <= 3; from++) for (let to = 1; to <= 3; to++) {
    if (Math.abs(from - to) > 1) continue;
    const x1 = mapGeometry.columns[from - 1], x2 = mapGeometry.columns[to - 1];
    const y1 = mapGeometry.firstY - (row - 1) * mapGeometry.rowGap, y2 = y1 - mapGeometry.rowGap;
    for (const [state, colour] of [['normal', '#5A6078'], ['taken', '#E3B866']]) controls.push({
      ...plate(`edge${row}_${from}_${to}_${state}`, (x1 + x2) / 2, (y1 + y2) / 2,
        Math.hypot(x2 - x1, y2 - y1), 3, colour), rotation: Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI,
    });
  }
  for (let row = 1; row <= 5; row++) {
    const y = mapGeometry.firstY - (row - 1) * mapGeometry.rowGap;
    controls.push(text(`floor${row}`, -575, y, 62, 44));
    for (let lane = 1; lane <= 3; lane++) controls.push({
      name: `node${(row - 1) * 3 + lane}`, kind: 'container',
      position: [mapGeometry.columns[lane - 1], y], size: [214, 70], children: [
        plate('locked', 0, 0, 214, 70, '#4A4F63'), plate('visited', 0, 0, 214, 70, '#8E7448'),
        plate('current', 0, 0, 214, 70, '#F5D79A'), plate('available', 0, 0, 214, 70, '#ECE6DA'),
        plate('inset', 0, 0, 208, 64, '#1C1E27'),
        text('label', 0, 19, 206, 24, '', 18), text('status', 0, -3, 206, 20, '', 14),
        text('route', 0, -24, 206, 20, '', 14), hit(214, 70),
      ],
    });
  }
  controls.push(button('previous', -420, '前五层'), button('focus', -180, '当前进度'), button('next', 60, '后五层'));
  return { name: 'AbyssMap', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [{ name: 'mapPanel', kind: 'container', size: [1280, 720], children: controls }] };
}
