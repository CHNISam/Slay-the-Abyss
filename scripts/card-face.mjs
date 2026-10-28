import { nativeControls } from './native-ui-theme.mjs';

// Native-library composition, not CSS clipping. The triangle is rotated by the importer.
function roundedParts(w,h,r,colour,picture,plate,frame) {
  return [plate('vertical',frame([0,0],[w-2*r,h]),colour),
    plate('horizontal',frame([0,0],[w,h-2*r]),colour),
    ...[-1,1].flatMap(x=>[-1,1].map(y=>picture('corner'+x+'_'+y,[x*(w/2-r),y*(h/2-r),r*2,r*2],100002,colour)))];
}
function windowParts(kind,w,h,colour,picture,plate,frame) {
  if(kind==='skill')return roundedParts(w,h,11,colour,picture,plate,frame);
  if(kind==='power')return [picture('arch',[0,h*.16,w,h*.68],100002,colour),
    plate('base',frame([0,-h*.17],[w,h*.66]),colour)];
  return [plate('upper',frame([0,h*.08],[w,h*.84]),colour),
    {...picture('point',[0,-h*.42,w,h*.16],100003,colour),rotation:180}];
}

function emblem(role,picture,colour,body) {
  const p=(name,xywh,id=100002,tone=colour)=>picture(name,xywh,id,tone);
  if(role==='HT')return Array.from({length:5},(_,i)=>p('petal'+i,[Math.sin(i*Math.PI*2/5)*3,Math.cos(i*Math.PI*2/5)*3,5,5]));
  if(role==='AR')return [p('moon',[0,0,11,11]),p('cut',[2,2,9,9],100002,body)];
  if(role==='FR')return [p('water',[0,-2,8,8]),p('tip',[0,2,8,8],100003)];
  if(role==='RD')return [{...p('bolt',[0,2,5,9],100003),rotation:200},{...p('tail',[0,-2,5,9],100003),rotation:20}];
  if(role==='curse')return [{...p('slash',[0,0,3,12],100001),rotation:45},{...p('backslash',[0,0,3,12],100001),rotation:-45}];
  return [p('symbol',[0,0,11,11],role==='traveler'?100004:role==='colorless'?100006:100004)];
}

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
    hidden(plate('shadow', frame([0,-trim.shadow],[w,h]), c.cardShadow)),
    hidden(plate('border', frame([0,0],[w,h]), c.rarity.basic)),
    hidden(plate('plate', frame([0,0],[w-b*2,h-b*2]), c.cardBody)),
    ...[['roundShadow',0,-trim.shadow,w,h,7,c.cardShadow],['roundFrame',0,0,w,h,7,c.rarity.basic],['roundBody',0,0,w-b*2,h-b*2,4,c.cardBody]].map(([name,x,y,width,height,r,colour])=>({name,kind:'container',position:[x,y],size:[width,height],children:roundedParts(width,height,r,colour,picture,plate,frame)})),
    plate('nameBand', frame([0,nameY],[w-b*2,card.nameBand]), c.rarityBand.basic),
    plate('nameRule', frame([0,bandBottom],[w-b*2,b]), c.rarity.basic),
    // artPlate is the picture's 1px keyline; artWell is the dark window inside it.
    plate('artPlate', frame([0,artY],[w-b*2,card.art]), c.cardType.attack),
    plate('artWell', frame([0,artY],[w-b*2-trim.keyline*2,card.art-trim.keyline*2]), c.cardWell),
    {name:'skin',kind:'container',size:[w,h],children:[
      ...Array.from({length:theme.cardSkin.bandSteps},(_,i)=>plate('band'+(i+1),frame([0,nameY+card.nameBand/2-(i+.5)*card.nameBand/theme.cardSkin.bandSteps],[w-b*2,card.nameBand/theme.cardSkin.bandSteps+.1]),c.rarityBand.basic)),
      plate('gloss',frame([0,top-b-1],[w-b*2,1]),c.text),
      ...['attack','skill','power'].map(kind=>({name:kind,kind:'container',position:[0,artY],size:[w-b*2,card.art],children:
        [0,1.5].map((inset,index)=>({name:index?'well':'edge',kind:'container',size:[w-b*2,card.art],children:
          windowParts(kind,w-b*2-inset*2,card.art-inset*2,index?c.cardWell:c.energy,picture,plate,frame)
        }))})),
    ]},
    text('name', frame([d/2,nameY],[w-d-s.s,Math.max(card.nameBand,l.nativeText.lineHeight)]), '', f.cardName),
    ...(node ? Object.entries(icon.cardArt).map(([kind,id]) => hidden(picture(`art_${kind}`,[0,artY,iconSize,iconSize],id)))
      : [picture('art',[0,artY,iconSize,iconSize],icon.cardArt.attack)]),
    // Type pill on the picture's lower edge, wide enough for a moved "＋2" marker.
    hidden(plate('typeEdge', frame([0,typeY],[trim.typeTag[0]+trim.keyline*2,trim.typeTag[1]+trim.keyline*2]), c.gold)),
    hidden(plate('typeTag', frame([0,typeY],trim.typeTag), c.cardWell)),
    ...[['tagEdge',trim.typeTag[0]+trim.keyline*2,trim.typeTag[1]+trim.keyline*2,c.gold],['tagBody',...trim.typeTag,c.cardWell]].map(([name,width,height,colour])=>({name,kind:'container',position:[0,typeY],size:[width,height],children:roundedParts(width,height,height/2,colour,picture,plate,frame)})),
    text('type', frame([0,typeY],[w-s.s,l.nativeText.lineHeight]), '', f.small, c.gold),
    text(node?'description':'label', frame([0,-top+card.textBox[1]/2+s.xs],card.textBox), '', f.card),
    orb('roleRing',frame([0,-h/2+1],[18,18]),c.cardWell),
    {name:'roleMark',kind:'container',position:[0,-h/2+1],size:[11,11],children:Object.keys(theme.cardSkin.roles).map(role=>({name:role,kind:'container',size:[11,11],children:emblem(role,picture,c.energy,c.cardWell)}))},
    hidden(orb('costHalo',frame(disc,[d+12,d+12]),c.positive,image.ring)),
    // Dark coin with a coloured ring and coloured numeral.
    orb('costCore', frame(disc,[d+trim.costRing,d+trim.costRing]), c.cardWell),
    orb('costDisc', frame(disc,[d,d]), c.energy, image.ring),
    text('cost',frame(disc,[d,node?l.nativeText.lineHeight:d]),'',f.cost,c.energy),
    hidden(text('costDirection',frame([disc[0]+d/2-2,disc[1]-d/2+2],[20,l.nativeText.lineHeight]),'',f.small,c.positive)),
    hidden(text('blockedReason',frame([0,artY],[w-12,l.nativeText.lineHeight]),'',f.small,c.danger)),
    ...(node ? [
      hidden(plate('veil',frame([0,0],[w,h]),c.backdropVeil)),
      hidden(plate('stampPlate',frame([0,0],[w-b*2,l.nativeText.lineHeight+s.s]),c.panelSunken)),
      hidden(text('stamp',frame([0,0],[w-s.s,l.nativeText.lineHeight]),'',f.label,c.goldBright)),
    ] : []),
    ...(interactive && context !== 'deck' ? [hit([w,h])] : []),
  ];
}
