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
  controls.push(action('previous', layout.previous, '上一页'), action('leave', layout.leave, '返回路线'),
    action('next', layout.next, '下一页'));
  return { name: 'AbyssNodes', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [{ name: 'nodePanel', kind: 'container', size: [...theme.canvas.base], children: controls }] };
}
