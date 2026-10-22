import { nativeControls, nativeTheme } from './native-ui-theme.mjs';

export const mapGeometry = structuredClone(nativeTheme.layout.nativeMap.geometry);

export function mapLayout(theme = nativeTheme) {
  const { text, plate, hit, button, frame, centred } = nativeControls(theme);
  const layout = theme.layout.nativeMap, geometry = layout.geometry, { color, font } = theme;
  const controls = [plate('backdrop', layout.backdrop, color.backdrop),
    text('title', layout.title, '杀戮深渊 · 路线', font.title, color.gold),
    text('notice', layout.notice), text('page', layout.page),
    plate('legendPanel', layout.legendPanel, color.panel),
    text('legend', layout.legend,
      '路线图例\n\n亮金 · 当前位置\n暗金 · 已走过\n白色 · 可前往\n灰色 · 锁定\n金线 · 已走路线\n灰线 · 后续路线\n\n左 / 中 / 右为路线列\n跨页去向见节点下方\n完成当前节点后继续'),
  ];
  // Lua shows only actual graph edges from these prebuilt neighbors.
  const columns = geometry.columns.length;
  for (let row = 1; row < geometry.rows; row++) for (let from = 1; from <= columns; from++) for (let to = 1; to <= columns; to++) {
    if (Math.abs(from - to) > 1) continue;
    const x1 = geometry.columns[from - 1], x2 = geometry.columns[to - 1];
    const y1 = geometry.firstY - (row - 1) * geometry.rowGap, y2 = y1 - geometry.rowGap;
    for (const [state, colour] of [['normal', color.node.path], ['taken', color.node.pathTaken]]) controls.push({
      ...plate(`edge${row}_${from}_${to}_${state}`, [(x1 + x2) / 2, (y1 + y2) / 2,
        Math.hypot(x2 - x1, y2 - y1), layout.edgeWidth], colour),
      rotation: Math.atan2(y2 - y1, x2 - x1) * 180 / Math.PI,
    });
  }
  for (let row = 1; row <= geometry.rows; row++) {
    const y = geometry.firstY - (row - 1) * geometry.rowGap;
    const floor = [...layout.floor]; floor[1] = y;
    controls.push(text(`floor${row}`, floor));
    for (let lane = 1; lane <= columns; lane++) controls.push({
      name: `node${(row - 1) * columns + lane}`, kind: 'container',
      position: [geometry.columns[lane - 1], y], size: [...layout.nodeSize], children: [
        ...[['locked', 'locked'], ['visited', 'visited'], ['current', 'current'], ['available', 'reachable']]
          .map(([name, token]) => plate(name, centred(layout.nodeSize), color.node[token])),
        plate('inset', centred(layout.nodeInsetSize), color.panel),
        text('label', layout.label), text('status', layout.status, '', font.small),
        text('route', layout.route, '', font.small), hit(layout.nodeSize),
      ],
    });
  }
  for (const [index, [name, label]] of [['previous', '前五层'], ['focus', '当前进度'], ['next', '后五层']].entries()) {
    const nav = layout.navigation;
    controls.push(button(name, frame([nav.columns[index], nav.y], nav.size), label, { inset: nav.inset }));
  }
  return { name: 'AbyssMap', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [{ name: 'mapPanel', kind: 'container', size: [...theme.canvas.base], children: controls }] };
}
