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
  const iconSize = Math.min(d, card.art);
  const trim = card.trim;
  // The cost straddles the top-left corner; the title banner and frame carry rarity.
  const disc = [-w / 2 + d / 2 - trim.costOverhang, top - d / 2 + trim.costOverhang];
  const typeY = top - card.nameBand - card.art - card.typeLine / 2 - b;
  const bandBottom = top - b - card.nameBand;
  const picture = (name, values, id, colour = c.text) => ({name, kind:'image',
    position:values.slice(0,2), size:values.slice(2), image:id, colour});
  const hidden = control => ({...control, visible:false});
  const orb = (name, values, colour, id = image.disc) => ({...plate(name, values, colour), image:id});
  const padding = node ? s.xl : s.s;
  // Views tint border/nameBand/nameRule by rarity, artPlate/costDisc by state;
  // the remaining trim is fixed-colour.
  return [
    ...(context === 'deck' ? [] : [hidden({...plate('glow', frame([0,0],[w+padding,h+padding]), c.goldBright), image:image.glow})]),
    plate('shadow', frame([0,-trim.shadow],[w,h]), c.cardShadow),
    plate('border', frame([0,0],[w,h]), c.rarity.basic),
    plate('plate', frame([0,0],[w-b*2,h-b*2]), c.cardBody),
    plate('nameBand', frame([0,nameY],[w-b*2,card.nameBand]), c.rarityBand.basic),
    plate('nameRule', frame([0,bandBottom],[w-b*2,b]), c.rarity.basic),
    text('name', frame([d/2,nameY],[w-d-s.s,Math.max(card.nameBand,l.nativeText.lineHeight)]), '', f.cardName),
    // artPlate is the picture's 1px keyline; artWell is the dark window inside it.
    plate('artPlate', frame([0,artY],[w-b*2,card.art]), c.cardType.attack),
    plate('artWell', frame([0,artY],[w-b*2-trim.keyline*2,card.art-trim.keyline*2]), c.cardWell),
    ...(node ? Object.entries(icon.cardArt).map(([kind,id]) => hidden(picture(`art_${kind}`,[0,artY,iconSize,iconSize],id)))
      : [picture('art',[0,artY,iconSize,iconSize],icon.cardArt.attack)]),
    // Type pill on the picture's lower edge, wide enough for a moved "＋2" marker.
    plate('typeEdge', frame([0,typeY],[trim.typeTag[0]+trim.keyline*2,trim.typeTag[1]+trim.keyline*2]), c.gold),
    plate('typeTag', frame([0,typeY],trim.typeTag), c.cardWell),
    text('type', frame([0,typeY],[w-s.s,l.nativeText.lineHeight]), '', f.small, c.gold),
    text(node?'description':'label', frame([0,-top+card.textBox[1]/2+s.xs],card.textBox), '', f.card),
    // Dark coin with a coloured ring and coloured numeral.
    orb('costCore', frame(disc,[d+trim.costRing,d+trim.costRing]), c.cardWell),
    orb('costDisc', frame(disc,[d,d]), c.energy, image.ring),
    text('cost',frame(disc,[d,node?l.nativeText.lineHeight:d]),'',f.cost,c.energy),
    ...(node ? [
      hidden(plate('veil',frame([0,0],[w,h]),c.backdropVeil)),
      hidden(plate('stampPlate',frame([0,0],[w-b*2,l.nativeText.lineHeight+s.s]),c.panelSunken)),
      hidden(text('stamp',frame([0,0],[w-s.s,l.nativeText.lineHeight]),'',f.label,c.goldBright)),
    ] : []),
    ...(interactive && context !== 'deck' ? [hit([w,h])] : []),
  ];
}
