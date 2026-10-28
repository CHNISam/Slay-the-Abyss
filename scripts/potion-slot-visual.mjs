import { nativeControls } from './native-ui-theme.mjs';

// Map 41–47 / Main 48–57: empty, occupied and selected are different shells.
// No verified dashed-ring asset is available in the cloud copy: known rects
// form separated tangent dashes. The known soft-disc approximates CSS radial
// falloff with source-interpolated colors; both discs are bounded inside the face
// rather than assuming a new clip API.
export function potionSlotVisual(theme, { border, plate, bottleSize, ink }) {
  const { plate: rectangle } = nativeControls(theme);
  const c=theme.color.potionShell,l=theme.layout.potionShell,d=border.size[0],b=l.border;
  const inner=d-2*b,focus=d*l.fittedFocusY,lightSize=inner-2*focus;
  const picture=(name,size,colour,id=theme.image.disc,position=[0,0])=>({
    ...rectangle(name,[...position,...size],colour),image:id,
  });
  const group=(name,children,visible=false)=>({name,kind:'container',position:[0,0],size:[d,d],visible,children});
  const radius=(d-b)/2,count=Math.round(Math.PI*(d-b)/(2*l.dashBorderRatio*b));
  const dashLength=2*radius*Math.sin(Math.PI/(2*count));
  const filled=(name,colours)=>group(name,[
    picture('rim',[d,d],colours.border),picture('base',[inner,inner],colours.base),
    // Bounded two-disc fit of the source farthest-corner field, not CSS/native equivalence.
    picture('light',[inner,inner],colours.mid,theme.image.discSoft),
    picture('focusLight',[lightSize,lightSize],colours.light,theme.image.discSoft,[0,focus]),
  ]);
  return [
    // Old battle button() can still tint these paths; they must never show.
    { ...border, image:theme.image.disc, visible:false },
    { ...plate, image:theme.image.disc, visible:false },
    group('selectedShell',[
      picture('glow',[d+2*l.blur,d+2*l.blur],c.selected.glow,theme.image.glow),
      picture('spread',[d+2*l.spread,d+2*l.spread],c.selected.spread),
    ]),
    group('emptyShell',[
      picture('face',[d,d],c.empty.face),
      group('dashes',Array.from({length:count},(_,i)=>{
        const angle=2*Math.PI*i/count;
        return {...picture(`dash${i+1}`,[dashLength,b],c.empty.border,theme.image.rect,
          [radius*Math.sin(angle),radius*Math.cos(angle)]),rotation:-i*360/count};
      }),true),
    ],true),
    filled('filledShell',c.normal),filled('fireShell',c.fire),
    { name:'bottle',kind:'image',position:[0,0],size:[bottleSize,bottleSize],
      image:theme.icon.potion.fire_potion,colour:ink,visible:false },
  ];
}
