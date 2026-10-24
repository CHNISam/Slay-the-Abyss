import { nativeControls, nativeTheme } from './native-ui-theme.mjs';
import { merchantControl } from './cinematic-ui-layout.mjs';

// Approved PR19 node screens (shop, camp/forge, event, treasure) as one native
// tree. Every view is its own container so no control exceeds the MCP child limit.
export function nodeLayout(theme = nativeTheme) {
  const { text, plate, frame, hit } = nativeControls(theme);
  const layout = theme.layout.nativeNode, { color, font, space, icon, image } = theme;
  const lineHeight = theme.layout.nativeText.lineHeight;
  const iconId = entry => (typeof entry === 'object' ? entry.id : entry);
  const picture = (name, values, id, colour = color.text) => ({ name, kind: 'image', position: values.slice(0, 2),
    size: values.slice(2), image: iconId(id), colour });
  const hidden = control => ({ ...control, visible: false });
  const group = (name, children, visible = false) => ({ name, kind: 'container', size: [...theme.canvas.base], visible, children });

  // Keep all direct child paths: cursor events select faces and scale the whole
  // framed container, including its dynamic text/icons and existing hit area.
  function framed(name, values, label = null, { primary = false, fontSize = font.body, children = [] } = {}) {
    const size = values.slice(2), [w, h] = size, b = space.border, centre = [0, 0];
    const face = (state, colour) => plate(state, frame(centre, [w - b * 2, h - b * 2]), colour);
    return { name, kind: 'container', position: values.slice(0, 2), size: [...size], children: [
      plate('border', frame(centre, size), primary ? color.goldBright : color.gold),
      face('normal', primary ? color.geo : color.panelRaised), face('disabled', color.panelSunken),
      hidden(face('hover', primary ? color.goldBright : color.buttonHover)), hidden(face('pressed', color.goldDim)),
      face('selected', color.goldDim),
      ...children,
      ...(label === null ? [] : [text('label', frame(centre, size.map((value, i) => value - layout.buttonInset[i])), label, fontSize,
        primary ? color.textOnLight : color.goldBright)]),
      hit(size),
    ] };
  }
  const arrow = (name, values, id) => framed(name, values, null, { children: [
    picture('icon', [0, 0, layout.arrowIcon, layout.arrowIcon], id, color.gold)] });

  // Approved 148x208 card: rarity frame, name band, type-coloured art, type line, text, cost disc.
  function card(name, position, interactive = true) {
    const card = theme.layout.card, [w, h] = card.size, b = space.border, top = h / 2;
    const artY = top - card.nameBand - card.art / 2 - b;
    const typeY = top - card.nameBand - card.art - card.typeLine / 2 - b;
    const disc = [-w / 2 + card.costDisc / 2, top - card.costDisc / 2];
    return { name, kind: 'container', position, size: [w, h], children: [
      hidden({ ...plate('glow', frame([0, 0], [w + space.xl, h + space.xl]), color.goldBright), image: image.glow }),
      plate('border', frame([0, 0], [w, h]), color.rarity.basic),
      plate('plate', frame([0, 0], [w - b * 2, h - b * 2]), color.panel),
      plate('nameBand', frame([0, top - card.nameBand / 2 - b], [w - b * 2, card.nameBand]), color.panelRaised),
      text('name', frame([card.costDisc / 2, top - card.nameBand / 2 - b], [w - card.costDisc - space.s, lineHeight]),
        '', font.cardName),
      plate('artPlate', frame([0, artY], [w - b * 2, card.art]), color.cardType.attack),
      ...Object.entries(icon.cardArt).map(([kind, id]) => hidden(picture(`art_${kind}`, [0, artY, lineHeight, lineHeight], id))),
      text('type', frame([0, typeY], [w - space.s, lineHeight]), '', font.small, color.gold),
      text('description', frame([0, -top + card.textBox[1] / 2 + space.xs], card.textBox), '', font.card),
      { ...plate('costDisc', frame(disc, [card.costDisc, card.costDisc]), color.energy), image: image.disc },
      text('cost', frame(disc, [card.costDisc, lineHeight]), '', font.number, color.textOnLight),
      hidden(plate('veil', frame([0, 0], [w, h]), color.backdropVeil)),
      hidden(plate('stampPlate', frame([0, 0], [w - b * 2, lineHeight + space.s]), color.panelSunken)),
      hidden(text('stamp', frame([0, 0], [w - space.s, lineHeight]), '', font.label, color.goldBright)),
      ...(interactive ? [hit([w, h])] : []),
    ] };
  }
  function price(name, x, y) {
    const [w, h] = layout.price.size, coin = layout.price.coin;
    return { name, kind: 'container', position: [x, y], size: [w, h], children: [
      picture('coin', [-w / 2 + coin / 2 + space.s, 0, coin, coin], icon.gold, color.text),
      text('value', frame([coin / 2, 0], [w - coin - space.s, h]), '', font.label, color.goldBright),
    ] };
  }

  const bar = layout.topBar;
  const controls = [
    plate('backdrop', layout.backdrop, color.backdrop),
    plate('topBar', bar.plate, color.panelSunken),
    text('title', bar.title, '', font.heading, color.gold),
    picture('hpIcon', bar.hpIcon, icon.hp, color.hp), text('hp', bar.hp, '', font.body),
    picture('goldIcon', bar.goldIcon, icon.gold, color.text), text('gold', bar.gold, '', font.body, color.goldBright),
    text('potions', bar.potions, '', font.label, color.textDim), text('relics', bar.relics, '', font.label, color.textDim),
    picture('deckIcon', bar.deckIcon, icon.deck, color.text), text('deck', bar.deck, '', font.body),
    text('notice', layout.notice, '', font.body, color.text),
  ];

  const shop = layout.shop, relic = shop.relics;
  const removal = framed('removal', shop.removal, null, { children: [
    picture('icon', [0, 50, 56, 56], icon.remove, color.textDim),
    text('name', frame([0, -6], [shop.removal[2] - space.l, lineHeight]), '移除一张卡牌', font.label, color.text),
    text('description', frame([0, -60], [shop.removal[2] - space.l, lineHeight + space.l]), '', font.small, color.textDim),
  ] });
  const shopControls = [arrow('previous', shop.previous, icon.back), arrow('next', shop.next, icon.next),
    text('page', shop.page, '', font.small, color.textDim), removal, price('removalPrice', shop.removal[0], shop.priceY)];
  shop.columns.forEach((x, i) => shopControls.push(card(`card${i + 1}`, [x, shop.cardY]), price(`price${i + 1}`, x, shop.priceY)));
  relic.columns.forEach((x, i) => {
    const [w, h] = relic.size, left = -w / 2 + space.l + relic.disc / 2, start = left + relic.disc / 2 + space.m;
    const textX = (start + w / 2 - space.m) / 2, textW = w / 2 - space.m - start;
    const tile = framed(`relic${i + 1}`, [x, relic.y, w, h], null, { children: [
      { ...plate('disc', frame([left, 0], [relic.disc, relic.disc]), color.panelSunken), image: image.disc },
      picture('icon', [left, 0, relic.disc - space.l, relic.disc - space.l], icon.node.treasure, color.geo),
      text('name', frame([textX, h / 4], [textW, lineHeight]), '', font.body, color.text),
      text('description', frame([textX, -h / 4], [textW, lineHeight]), '', font.small, color.textDim),
      hidden(plate('veil', frame([0, 0], [w, h]), color.backdropVeil)),
    ] });
    shopControls.push(tile, price(`relicPrice${i + 1}`, x, relic.priceY));
  });
  shopControls.push(arrow('relicPrevious', shop.relicPrevious, icon.back), arrow('relicNext', shop.relicNext, icon.next));

  const picker = layout.picker, previewY = picker.previewY;
  const pickerControls = [arrow('previous', picker.previous, icon.back), arrow('next', picker.next, icon.next),
    text('page', picker.page, '', font.small, color.textDim),
    ...picker.columns.map((x, i) => card(`card${i + 1}`, [x, picker.cardY])),
    hidden(card('before', [picker.before, previewY], false)), hidden(card('after', [picker.after, previewY], false)),
    hidden(card('target', [picker.target, previewY], false)),
    hidden(picture('arrow', picker.arrow, icon.next, color.positive)),
    text('label', picker.label, '', font.label, color.textDim), text('hint', picker.hint, '', font.small, color.textDim),
    text('empty', picker.empty, '', font.body, color.textMuted)];

  const camp = layout.camp;
  const campTile = (name, [x, y], id, tint) => {
    const tile = framed(name, [x, y, ...camp.tileSize], null, { children: [
      picture('icon', camp.icon, id, tint),
      text('name', camp.name, name === 'rest' ? '休息' : '锻造', font.title, color.goldBright),
      text('description', camp.description, '', font.label, color.textDim),
    ] });
    return tile;
  };
  const campControls = [picture('medallion', camp.medallion, icon.medallion.camp, color.text),
    campTile('rest', camp.tiles[0], icon.hp, color.hp), campTile('forge', camp.tiles[1], icon.upgrade, color.geo)];

  const event = layout.event, option = event.options;
  const eventControls = [plate('plateBorder', event.plate, color.goldDim),
    plate('plate', [...event.plate.slice(0, 2), event.plate[2] - space.border * 2, event.plate[3] - space.border * 2], color.panelRaised),
    { ...plate('glow', [event.art[0], event.art[1], event.art[2] * 2, event.art[3] * 2], color.goldDim), image: image.glow },
    picture('art', event.art, icon.geo, color.geo),
    text('caption', event.caption, '', font.label, color.textDim),
    text('name', event.name, '', font.title, color.goldBright), text('body', event.body, '', font.body, color.text),
    ...option.rows.map((y, i) => {
      const row = framed(`option${i + 1}`, [option.x, y, ...option.size], null, { children: [
        text('title', option.title, '', font.body, color.goldBright),
        text('description', option.description, '', font.small, color.textDim)] });
      return row;
    })];

  const chest = layout.treasure;
  const reward = framed('reward', chest.reward, null, { children: [
    { ...plate('disc', frame([-chest.reward[2] / 2 + space.l + chest.rewardDisc / 2, 0], [chest.rewardDisc, chest.rewardDisc]),
      color.panelSunken), image: image.disc },
    picture('icon', [-chest.reward[2] / 2 + space.l + chest.rewardDisc / 2, 0, chest.rewardDisc - space.l, chest.rewardDisc - space.l],
      icon.node.treasure, color.geo),
    text('name', frame([chest.rewardDisc / 2, chest.reward[3] / 4], [chest.reward[2] - chest.rewardDisc - space.xxl * 2, lineHeight]),
      '', font.body, color.text),
    text('description', frame([chest.rewardDisc / 2, -chest.reward[3] / 4],
      [chest.reward[2] - chest.rewardDisc - space.xxl * 2, lineHeight]), '', font.small, color.textDim),
  ] });
  const treasureControls = [
    { ...plate('glow', chest.glow, color.goldDim), image: image.glow },
    picture('closed', chest.chest, icon.medallion.treasure, color.text),
    hidden(picture('open', chest.chest, icon.medallion.chestOpen, color.text)),
    { name: 'chest', kind: 'container', position: chest.chest.slice(0, 2), size: chest.chest.slice(2), children: [hit(chest.chest.slice(2))] },
    text('hint', chest.hint, '点击打开宝箱', font.heading, color.textDim),
    hidden(reward), hidden(framed('take', chest.take, '拿取并离开', { primary: true, fontSize: font.heading })),
  ];

  controls.push(group('shopView', shopControls), group('campView', campControls), group('pickerView', pickerControls),
    group('eventView', eventControls), group('treasureView', treasureControls), merchantControl(theme),
    framed('back', layout.back, '返回'), framed('confirm', layout.confirm, '确认', { primary: true, fontSize: font.heading }));
  return { name: 'AbyssNodes', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [{ name: 'nodePanel', kind: 'container', size: [...theme.canvas.base], children: controls }] };
}
