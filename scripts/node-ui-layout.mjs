// Native controls on the shared centred 1280 x 720 canvas.
const text = (name, x, y, w, h, content = '', fontSize = 18, colour = '#ECE6DA') => ({
  name, kind: 'text', position: [x, y], size: [w, h],
  text: { content, fontSize, colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: 14 },
});
const plate = (name, w, h, colour) => ({ name, kind: 'image', size: [w, h], image: 100001, colour });
const button = (name, x, y, w, h, label = '') => ({
  name, kind: 'container', position: [x, y], size: [w, h], children: [
    plate('normal', w, h, '#433C30'), plate('disabled', w, h, '#272A36'),
    plate('selected', w, h, '#8E7448'), text('label', 0, 0, w - 20, h - 8, label, 19),
    { name: 'hit', kind: 'cursorArea', size: [w, h], focusable: true },
  ],
});
export const nodeGeometry = { columns: [-280, 280], rows: [90, -5, -100, -195], actionSize: [540, 80], pageSize: 8 };
export function nodeLayout() {
  const controls = [plate('backdrop', 1240, 680, '#0F1117'),
    text('title', 0, 310, 1160, 44, '', 30, '#E3B866'),
    text('resources', 0, 265, 1160, 38), text('notice', 0, 220, 1160, 42),
    text('page', 0, -263, 760, 28, '', 16),
  ];
  for (const [i, label] of ['卡牌', '遗物', '删牌'].entries()) controls.push(button(`tab${i + 1}`, (i - 1) * 280, 168, 240, 44, label));
  for (let i = 0; i < 8; i++) controls.push(button(`action${i + 1}`, nodeGeometry.columns[i % 2], nodeGeometry.rows[Math.floor(i / 2)], ...nodeGeometry.actionSize));
  controls.push(button('previous', -430, -310, 180, 48, '上一页'),
    button('leave', 0, -310, 240, 48, '返回路线'), button('next', 430, -310, 180, 48, '下一页'));
  return { name: 'AbyssNodes', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [{ name: 'nodePanel', kind: 'container', size: [1280, 720], children: controls }] };
}
