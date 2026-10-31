import { nativeControls, nativeTheme } from './native-ui-theme.mjs';
import { cardFaceChildren } from './card-face.mjs';
import { merchantControl } from './cinematic-ui-layout.mjs';
import { augmentMatchEventPicker } from './match-event-layout.mjs';

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
    return { name, kind: 'container', position, size: [...theme.layout.card.size],
      children: cardFaceChildren(theme, 'node', interactive) };
  }
  function price(name, x, y) {
    const [w, h] = layout.price.size, coin = layout.price.coin;
    return { name, kind: 'container', position: [x, y], size: [w, h], children: [
      picture('coin', [-w / 2 + coin / 2 + space.s, 0, coin, coin], icon.gold, color.text),
      text('value', frame([coin / 2, 0], [w - coin - space.s, h]), '', font.label, color.goldBright),
      hidden(text('sale',layout.price.sale,'特价',font.small,color.positive)),
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
    picture('icon', [0, 44, 24, 24], icon.remove, color.textDim),
    text('name', frame([0, 14], [shop.removal[2], lineHeight]), '移除一张牌', font.small, color.text),
    text('description', frame([0, -34], [shop.removal[2] - space.s, 64]), '', font.small, color.textDim),
  ] });
  const shopControls = [hidden(arrow('previous', shop.previous, icon.back)), hidden(arrow('next', shop.next, icon.next)),
    hidden(text('page', shop.page, '', font.small, color.textDim)), removal, price('removalPrice', shop.removal[0], shop.removalPriceY)];
  shop.columns.forEach((x, i) => shopControls.push(card(`card${i + 1}`, [x, shop.cardRows[i]]), price(`price${i + 1}`, x, shop.priceRows[i])));
  relic.columns.forEach((x, i) => {
    const [w, h] = relic.size, left = -w / 2 + space.s + relic.disc / 2;
    const tile = framed(`relic${i + 1}`, [x, relic.y, w, h], null, { children: [
      { ...plate('disc', frame([left, 0], [relic.disc, relic.disc]), color.panelSunken), image: image.disc },
      picture('icon', [left, 0, relic.disc, relic.disc], icon.node.treasure, color.geo),
      text('name', frame([18, 0], [104, lineHeight]), '', font.small, color.text),
      hidden(text('description', frame([0, -h/6], [w-space.l, 60]), '', font.small, color.textDim)),
      hidden(plate('veil', frame([0, 0], [w, h]), color.backdropVeil)),
    ] });
    shopControls.push(tile, price(`relicPrice${i + 1}`, x, relic.priceY));
  });
  shop.potions.columns.forEach((x,i) => {
    const [w,h]=shop.potions.size;
    shopControls.push(framed(`potion${i+1}`, [x,shop.potions.y,w,h], null, { children: [
      picture('icon', [-50,0,32,32], icon.potion.fire_potion, color.text),
      text('name', frame([18,0],[104,lineHeight]), '', font.small, color.text),
      hidden(text('description', frame([0,-h/6],[w-space.l,60]), '', font.small, color.textDim)),
      hidden(plate('veil', frame([0,0],[w,h]), color.backdropVeil)),
    ] }), price(`potionPrice${i+1}`,x,shop.potions.priceY));
  });
  shopControls.push(hidden(arrow('relicPrevious', shop.relicPrevious, icon.back)), hidden(arrow('relicNext', shop.relicNext, icon.next)));
  shopControls.push(hidden({name:'detail',kind:'container',position:shop.detail.slice(0,2),size:shop.detail.slice(2),children:[
    plate('border',frame([0,0],shop.detail.slice(2)),color.gold),
    plate('panel',frame([0,0],shop.detail.slice(2).map(v=>v-space.border*2)),color.panelSunken),
    text('name',frame([0,40],[shop.detail[2]-space.l,40]),'',font.body,color.goldBright),
    text('description',frame([0,-20],[shop.detail[2]-space.l,80]),'',font.body,color.text),
  ]}));

  const picker = layout.picker, previewY = picker.previewY;
  const pickerControls = [arrow('previous', picker.previous, icon.back), arrow('next', picker.next, icon.next),
    text('page', picker.page, '', font.small, color.textDim),
    ...picker.columns.map((x, i) => card(`card${i + 1}`, [x, picker.cardY])),
    hidden(card('before', [picker.before, previewY], true)), hidden(card('after', [picker.after, previewY], true)),
    hidden(card('target', [picker.target, previewY], false)),
    hidden(picture('arrow', picker.arrow, icon.next, color.positive)),
    text('label', picker.label, '', font.label, color.textDim), text('hint', picker.hint, '', font.small, color.textDim),
    text('empty', picker.empty, '', font.body, color.textMuted)];
  const forge = layout.forge;
  pickerControls.push(hidden(arrow('forgePrevious',forge.previous,icon.back)),hidden(arrow('forgeNext',forge.next,icon.next)));
  pickerControls.push(hidden(group('forgeGrid',forge.rows.flatMap((y,row)=>forge.columns.map((x,col)=>
    card(`card${row*forge.columns.length+col+1}`,[x,y]))))));

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
  campControls.push(hidden(group('result',[
    plate('border',[0,-20,640,200],color.gold),plate('panel',[0,-20,636,196],color.panelSunken),
    text('name',[0,28,600,60],'休息完成',font.title,color.goldBright),
    text('description',[0,-52,600,80],'',font.heading,color.positive),
  ])));

  const event = layout.event, option = event.options;
  const eventControls = [
    ...(event.neow ? [{ name: 'neowFigure', kind: 'container', position: [0, 0], size: [1280, 720], visible: false, children: [
      { ...picture('scene', [0, -36, 1280, 648], image.officialBackdrops.act1_1, '#2E3A52FF') },
      { ...picture('shade', [0, -36, 1280, 648], image.vignette, '#000000C0') },
    ] }] : []),
...(event.neow ? [hidden({ ...plate('bubble', event.neow.bubble, '#E9E1CCF2'), image: image.discSoft })] : []), plate('plateBorder', event.plate, color.goldDim),
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
    hidden(arrow('previous', chest.previous, icon.back)), hidden(arrow('next', chest.next, icon.next)),
    hidden(text('page', chest.page, '', font.label, color.goldBright)),
    hidden(text('bossDescription', chest.bossDescription, '', font.small, color.textDim)),
  ];
  const list=layout.rewardList;
  list.rows.forEach((y,i)=>treasureControls.push(hidden(framed(`rewardItem${i+1}`,[list.x,y,...list.size],null,{children:[
    picture('icon',[-list.size[0]/2+40,0,48,48],icon.node.treasure,color.geo),
    text('name',frame([28,22],[list.size[0]-100,40]),'',font.body,color.goldBright),
    text('description',frame([28,-22],[list.size[0]-100,40]),'',font.small,color.textDim),
  ]}))));
  treasureControls.push(hidden({...picture('burst',[...chest.chest.slice(0,2),360,360],image.glow,color.goldBright)}));
  const rd=list.detail;
  treasureControls.push(hidden({name:'details',kind:'container',position:rd.slice(0,2),size:rd.slice(2),children:[
    plate('border',[0,0,...rd.slice(2)],color.gold),plate('panel',[0,0,rd[2]-4,rd[3]-4],color.panelSunken),
    text('name',[0,110,rd[2]-32,40],'',font.heading,color.goldBright),
    text('description',[0,-20,rd[2]-32,200],'',font.body,color.text),
  ]}));

  controls.push(group('shopView', shopControls), group('campView', campControls), augmentMatchEventPicker(group('pickerView', pickerControls),theme),
    group('eventView', eventControls), group('treasureView', treasureControls), merchantControl(theme),
    framed('back', layout.back, '返回'), framed('confirm', layout.confirm, '确认', { primary: true, fontSize: font.heading }),
    hidden(group('roomEffect',[
      plate('shade',[0,0,...theme.canvas.base],color.backdropVeil),
      {...picture('glow',[0,30,320,320],image.glow,color.goldBright)},
      picture('icon',[0,40,120,120],icon.medallion.camp,color.text),
      text('title',[0,-70,800,60],'',font.title,color.goldBright),
      text('description',[0,-138,800,60],'',font.heading,color.text),
      ...Array.from({length:layout.roomMotion.sparkCount},(_,i)=>picture(`spark${i+1}`,[0,40,layout.roomMotion.sparkSize,layout.roomMotion.sparkSize],image.diamond,color.goldBright)),
    ])));
  return { name: 'AbyssNodes', script: 'abyss_ui', showCursor: true, blockKeys: true, blockCursor: true,
    controls: [{ name: 'nodePanel', kind: 'container', size: [...theme.canvas.base], children: controls }] };
}
