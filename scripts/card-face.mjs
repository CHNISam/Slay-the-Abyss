import { nativeControls } from './native-ui-theme.mjs';

// The same card face is assembled for hand/reward, library and node views.
// Context changes host controls, never the underlying artwork/text ownership.
export function cardFaceChildren(theme, context, interactive = true) {
  if (!['battle', 'deck', 'node'].includes(context)) throw new Error('Unknown card face context');
  const { text, plate, frame, hit } = nativeControls(theme);
  const { color: c, font: f, layout: l, space: s, image, icon } = theme;
  const card = l.card, [w, h] = card.size, b = s.border, top = h / 2, d = card.costDisc;
  const node = context === 'node';
  const nameY = top - card.nameBand / 2 - b;
  const artY = top - card.nameBand - card.art / 2 - b;
  const iconSize = Math.min(node ? l.nativeText.lineHeight : d, card.art);
  const disc = [-w / 2 + d / 2, top - d / 2];
  const picture = (name, values, id, colour = c.text) => ({name, kind:'image',
    position:values.slice(0,2), size:values.slice(2), image:id, colour});
  const hidden = control => ({...control, visible:false});
  const padding = node ? s.xl : s.s;
  return [
    ...(context === 'deck' ? [] : [hidden({...plate('glow', frame([0,0],[w+padding,h+padding]), c.goldBright), image:image.glow})]),
    plate('border', frame([0,0],[w,h]), c.rarity.basic),
    plate('plate', frame([0,0],[w-b*2,h-b*2]), c.panel),
    plate('nameBand', frame([0,nameY],[w-b*2,card.nameBand]), c.panelRaised),
    text('name', frame([d/2,nameY],[w-d-s.s,card.nameBand]), '', f.cardName),
    plate('artPlate', frame([0,artY],[w-b*2,card.art]), c.cardType.attack),
    ...(node ? Object.entries(icon.cardArt).map(([kind,id]) => hidden(picture(`art_${kind}`,[0,artY,iconSize,iconSize],id)))
      : [picture('art',[0,artY,iconSize,iconSize],icon.cardArt.attack)]),
    text('type', frame([0,top-card.nameBand-card.art-card.typeLine/2-(node?b:0)],[w-s.s,l.nativeText.lineHeight]), '', f.small, c.gold),
    text(node?'description':'label', frame([0,-top+card.textBox[1]/2+s.xs],card.textBox), '', f.card),
    {...plate('costDisc',frame(disc,[d,d]),c.energy),image:image.disc},
    text('cost',frame(disc,[d,node?l.nativeText.lineHeight:d]),'',f.number,c.textOnLight),
    ...(node ? [
      hidden(plate('veil',frame([0,0],[w,h]),c.backdropVeil)),
      hidden(plate('stampPlate',frame([0,0],[w-b*2,l.nativeText.lineHeight+s.s]),c.panelSunken)),
      hidden(text('stamp',frame([0,0],[w-s.s,l.nativeText.lineHeight]),'',f.label,c.goldBright)),
    ] : []),
    ...(interactive && context !== 'deck' ? [hit([w,h])] : []),
  ];
}
