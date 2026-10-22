import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

export const nodeGeometry = structuredClone(nativeTheme.layout.nativeNode.geometry);

export function nodeLayout(theme = nativeTheme) {
  const { text, plate, button, frame } = nativeControls(theme);
  const layout = theme.layout.nativeNode, geometry = layout.geometry, { color, font } = theme;
  const action = (name, values, label = '') => button(name, values, label, { inset: layout.buttonInset, states: true });
  const controls = [plate('backdrop', layout.backdrop, color.backdrop),
    text('title', layout.title, '', font.title, color.gold),
    text('resources', layout.resources), text('notice', layout.notice), text('page', layout.page, '', font.label),
  ];
  for (const [i, label] of ['卡牌', '遗物', '删牌'].entries()) controls.push(action(`tab${i + 1}`,
    frame(layout.tabs.origin.map((value, axis) => value + i * layout.tabs.step[axis]), layout.tabs.size), label));
  for (let i = 0; i < geometry.pageSize; i++) controls.push(action(`action${i + 1}`,
    frame([geometry.columns[i % geometry.columns.length], geometry.rows[Math.floor(i / geometry.columns.length)]], geometry.actionSize)));
  const shop = layout.shop;
  const [cardWidth, cardHeight] = theme.layout.card.size;
  const lineHeight = theme.layout.nativeText.lineHeight;
  const itemSize = [cardWidth, cardHeight];
  const priceY = -cardHeight / 2 - theme.space.l - lineHeight / 2;
  for (let i = 0; i < shop.pageSize; i++) {
    const item = action(`shop${i + 1}`, frame(
      [shop.columns[i % shop.columns.length], shop.rows[Math.floor(i / shop.columns.length)]], itemSize));
    const name = frame([0, cardHeight / 2 - lineHeight / 2], [cardWidth - theme.space.s, lineHeight]);
    const description = frame([0, -cardHeight / 2 + theme.layout.card.textBox[1] / 2 + theme.space.xs], theme.layout.card.textBox);
    const price = frame([0, priceY], [cardWidth + theme.space.l, lineHeight]);
    item.children.push(text('name', name, '', font.cardName, color.gold),
      text('description', description, '', font.card, color.text),
      text('price', price, '', font.label, color.gold),
      text('unavailablePrice', price, '', font.label, color.danger));
    for (const [kind, icon] of Object.entries(theme.icon.cardArt)) item.children.push(
      plate(`artPlate_${kind}`, frame([0, theme.layout.card.art / 2],
        [cardWidth - theme.space.border * 2, theme.layout.card.art]), color.cardType[kind] ?? color.panelRaised), {
        name: `art_${kind}`, kind: 'image', position: [0, theme.layout.card.art / 2],
        size: [lineHeight, lineHeight], image: icon, colour: color.text,
      });
    item.children.push({ name: 'art_relic', kind: 'image', position: [0, theme.layout.card.art / 2],
      size: [lineHeight, lineHeight], image: theme.icon.node.treasure, colour: color.gold });
    controls.push(item);
  }
  controls.push(action('previous', layout.previous, '上一页'), action('leave', layout.leave, '返回路线'),
    action('next', layout.next, '下一页'));
  return { name: 'AbyssNodes', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [{ name: 'nodePanel', kind: 'container', size: [...theme.canvas.base], children: controls }] };
}
