import { battleLayout } from './ui-layout.mjs';
import { mapLayout } from './map-ui-layout.mjs';
import { nodeLayout } from './node-ui-layout.mjs';
import { nativeControls, nativeTheme } from './native-ui-theme.mjs';
import { deckControls } from './deck-ui-layout.mjs';
import { exitControls } from './exit-ui-layout.mjs';
import { potionDiscardControls } from './potion-discard-layout.mjs';
import { prologueControl, vistaControl } from './cinematic-ui-layout.mjs';
import { experimentalCharacterControls } from './character-ui-layout.mjs';

// Approved win.png shows four cells; each is backed by a stat the run already records.
export const resultStats = ['floor', 'victories', 'time', 'deck'];

// Native four-state buttons and bounded text rows; the runtime never truncates notes.
function releaseNotesControls(theme) {
  const { plate, text } = nativeControls(theme);
  const { color: c, font: f, space: s } = theme, l = theme.layout.releaseNotes;
  const line = (name, frame, content = '', font = f.body, ink = c.text) => {
    const item = text(name, frame, content, font, ink);
    item.text.autoSize = false;
    return item;
  };
  const button = (name, frame, label) => {
    const size = frame.slice(2);
    const variants = { normal: [c.panelRaised, c.goldBright, c.goldDim],
      hover: [c.buttonHover, c.goldBright, c.goldBright],
      pressed: [c.goldDim, c.buttonPressedText, c.goldBright], disabled: [c.panelSunken, c.textMuted, c.line] };
    return { name, kind: 'container', position: frame.slice(0, 2), size, children: [
      { name: 'hit', kind: 'presetButton', size: [...size], focusable: true,
        states: Object.fromEntries(Object.keys(variants).map(state => [state, state])),
        children: Object.entries(variants).map(([state, [fill, ink, border]]) => ({
          name: state, kind: 'container', size: [...size],
          scale: state === 'pressed' ? [l.pressedScale, l.pressedScale] : [1, 1], children: [
            plate('border', [0, 0, ...size], border),
            plate('face', [0, 0, ...size.map(value => value - s.border * 2)], fill),
            line('label', [0, 0, ...size.map((value, i) => value - l.buttonInset[i])], label, f.label, ink),
          ],
        })),
      },
    ] };
  };
  const panel = { name: 'releaseNotesPanel', kind: 'container', size: [...theme.canvas.base], visible: false,
    children: [
      plate('veil', [0, 0, ...theme.canvas.base], c.backdropVeil),
      { name: 'blocker', kind: 'cursorArea', size: [...theme.canvas.base], focusable: false },
      plate('border', l.panel, c.goldDim),
      plate('face', [...l.panel.slice(0, 2), ...l.panel.slice(2).map(value => value - s.border * 2)], c.panel),
      line('title', l.title, '更新公告', f.heading, c.goldBright),
      line('build', l.build, '', f.label, c.textDim),
      button('history', l.history, '已发布记录'), button('current', l.current, '本次版本说明'),
      line('version', l.version, '', f.heading, c.gold), line('date', l.date, '', f.label, c.textDim),
      button('newer', l.newer, '较新'), button('older', l.older, '较早'),
      ...Array.from({ length: l.rows }, (_, i) => {
        const row = line(`row${i + 1}`, [l.row[0], l.row[1] - i * l.rowStep, ...l.row.slice(2)]);
        row.text.align = 'left';
        return row;
      }),
      button('previous', l.previous, '上一页'), line('page', l.page, '', f.label, c.textDim),
      button('next', l.next, '下一页'), button('close', l.close, '返回主菜单'),
    ] };
  return { entry: button('releaseNotes', l.entry, '更新公告'),
    version: line('codeVersion', l.menuVersion, '', f.small, c.textDim), panel };
}

