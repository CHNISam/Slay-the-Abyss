import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { toLua } from './build-lua-data.mjs';

export const loadMapTheme = () => JSON.parse(readFileSync('data/presentation/ui_theme.json', 'utf8'));

// Positions absent from the shared theme come from PR #19's approved map viewport.
// These are presentation capacities, never a replacement for Map.view's graph.
export function mapGeometry(theme = loadMapTheme()) {
  const { floorGap, viewportHeight } = theme.layout.map;
  return { floors: 17, generatedRows: 15, lanes: 7, maxNodes: 92, maxEdges: 126,
    viewport: { left: -460, right: 440, bottom: -308, top: -308 + viewportHeight },
    firstY: -308 + 60, contentHeight: 17 * floorGap + 120,
    maxScroll: 17 * floorGap + 120 - viewportHeight, focusY: -128,
    scrollStep: floorGap * theme.layout.map.scrollStepFloors, scrollSeconds: theme.motion.base,
    breathSeconds: 1.4, breathScale: 1.1,
    glowPadding: 12, lineWidth: 4, dragThreshold: theme.layout.cardDrag.threshold };
}

export function mapLayout(theme = loadMapTheme()) {
  const g = mapGeometry(theme), c = theme.color, f = theme.font, im = theme.image;
  const text = (name, x, y, w, h, content = '', fontSize = f.body, colour = c.text) => ({
    name, kind: 'text', position: [x, y], size: [w, h],
    text: { content, fontSize, colour, align: 'centre', valign: 'middle', autoSize: true, minFontSize: f.minimum },
  });
  const image = (name, x, y, w, h, colour, picture = im.rect) => ({
    name, kind: 'image', position: [x, y], size: [w, h], image: picture, colour,
  });
  const hit = (w, h) => ({ name: 'hit', kind: 'cursorArea', size: [w, h], focusable: true });
  const button = (name, y, label) => ({ name, kind: 'container', position: [-522, y], size: [148, 52], children: [
    image('frame', 0, 0, 148, 52, c.goldDim), image('body', 0, 0, 144, 48, c.panel),
    text('label', 0, 0, 140, 44, label, f.label), hit(148, 52),
  ] });
  const { left, right, bottom, top } = g.viewport;
  const controls = [
    // Lowest layer: dragging anywhere on the route scrolls it; node hits sit above.
    { name: 'dragArea', kind: 'cursorArea', position: [(left + right) / 2, (bottom + top) / 2],
      size: [right - left, top - bottom], focusable: false },
    text('title', 0, 327, 640, 44, '', f.heading, c.goldBright),
    text('notice', 0, -324, 1160, 28, '', f.small, c.textDim),
    button('next', 160, '向上查看'), button('focus', 96, '当前进度'), button('previous', 32, '向下查看'),
    image('legendFrame', 526, 24, 148, 456, c.goldDim), image('legendBody', 526, 24, 144, 452, c.panel),
    text('legendTitle', 526, 228, 128, 28, '图例', f.label, c.goldBright),
    text('legendStateTitle', 526, -44, 128, 28, '节点状态', f.label, c.goldBright),
  ];
  const names = { combat: '战斗', elite: '精英', camp: '营地', shop: '商店', event: '事件', treasure: '宝箱', boss: '首领' };
  Object.entries(names).forEach(([kind, name], i) => {
    controls.push(image(`legend_${kind}`, 482, 194 - i * 34, 24, 24, c.textDim, theme.icon.node[kind]),
      text(`legendLabel_${kind}`, 539, 194 - i * 34, 76, 28, name, f.label));
  });
  // Node state is a ring colour on the map, so the legend shows the same ring, not colour words.
  const states = [['current', c.node.current, '当前位置'], ['visited', c.node.visited, '已走过'],
    ['available', c.node.reachable, '可前往'], ['locked', c.node.locked, '暂不可达']];
  states.forEach(([state, colour, name], i) => {
    controls.push(image(`legendRing_${state}`, 482, -78 - i * 34, 24, 24, colour, im.disc),
      image(`legendDot_${state}`, 482, -78 - i * 34, 16, 16, c.panel, im.disc),
      text(`legendStateLabel_${state}`, 539, -78 - i * 34, 76, 28, name, f.label));
  });
  // Runtime clips these line segments geometrically to the 600px viewport.
  for (let i = 1; i <= g.maxEdges; i++) controls.push({
    ...image(`edge${i}`, 0, 0, 1, g.lineWidth, c.node.path), visible: false,
  });
  for (let i = 1; i <= g.maxNodes; i++) {
    const s = theme.layout.map.node;
    const children = [image('glow', 0, 0, s + g.glowPadding, s + g.glowPadding, c.goldBright, im.glow)];
    for (const [state, colour] of Object.entries({ locked: c.node.locked, visited: c.node.visited,
      current: c.node.current, available: c.node.reachable })) children.push(image(state, 0, 0, s, s, colour, im.disc));
    children.push(image('body', 0, 0, s - theme.space.border * 2, s - theme.space.border * 2, c.panel, im.disc),
      image('icon', 0, 0, s * .6, s * .6, c.node.locked, theme.icon.node.combat), hit(s, s));
    controls.push({ name: `node${i}`, kind: 'container', position: [0, 0], size: [s, s], visible: false, children });
  }
  // MCP accepts at most 60 children per control. Keep draw order and positions
  // while putting the large edge/node pools in zero-offset containers.
  const groups = [];
  for (let i = 0; i < controls.length; i += 50) groups.push({
    name: `mapGroup${groups.length + 1}`, kind: 'container', size: theme.canvas.base,
    children: controls.slice(i, i + 50),
  });
  return { name: 'AbyssMap', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [image('mapBackdrop', 0, 0, ...theme.canvas.base, c.backdrop),
      { name: 'stage', kind: 'container', size: theme.canvas.base, children: [
        { name: 'mapPanel', kind: 'container', size: theme.canvas.base, children: groups },
      ] }],
  };
}

// Build separately so no shared battle entry point or package command is changed.
export function buildMapLayout(output = 'build/map-ui.json', contract = 'build/lua/abyss_map_layout.lua',
  controls = 'build/lua/abyss_map_controls.lua') {
  const theme = loadMapTheme();
  const layout = mapLayout(theme);
  for (const file of [output, contract, controls]) mkdirSync(dirname(file), { recursive: true });
  writeFileSync(output, JSON.stringify(layout, null, 2) + '\n');
  writeFileSync(contract, '-- Generated by scripts/map-ui-layout.mjs. Do not edit.\nreturn ' + toLua(mapGeometry(theme)) + '\n');
  // Same schema in Lua lets the test harness exercise the exact generated tree.
  writeFileSync(controls, '-- Generated map control schema.\nreturn ' + toLua(layout) + '\n');
}

// Main UI builds can put all runtime artifacts in the same custom directory.
export function buildMapUI(outputDirectory = 'build/lua') {
  buildMapLayout(join(outputDirectory, 'map-ui.json'),
    join(outputDirectory, 'abyss_map_layout.lua'), join(outputDirectory, 'abyss_map_controls.lua'));
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  buildMapLayout();
  console.log('Map controls and Lua layout contract built.');
}
