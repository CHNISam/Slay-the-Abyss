import { battleLayout } from './ui-layout.mjs';
import { mapLayout } from './map-ui-layout.mjs';
import { nodeLayout } from './node-ui-layout.mjs';
import { nativeControls, nativeTheme } from './native-ui-theme.mjs';
import { deckControls } from './deck-ui-layout.mjs';
import { relicViewControls } from './relic-view-layout.mjs';
import { exitControls } from './exit-ui-layout.mjs';
import { potionDiscardControls } from './potion-discard-layout.mjs';
import { vistaControl, prologueControl } from './cinematic-ui-layout.mjs';
import { experimentalCharacterControls } from './character-ui-layout.mjs';
import {attachVictoryEasterEgg} from './victory-easter-egg-layout.mjs';
import {attachOfficialBackdrops} from './official-backdrop-layout.mjs';

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
  // Conditional map return actions stay secondary to the route, not large panels.
  // Reuse the existing official back glyph; no route or reward binding changes.
  const mapReturn = (name, values, label) => {
    const action = button(name, values, label, { inset: [space.s, space.s],
      fontSize: font.label, colour: color.mapHeader.ink, fill: '#00000000' });
    const textLabel = action.children.find(item => item.name === 'label');
    textLabel.position = [space.m, 0]; textLabel.size = [values[2] - space.xl, values[3]];
    action.children.splice(1, 0, { name: 'backIcon', kind: 'image', position: [-values[2] / 2 + space.s, 0],
      size: [font.label, font.label], image: theme.icon.back, colour: color.mapHeader.ink });
    // TASK-4.13 judge: translucent dark panel + copper hairline, matching the top bar.
    const [hw, hh] = values.slice(2);
    action.children.unshift({ name: 'panelHairline', kind: 'image', position: [0, 0], size: [hw, hh], image: theme.image.rect ?? theme.image.disc, colour: color.mapHeader.border, opacity: 153 / 255 },
      { name: 'panelShade', kind: 'image', position: [0, 0], size: [hw - 2, hh - 2], image: theme.image.rect ?? theme.image.disc, colour: color.mapHeader.shade, opacity: 179 / 255 });
    return { ...action, visible: false };
  };
  // Route choices need the same resources as room decisions, before entering a shop.
  mapPanel.children.push(mapReturn('previewBack', theme.layout.runMenu.mapBack, '返回菜单'));
  const bar = theme.layout.nativeNode.topBar;
  const resourceIcon = (name, values, entry, colour) => ({ name, kind: 'image',
    position: values.slice(0, 2), size: values.slice(2),
    image: typeof entry === 'object' ? entry.id : entry, colour });
  mapPanel.children.push({ name: 'resources', kind: 'container', size: [...theme.canvas.base], children: [
    resourceIcon('hpIcon', bar.hpIcon, theme.icon.hp, color.hp),
    text('hp', bar.hp, '', font.hud, color.text),
    resourceIcon('goldIcon', bar.goldIcon, theme.icon.gold, color.text),
    text('gold', bar.gold, '', font.hud, color.goldBright),
  ] });
  const resourceBox = (icon, value) => {
    const left = Math.min(icon[0] - icon[2] / 2, value[0] - value[2] / 2);
    const right = Math.max(icon[0] + icon[2] / 2, value[0] + value[2] / 2);
    return [(left + right) / 2, value[1], Math.max(48, right - left), Math.max(48, value[3])];
  };
  const resourceHints = (hp, gold) => ({ name: 'resourceHints', kind: 'container', size: [...theme.canvas.base], children:
    [['hp', hp], ['gold', gold]].map(([name, box]) => ({ name, kind: 'container', position: box.slice(0, 2), size: box.slice(2), children: [
      { name: 'hit', kind: 'cursorArea', size: box.slice(2), focusable: true },
    ] })) });
  const b = theme.layout.topBar;
  battleControls.push(resourceHints(resourceBox([b.hpIcon[0], b.y, b.hpIcon[1], b.hpIcon[1]], [b.hp[0], b.y, b.hp[1], b.height]),
    resourceBox([b.goldIcon[0], b.y, b.goldIcon[1], b.goldIcon[1]], [b.gold[0], b.y, b.gold[1], b.height])));
  mapPanel.children.push(resourceHints(resourceBox(bar.hpIcon, bar.hp), resourceBox(bar.goldIcon, bar.gold)));
  const picture = (name, size, id, colour) => ({ name, kind: 'image', position: [...theme.layout.nativeControl.origin],
    size, image: id, colour });
  const [ex, ey, ew, eh] = layout.emblem;
  // Shared by menu and results: glow, sunken disc and Geo mark; Lua recolours it per outcome.
  const emblem = { name: 'emblem', kind: 'container', position: [ex, ey], size: [ew, eh], children: [
    { ...picture('glow', [ew + layout.emblemGlow, eh + layout.emblemGlow], image.glow, color.goldBright), opacity: 0.35 },
    // Pan 2026-10-31：首页徽记改为自研「岩晶」刻面（三层菱形 + 中轴刻线），不再用原生元素圆徽。
    { ...picture('frame', [ew * .62, eh * .62], image.rect, color.goldDim), rotation: 45 },
    { ...picture('disc', [ew * .56, eh * .56], image.rect, color.panelSunken), rotation: 45 },
    { ...picture('icon', [ew * .38, eh * .38], image.rect, color.geo), rotation: 45 },
    { ...picture('core', [ew * .16, eh * .16], image.rect, color.panelSunken), rotation: 45 },
    picture('spark', [ew * .2, eh * .2], image.diamond, color.goldBright),
  ] };
  const stats = layout.stats, [cw, ch] = stats.size;
  const statCard = (key, i) => ({ name: `stat_${key}`, kind: 'container',
    position: [stats.origin[0] + i * stats.step, stats.origin[1]], size: [cw, ch], children: [
      plate('border', centred([cw + space.border, ch + space.border]), color.line),
      plate('face', centred([cw, ch]), color.panel),
      text('label', frame([0, stats.label], [cw - space.l, Math.max(theme.layout.nativeText.lineHeight, font.label + space.l)]), '', font.label, color.textDim),
      text('value', frame([0, stats.value], [cw - space.l, font.numberLarge + space.l]), '', font.numberLarge, color.text),
    ] });
  const layoutTree = {
    name: 'SlayTheAbyss', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [
      { name: 'battlePanel', kind: 'container', size: [...theme.canvas.base], visible: false, children: battleControls },
      mapPanel,
      mapReturn('combatRewards', theme.layout.battleRewards.return, '返回战利品'),
      ...nodeLayout(theme).controls.map(control => ({ ...control, visible: false, children: control.children.map(child =>
        ['deckIcon', 'deck', 'potions', 'relics'].includes(child.name) ? { ...child, visible: false } : child.name === 'title' ? { ...child, size: [theme.layout.nativeNode.topBar.title[2], child.size[1]] }
          : child.name === 'notice' ? { ...child, position: theme.layout.exitMenu.nodeNotice.slice(0, 2),
            size: theme.layout.exitMenu.nodeNotice.slice(2) } : child) })),
      { name: 'menuPanel', kind: 'container', size: [...theme.canvas.base], children: [
        plate('backdrop', layout.backdrop, color.backdrop),
        vistaControl(theme),
        ...(layout.hero && theme.icon.heroSlots ? [{ name: 'heroArt', kind: 'image',
          position: layout.hero.slice(0, 2), size: layout.hero.slice(2),
          image: theme.icon.heroSlots.menu.id, colour: color.buttonPressedText }] : []),
        // Pan 2026-10-31：标题区压一条暗带 + 副标两侧金线，地景上保证可读、不显廉价。
        { name: 'lowpolyVeil', kind: 'image', position: [0, 0], size: [...theme.canvas.base], image: image.rect, colour: color.backdrop, opacity: 0.28 },
        { name: 'titleBand', kind: 'image', position: [0, 150], size: [1280, 230], image: image.rect, colour: color.backdrop, opacity: 0.55 },
        { name: 'taglineRuleL', kind: 'image', position: [-150, layout.tagline[1]], size: [120, 1], image: image.rect, colour: color.goldDim },
        { name: 'taglineRuleR', kind: 'image', position: [150, layout.tagline[1]], size: [120, 1], image: image.rect, colour: color.goldDim },
        emblem,
        text('title', layout.title, '杀戮原塔2', font.display, color.gold),
        text('tagline', layout.tagline, '', font.heading, color.goldBright),
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
        { ...plate('deathShade', layout.backdrop, color.backdrop), visible: false },
      ] },
      ...deckControls(theme),
      ...relicViewControls(theme),
      ...potionDiscardControls(theme),
      ...experimentalCharacterControls(theme),
      prologueControl(theme),
      ...exitControls(theme),
    ],
  };
  const overlays = new Set(['deckPanel', 'relicPanel', 'potionPanel', 'choicePanel', 'characterPanel', 'exitPanel', 'runMenu', 'prologuePanel']);
  for (const control of layoutTree.controls) if (overlays.has(control.name)) control.isolateNavigation = true;
  const menuPanel=layoutTree.controls.find(c=>c.name==='menuPanel');
  for(const name of ['vista','heroArt']){const old=menuPanel.children.find(c=>c.name===name);if(old)old.visible=false;}
  attachOfficialBackdrops(layoutTree,theme);
  attachVictoryEasterEgg(layoutTree,theme);
  return layoutTree;
}