export function gameLayout(theme = nativeTheme, options = {}) {
  const { text, plate, button, frame, centred } = nativeControls(theme);
  const layout = theme.layout.nativeMenu, { color, font, space, image } = theme;
  const battle = structuredClone(battleLayout());
  const battleControls = battle.controls.find(control => control.name === 'stage').children;
  const map = structuredClone(mapLayout(theme));
  const mapPanel = map.controls.find(control => control.name === 'stage').children.find(control => control.name === 'mapPanel');
  mapPanel.visible = false;
  // Leave the existing node potion-counter position free for the shared entry.
  for (const group of mapPanel.children) for (const item of group.children ?? []) {
    if (item.name === 'title') {
      item.position = theme.layout.nativeNode.topBar.title.slice(0, 2);
      item.size = theme.layout.nativeNode.topBar.title.slice(2);
    }
  }
  // Route choices need the same resources as room decisions, before entering a shop.
  const bar = theme.layout.nativeNode.topBar;
  const resourceIcon = (name, values, entry, colour) => ({ name, kind: 'image',
    position: values.slice(0, 2), size: values.slice(2),
    image: typeof entry === 'object' ? entry.id : entry, colour });
  mapPanel.children.push({ name: 'resources', kind: 'container', size: [...theme.canvas.base], children: [
    resourceIcon('hpIcon', bar.hpIcon, theme.icon.hp, color.hp),
    text('hp', bar.hp, '', font.body, color.text),
    resourceIcon('goldIcon', bar.goldIcon, theme.icon.gold, color.text),
    text('gold', bar.gold, '', font.body, color.goldBright),
  ] });
  const picture = (name, size, id, colour) => ({ name, kind: 'image', position: [...theme.layout.nativeControl.origin],
    size, image: id, colour });
  const [ex, ey, ew, eh] = layout.emblem;
  // Shared by menu and results: glow, sunken disc and Geo mark; Lua recolours it per outcome.
  const emblem = { name: 'emblem', kind: 'container', position: [ex, ey], size: [ew, eh], children: [
    picture('glow', [ew + layout.emblemGlow, eh + layout.emblemGlow], image.glow, color.goldBright),
    picture('disc', [ew, eh], image.disc, color.panelSunken),
    picture('icon', [ew - layout.emblemInset, eh - layout.emblemInset], theme.icon.geo, color.geo),
  ] };
  const notice = releaseNotesControls(theme);
  const stats = layout.stats, [cw, ch] = stats.size;
  const statCard = (key, i) => ({ name: `stat_${key}`, kind: 'container',
    position: [stats.origin[0] + i * stats.step, stats.origin[1]], size: [cw, ch], children: [
      plate('border', centred([cw + space.border, ch + space.border]), color.line),
      plate('face', centred([cw, ch]), color.panel),
      text('label', frame([0, stats.label], [cw - space.l, font.label + space.l]), '', font.label, color.textDim),
      text('value', frame([0, stats.value], [cw - space.l, font.numberLarge + space.l]), '', font.numberLarge, color.text),
    ] });
  const layoutTree = {
    name: 'SlayTheAbyss', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [
      { name: 'battlePanel', kind: 'container', size: [...theme.canvas.base], visible: false, children: battleControls },
      mapPanel,
      { ...button('combatRewards', theme.layout.battleRewards.return, '返回战利品', {
        inset: [space.s, space.s], fontSize: font.label, border: color.goldDim }), visible: false },
      ...nodeLayout(theme).controls.map(control => ({ ...control, visible: false, children: control.children.map(child =>
        child.name === 'title' ? { ...child, size: [theme.layout.nativeNode.topBar.title[2], child.size[1]] }
          : child.name === 'notice' ? { ...child, position: theme.layout.exitMenu.nodeNotice.slice(0, 2),
            size: theme.layout.exitMenu.nodeNotice.slice(2) } : child) })),
      { name: 'menuPanel', kind: 'container', size: [...theme.canvas.base], children: [
        plate('backdrop', layout.backdrop, color.backdrop),
        vistaControl(theme),
        emblem,
        text('title', layout.title, '杀戮原塔2', font.display, color.gold),
        text('tagline', layout.tagline, '', font.heading, color.goldDim),
        text('summary', layout.summary, '', font.body, color.textDim),
        { name: 'result', kind: 'container', size: [...theme.canvas.base], visible: false, children: [
          text('subtitle', layout.subtitle, '', font.body, color.textDim),
          ...resultStats.map(statCard),
          text('detail', layout.detail, '', font.label, color.textDim),
          text('status', layout.status, '', font.small, color.textMuted),
        ] },
        button('start', layout.start, '启程', { inset: layout.buttonInset, fontSize: font.heading,
          colour: color.textOnLight, fill: color.gold, border: color.goldBright }),
        button('battleSpeed', theme.layout.nativeMenu.battleSpeed, '战斗速度：普通', { inset: layout.buttonInset, fontSize: font.label, states: true }),
        notice.entry, notice.version,
        { ...button('settle', layout.settle, '结束并结算', { inset: layout.buttonInset, states: true,
          fontSize: font.heading, colour: color.gold, border: color.gold }), visible: false },
      ] },
      // Above every page so its last fade can uncover the map; below the deck and exit overlays.
      prologueControl(theme),
      ...deckControls(theme),
      ...potionDiscardControls(theme),
      ...(options.experimentalCharacters === true || options.originalCharacters === true ? experimentalCharacterControls(theme,options) : []),
      ...exitControls(theme),
      notice.panel,
    ],
  };
  const overlays = new Set(['deckPanel', 'potionPanel', 'choicePanel', 'characterPanel', 'exitPanel', 'prologuePanel', 'releaseNotesPanel']);
  for (const control of layoutTree.controls) if (overlays.has(control.name)) control.isolateNavigation = true;
  return layoutTree;
}
