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
  const stats = layout.stats, [cw, ch] = stats.size;
  const statCard = (key, i) => ({ name: `stat_${key}`, kind: 'container',
    position: [stats.origin[0] + i * stats.step, stats.origin[1]], size: [cw, ch], children: [
      plate('border', centred([cw + space.border, ch + space.border]), color.line),
      plate('face', centred([cw, ch]), color.panel),
      text('label', frame([0, stats.label], [cw - space.l, font.label + space.l]), '', font.label, color.textDim),
      text('value', frame([0, stats.value], [cw - space.l, font.numberLarge + space.l]), '', font.numberLarge, color.text),
    ] });
  return {
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
        { ...button('settle', layout.settle, '结束并结算', { inset: layout.buttonInset, states: true,
          fontSize: font.heading, colour: color.gold, border: color.gold }), visible: false },
      ] },
      // Above every page so its last fade can uncover the map; below the deck and exit overlays.
      prologueControl(theme),
      ...deckControls(theme),
      ...potionDiscardControls(theme),
      ...(options.experimentalCharacters === true ? experimentalCharacterControls(theme) : []),
      ...exitControls(theme),
    ],
  };
}
